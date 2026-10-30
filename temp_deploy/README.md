# WordRise PHP API

Vanilla PHP + MySQL REST API for the Flutter vocabulary app.

## Setup

1. Create database and tables:

```powershell
mysql -u root -p < backend_php/database/schema.sql
```

PowerShell does not support `<` redirection for this command. Use the helper scripts instead:

```powershell
.\backend_php\start_database.ps1
.\backend_php\import_schema.ps1
```

2. Configure database with environment variables if needed:

```powershell
$env:DB_HOST="127.0.0.1"
$env:DB_PORT="3306"
$env:DB_NAME="wordrise"
$env:DB_USER="root"
$env:DB_PASS=""
$env:APP_TIMEZONE="Asia/Tashkent"
$env:APP_DEBUG="0"
$env:CORS_ALLOWED_ORIGINS="https://app.example.com"
```

Google login additionally needs the **Web application** OAuth client ID from
the same Google Cloud project as the Android package/SHA credential:

```powershell
$env:GOOGLE_WEB_CLIENT_ID="123456-example.apps.googleusercontent.com"
```

Build Flutter with that same public ID. Never bundle an OAuth client secret in
the app:

```powershell
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=123456-example.apps.googleusercontent.com
```

Deploy and run the idempotent migration before enabling the button:

```powershell
php backend_php/database/migrations/2026_07_18_google_auth.php
```

`POST /api/google_login.php` accepts only a Google ID token. The server verifies
its RS256 signature against Google's rotating certificates plus `iss`, `aud`,
`exp`, `iat`, subject and verified email before issuing a WordRise API token.

3. Start local API:

```powershell
php -S 127.0.0.1:8000 -t backend_php
```

If PHP was installed with winget and the current terminal does not see `php` yet:

```powershell
.\backend_php\start_server.ps1
```

Flutter default API URL:

```text
http://127.0.0.1:8000/api
```

Android emulator:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

## Learning companion migration

Run the idempotent migration after deploying this release:

```powershell
php backend_php/database/migrations/2026_07_16_learning_companion.php
php backend_php/database/migrations/2026_07_16_auth_hardening.php
```

It adds per-user starred words, streak-freeze state, reminder preferences,
offline review synchronization, and FCM device tokens.
The auth hardening migration adds privacy-safe login throttling storage.

## Professional chat migration

Deploy the backend files first, then run the idempotent chat migration before
opening the updated Flutter client:

```powershell
php backend_php/database/migrations/2026_07_18_professional_chat.php
```

The migration preserves existing messages and adds presence, delivery/read
timestamps, edit history, per-user soft deletion, delete-for-everyone, replies,
image attachments, synchronization timestamps, indexes, and message rate-limit
storage. It is safe to run again.

New authenticated endpoints:

```text
POST   /api/presence/heartbeat.php
GET    /api/presence/status.php?user_id=12
POST   /api/messages/delivered.php
POST   /api/messages/read.php
PUT    /api/messages/update.php
DELETE /api/messages/delete.php
POST   /api/messages/send_image.php
```

`send_image.php` expects multipart form data with an `image` part. Ensure
`backend_php/uploads/messages` is writable by PHP and that its `.htaccess` is
deployed so uploaded files cannot be executed as PHP.

## Legacy database import

Use the CLI-only importer when moving an older WordRise database into the
current production database. The JSON snapshot must contain a stable
`source_key` plus `users`, `lessons`, `words`, `quiz_results`,
`quiz_result_answers`, `mistakes`, `badges`, and `user_badges` arrays.

```powershell
php backend_php/database/migrations/import_legacy_snapshot.php legacy-snapshot.json
```

The import is transactional and idempotent. It maps legacy IDs to new IDs,
keeps existing accounts intact, skips session tokens, and rebuilds per-user
Smart Learn progress from historical quiz answers and mistakes.

## Firebase push

The PHP server sends notifications through FCM HTTP v1. Configure the Firebase
service-account values as server environment variables. Keep the private key on
the server only.

```powershell
$env:FIREBASE_PROJECT_ID="your-project-id"
$env:FIREBASE_CLIENT_EMAIL="firebase-adminsdk@your-project.iam.gserviceaccount.com"
$env:FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
$env:CRON_SECRET="replace-with-a-long-random-value"
```

Build or run Flutter with the matching public Firebase client values:

```powershell
flutter run `
  --dart-define=FIREBASE_API_KEY=... `
  --dart-define=FIREBASE_APP_ID=... `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... `
  --dart-define=FIREBASE_PROJECT_ID=... `
  --dart-define=FIREBASE_STORAGE_BUCKET=...
```

Call the reminder dispatcher every five minutes from hosting cron:

```text
POST /api/notifications/dispatch_reminders.php
X-Cron-Secret: the configured CRON_SECRET
```

When the hosting cron runs on the same server, prefer the protected CLI path;
it does not expose a secret over HTTP:

```cron
*/5 * * * * /usr/bin/php /absolute/path/to/wordrise-api/api/notifications/dispatch_reminders.php
```

## Example Requests

Register:

```json
POST /api/register.php
{
  "name": "Ali",
  "email": "ali@example.com",
  "password": "strong-password",
  "role": "student"
}
```

Create lesson:

```json
POST /api/lessons/create.php
Authorization: Bearer TOKEN
{
  "title": "Lesson 1",
  "description": "Food words",
  "category": "Food"
}
```

Add word:

```json
POST /api/words/create.php
Authorization: Bearer TOKEN
{
  "lesson_id": 1,
  "english_word": "apple",
  "uzbek_translation": "olma",
  "example_sentence": "I eat an apple.",
  "pronunciation": "AE-puhl"
}
```

Bulk add words:

```json
POST /api/words/bulk_create.php
Authorization: Bearer TOKEN
{
  "lesson_id": 1,
  "words": [
    {
      "word": "apple",
      "translation": "olma",
      "example": "I eat an apple.",
      "pronunciation": "AE-puhl"
    },
    {
      "english_word": "book",
      "uzbek_translation": "kitob"
    }
  ]
}
```

Flutter UI oddiy matnni ham qabul qiladi:

```text
apple - olma | I eat an apple. | AE-puhl
book - kitob
water = suv
teacher, o'qituvchi
```

Generate quiz:

```text
GET /api/quiz/generate.php?lesson_id=1&mode=multiple_choice
Authorization: Bearer TOKEN
```

Submit quiz:

```json
POST /api/quiz/submit.php
Authorization: Bearer TOKEN
{
  "lesson_id": 1,
  "mode": "multiple_choice",
  "answers": [
    {"word_id": 1, "answer": "olma"}
  ]
}
```
