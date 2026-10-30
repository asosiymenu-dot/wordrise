# WordRise — Comprehensive Product Review & Improvement Roadmap

> **Application**: WordRise v4.0.2 — English-Uzbek language learning app  
> **Platform**: Flutter (Android, iOS, Web)  
> **Reviewed**: 2026-08-01  
> **Review Scope**: Full product audit — UI, UX, Engineering, Performance, Accessibility, Security

---

## Executive Summary

WordRise is a **feature-rich Uzbek-to-English language learning app** with Smart Learning, quizzes, grammar lessons, battle mode, messaging, leaderboard, and speaking practice. The codebase demonstrates solid architecture with a clean service layer, proper offline support, and iOS-inspired design language.

**Production Readiness Score: 5.5 / 10**

The app has strong fundamentals but has **critical bugs, significant UX issues, hardcoded strings, missing features, and inconsistent design** that would severely impact retention for millions of users.

---

## SCREEN-BY-SCREEN ANALYSIS

---

### 1. Splash Screen ★★★★★★★☆☆☆ (7/10)

**File**: [splash_screen.dart](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/auth/splash_screen.dart)

**Purpose**: Loading screen while app initializes and fetches user profile.

**✅ What's Good**
- Clean glass card design with gradient background
- App branding is centered and immediately visible
- Loading indicator gives user feedback

**❌ Problems Found**
| # | Problem | Severity |
|---|---------|----------|
| 1 | No app logo — uses generic `auto_awesome` icon | Medium |
| 2 | No animation (fade-in, scale) — feels static and cheap | Medium |
| 3 | No timeout handling — can show forever on slow network | High |
| 4 | No progress indication (what's loading?) | Low |
| 5 | `CircularProgressIndicator` uses default theme color, not branded | Low |

**Recommended Changes**:
- Add actual app logo asset instead of icon
- Add scale/fade animation on entry (like Duolingo splash)
- Add a timeout with retry after 10 seconds
- Brand the progress indicator with AppColors.blue

---

### 2. Onboarding Screen ★★★★★★☆☆☆☆ (6/10)

**File**: [onboarding_screen.dart](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/auth/onboarding_screen.dart)

**Purpose**: First-time user introduction to the app's features.

**❌ Problems Found**
| # | Problem | Severity |
|---|---------|----------|
| 1 | Single-page onboarding — too simple for a feature-rich app | High |
| 2 | Uses hardcoded light theme gradient `Color(0xEEFFFFFF)` — broken in dark mode | Critical |
| 3 | Only 3 features shown — misses battle, speaking, grammar, messaging | Medium |
| 4 | `AppTextStyles.display` (line 44) uses hardcoded navy color — broken in dark mode | High |
| 5 | `AppTextStyles.body` (line 49) also uses hardcoded navy — broken in dark mode | High |
| 6 | No skip button | Medium |
| 7 | No illustrations/images — text-only feels amateur | High |
| 8 | No page dots or swipe gesture | Medium |

**Recommended Redesign**:
- Multi-page onboarding (3-4 pages) with PageView + dot indicators
- Each page highlights one core feature with an illustration
- Use `displayFor(context)` instead of `display` for dark mode support
- Add skip button in top-right
- Add "Welcome back" flow for returning users

---

### 3. Login / Register Screen ★★★★★★★☆☆☆ (7/10)

**File**: [login_register_screen.dart](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/auth/login_register_screen.dart)

**Purpose**: Authentication screen for login and registration.

**✅ What's Good**
- Clean card-based layout with shadow
- Google Sign-In properly implemented
- Username validation with regex
- Toggle between login/register works smoothly
- Error handling for API exceptions

**❌ Problems Found**
| # | Problem | Severity |
|---|---------|----------|
| 1 | Background color hardcoded to `Color(0xFFF0F4F8)` — completely broken in dark mode | Critical |
| 2 | Card color hardcoded to `Colors.white` — broken in dark mode | Critical |
| 3 | No "Forgot Password" feature — major user flow gap | Critical |
| 4 | No password visibility toggle (show/hide) | High |
| 5 | No password strength indicator on register | Medium |
| 6 | No email validation regex on register | High |
| 7 | `_required` validator only checks empty — accepts "   " after trim but allows single chars for password | Medium |
| 8 | No minimum password length enforcement | High |
| 9 | Google brand mark uses asset clipping trick that may break on different DPI | Low |
| 10 | No Terms of Service / Privacy Policy link | High |
| 11 | Login button shows "Login" but field label says "identifier" — inconsistent UX | Medium |
| 12 | TextButton for "switch mode" has no padding from Google button — cramped | Low |
| 13 | No input autofill hints (email, password) for password managers | Medium |

**Recommended Changes**:
- Add dark mode support with `AppColors.surface(context)` and `AppColors.isDark(context)`
- Add Forgot Password flow
- Add password visibility toggle icon
- Add email validation regex for registration
- Add minimum 6-char password validation
- Add Terms of Service link at bottom
- Add autofill hints: `AutofillHints.email`, `AutofillHints.password`

---

### 4. Home Screen ★★★★★☆☆☆☆☆ (5/10)

**File**: [home_screen.dart](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/home/home_screen.dart)

**Purpose**: Main dashboard with feature navigation grid.

**❌ Problems Found — CRITICAL**
| # | Problem | Severity |
|---|---------|----------|
| 1 | **HARDCODED UZBEK STRINGS everywhere** — `"Sanani o'zgartirish"`, `"YO'LOVCHI"`, `"Birga bir jang"`, `"Oktagon"`, `"kun"` — not localized | Critical |
| 2 | Verified badge shown for ALL users (`Icons.verified_rounded`) regardless of verification status | High |
| 3 | `_GridItem` uses `GestureDetector` — no Material ripple/ink splash feedback | High |
| 4 | `_LargeGridItem` uses `GestureDetector` — no touch feedback | High |
| 5 | `_FullWidthCard` uses `GestureDetector` — no touch feedback | High |
| 6 | Empty `SizedBox` placeholder at bottom of grid (line 193) — wastes space | Medium |
| 7 | Speaking icon is `format_list_numbered` — should be mic/headphones | Medium |
| 8 | No user avatar support — only shows initial letter | Medium |
| 9 | `Colors.white` hardcoded in text styles — broken in light mode where grid items use glass surface | High |
| 10 | `- $wordsLeft` shows negative sign prefix — confusing (line 354) | Medium |
| 11 | No pull-to-refresh | High |
| 12 | `_TopDashboard` has tap target on avatar but no onTap handler | Medium |
| 13 | `onOpenDiscover` appears twice — once in TopDashboard (search icon) and once in grid | Low |
| 14 | Messages button missing from home screen top bar | Medium |
| 15 | `_ProgressCard` background hardcoded to `Color(0xFF1E2A38)` — looks wrong in light mode | High |
| 16 | Bottom padding is 110px but there's no bottom nav bar visible | Medium |
| 17 | No greeting based on time of day | Low |
| 18 | No daily goal/streak motivation | Medium |

**Recommended Redesign**:
- Replace ALL hardcoded Uzbek strings with localization keys
- Replace `GestureDetector` with `InkWell` or `Material` wrapper for ripple effect
- Use `AppColors.glassSurface(context)` for progress card
- Add user avatar with `UserAvatar` widget (already exists in core/widgets)
- Add pull-to-refresh
- Only show verified badge if user has earned it
- Fix speaking icon to `Icons.mic_rounded`
- Add messages icon with unread badge in top bar

---

### 5. Profile Screen ★★★★★★☆☆☆☆ (6/10)

**File**: [profile_screen.dart](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/profile/profile_screen.dart)

**❌ Problems Found**
| # | Problem | Severity |
|---|---------|----------|
| 1 | **HARDCODED "YO'LOVCHI"** string (line 178) — not localized | Critical |
| 2 | **Hardcoded "Freezes"** string (line 214) — not localized | High |
| 3 | Progress button `onPressed: () {}` — **DEAD BUTTON** doing nothing | Critical |
| 4 | `_ProfileStatRow` shows chevron_right but rows are **not tappable** — misleading | High |
| 5 | Divider color hardcoded `Color(0xFF334155)` — wrong in light mode | High |
| 6 | Avatar always uses `Color(0xFF0F172A)` bg — broken in light mode | High |
| 7 | No logout confirmation dialog — immediate logout is destructive | Critical |
| 8 | Border `Colors.white.withValues(alpha: 0.05)` is invisible in light mode | Medium |
| 9 | No app version info shown | Medium |
| 10 | No account deletion option (required by App Store/Play Store policies) | Critical |
| 11 | Back button not using standard AppBar — custom implementation | Low |

**Recommended Changes**:
- Add logout confirmation dialog
- Add account deletion option
- Fix dead progress button or remove it
- Remove chevron from non-tappable stat rows
- Localize all hardcoded strings
- Add app version from `package_info_plus`

---

### 6. Quiz Mode Selection Screen ★★★★★★★☆☆☆ (7/10)

**File**: [quiz_mode_selection_screen.dart](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/quiz/quiz_mode_selection_screen.dart)

**❌ Problems Found**
| # | Problem | Severity |
|---|---------|----------|
| 1 | Hardcoded Uzbek: `'Test Qamrovi'`, `'Mavzu (Lesson)'`, `'Barcha so\'zlar'`, `'Qiyin so\'zlar'` | Critical |
| 2 | Only 1 practice mode shown (Typing) — Flashcard, Match Words, Battle, Speaking launchers exist in code but **removed from UI** | High |
| 3 | `_openFlashcard()`, `_openMatch()`, `_openReviewQuiz()`, `_openBattle()`, `_openSpeaking()` are **dead code** — methods exist but never called from UI | High |
| 4 | No AppBar/back button — user must use system back gesture | High |
| 5 | `_reviewLimit == 9999` comparison uses magic number for "all" — fragile | Medium |

---

### 7. Quiz Screen ★★★★★★☆☆☆☆ (6/10)

**File**: [quiz_screen.dart](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/quiz/quiz_screen.dart)

**❌ Problems Found**
| # | Problem | Severity |
|---|---------|----------|
| 1 | Settings button `onPressed: () {}` — **DEAD BUTTON** | Critical |
| 2 | Flag button `onPressed: () {}` — **DEAD BUTTON** | Critical |
| 3 | `_normalize` function defined (line 675) but **never used** — dead code | Low |
| 4 | No "Are you sure?" dialog when pressing back mid-quiz — progress lost | High |
| 5 | 30-second timer is not configurable | Medium |
| 6 | No skip button for questions | Medium |
| 7 | `'True / False'` mode title not localized (line 692) | High |
| 8 | Auto-advance after 1750ms gives no control — user can't review | Medium |

---

### 8. Smart Learn Screen ★★★★★★★★☆☆ (8/10)

**File**: [smart_learn_screen.dart](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/smart_learn/smart_learn_screen.dart)

**✅ What's Good**
- Well-structured learning flow with feedback
- Hint system for struggling users
- TTS pronunciation support
- Offline mode support
- Progress tracking with visual indicators
- Skeleton loading states

**❌ Problems Found**
| # | Problem | Severity |
|---|---------|----------|
| 1 | No "Are you sure?" dialog when closing mid-session | High |
| 2 | Completed view only shows 2 metrics (accuracy & answers) — feels thin | Medium |
| 3 | No celebration animation on completion (confetti, etc.) | Medium |
| 4 | `FlutterTts` initialized without error feedback to user | Low |

---

### 9. Lesson List Screen ★★★★★★★☆☆☆ (7/10)

**File**: [lesson_list_screen.dart](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/lessons/lesson_list_screen.dart)

**✅ What's Good**
- Full CRUD for lessons
- Search/filter functionality
- Import/Export support (JSON + table)
- AI lesson generation
- Share system with deep links
- Public/Private toggle
- Permission-based actions

**❌ Problems Found**
| # | Problem | Severity |
|---|---------|----------|
| 1 | Import sheet is scrollable but may overflow on small screens — no `SafeArea` inside modal | Medium |
| 2 | No sort options (by date, alphabetical, word count) | Medium |
| 3 | No lesson categories filtering | Medium |
| 4 | Delete has confirmation but export doesn't indicate copy success on all platforms | Low |
| 5 | No back button — relies on system gesture | Medium |

---

### 10. Battle Screen ★★★★★★★☆☆☆ (7/10)

**File**: [battle_screen.dart](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/battle/battle_screen.dart)

**✅ What's Good**
- Real-time polling with 1-second refresh
- Countdown animation with scale transitions
- Rematch functionality
- Score visualization

**❌ Problems Found**
| # | Problem | Severity |
|---|---------|----------|
| 1 | 1-second poll + 1-second timer = 2 timers running simultaneously — battery drain | High |
| 2 | `_sameAnswer` duplicated between battle_screen.dart and quiz_screen.dart | Medium |
| 3 | No "Are you sure?" when pressing back during active battle | High |
| 4 | No error state for expired/cancelled battles | Medium |

---

### 11. Messages Screen ★★★★★★★☆☆☆ (7/10)

**File**: [messages_screen.dart](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/messages/messages_screen.dart)

**Key Concern**: This file is **3197 lines / 104KB** — a **God Object** that needs decomposition.

**❌ Problems Found**
| # | Problem | Severity |
|---|---------|----------|
| 1 | **3197 lines in single file** — maintainability nightmare | Critical |
| 2 | Contains conversation list, chat thread, user search, battle invites, image picking — all in one file | Critical |
| 3 | Polling interval of 2-3 seconds for chat — significant battery drain | High |
| 4 | No message pagination (loads all messages at once?) | High |

---

### 12. Grammar Screens ★★★★★★★☆☆☆ (7/10)

**Files**: 6 files in [grammar/](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/grammar/)

Good feature set with levels, topics, lessons, and exercises. Admin review screen exists.

---

### 13. Leaderboard Screen ★★★★★★★☆☆☆ (7/10)

**File**: [leaderboard_screen.dart](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/leaderboard/leaderboard_screen.dart)

**✅ Well structured** with scope filters, friend filter, profile navigation.

**❌ Problems**: No position highlighting for current user, no podium for top 3.

---

### 14. Speaking Screen ★★★★★★★☆☆☆ (7/10)

**File**: [speaking_screen.dart](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/speaking/speaking_screen.dart)

**✅ Good**: Beautiful mic button with gradient, topic selection, AI feedback with score.

**❌ Problems**: No waveform visualization, history limit of 8 isn't shown to user.

---

### 15. Forced Update Screen ★★★★★★★★☆☆ (8/10)

**File**: [forced_update_screen.dart](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/update/forced_update_screen.dart)

**✅ Well designed**: Clean, informative, with release notes and file size. Good `PopScope` to prevent bypass.

---

## CRITICAL BUGS

| # | Bug | Location | Impact |
|---|-----|----------|--------|
| 1 | **`BadgesScreen` imported but feature directory doesn't exist** — **compilation error** | [app_shell.dart:10](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/app/app_shell.dart#L10) | 🔴 App won't compile |
| 2 | **Login/Register screen completely broken in dark mode** — white card on white-ish bg | [login_register_screen.dart:167](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/auth/login_register_screen.dart#L167) | 🔴 Half users can't use auth |
| 3 | **Onboarding broken in dark mode** — hardcoded white gradient | [onboarding_screen.dart:28-31](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/auth/onboarding_screen.dart#L28) | 🔴 First impression destroyed |
| 4 | **No logout confirmation** — one accidental tap logs user out | [profile_screen.dart:265](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/profile/profile_screen.dart#L265) | 🔴 Data loss feeling |
| 5 | **Dead progress button** in profile — `onPressed: () {}` | [profile_screen.dart:185](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/profile/profile_screen.dart#L185) | 🟡 Broken trust |
| 6 | **Dead settings/flag buttons** in quiz — `onPressed: () {}` | [quiz_screen.dart:465-475](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/features/quiz/quiz_screen.dart#L465) | 🟡 Broken trust |
| 7 | **Deep link crash** — `_user!` force unwrap at line 364 when user is null | [app_shell.dart:364](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/app/app_shell.dart#L364) | 🔴 Crash |
| 8 | **`_showOnboarding = false` set after network error** — user skips onboarding if first load has token + network error | [app_shell.dart:415](file:///c:/Users/Abbosbek/Desktop/wordrisee/lib/app/app_shell.dart#L415) | 🟡 Logic error |

---

## TOP 100 IMPROVEMENTS (Ranked by Impact)

### 🔴 Critical (Ship Blockers) — Do First

| # | Improvement | Category | Effort |
|---|------------|----------|--------|
| 1 | Fix/create `BadgesScreen` or remove import — **app won't compile** | Bug | 15 min |
| 2 | Fix dark mode on Login/Register screen | UI | 30 min |
| 3 | Fix dark mode on Onboarding screen | UI | 20 min |
| 4 | Add logout confirmation dialog | UX | 20 min |
| 5 | Fix force-unwrap crash on deep link when user is null | Bug | 10 min |
| 6 | Localize ALL hardcoded Uzbek strings (home, profile, quiz selection) | i18n | 2 hrs |
| 7 | Add Forgot Password flow | Feature | 4 hrs |
| 8 | Add account deletion (App Store/Play Store requirement) | Compliance | 4 hrs |
| 9 | Remove dead buttons (settings, flag in quiz; progress in profile) or implement them | UX | 1 hr |
| 10 | Add Terms of Service / Privacy Policy links | Compliance | 1 hr |

### 🟠 High Priority — Before Launch

| # | Improvement | Category | Effort |
|---|------------|----------|--------|
| 11 | Replace `GestureDetector` with `InkWell` on all home screen cards | UX | 30 min |
| 12 | Fix `_ProgressCard` light mode — hardcoded dark bg `Color(0xFF1E2A38)` | UI | 15 min |
| 13 | Fix hardcoded dark dividers in profile `Color(0xFF334155)` | UI | 15 min |
| 14 | Add "Are you sure?" dialog when leaving active quiz/battle/smart learn | UX | 1 hr |
| 15 | Add password visibility toggle on auth screen | UX | 20 min |
| 16 | Add email validation on registration | UX | 15 min |
| 17 | Add minimum password length validation (6+ chars) | Security | 10 min |
| 18 | Fix wrong icon for Speaking (`format_list_numbered` → `mic_rounded`) | UI | 5 min |
| 19 | Fix verified badge showing for ALL users | UX | 10 min |
| 20 | Split `messages_screen.dart` (3197 lines) into separate files | Tech Debt | 4 hrs |
| 21 | Add pull-to-refresh on Home screen | UX | 30 min |
| 22 | Fix `_showOnboarding = false` race condition with network errors | Bug | 20 min |
| 23 | Add autofill hints for password managers | UX | 10 min |
| 24 | Add back/close button on Quiz Mode Selection screen | UX | 10 min |
| 25 | Remove dead code methods in quiz_mode_selection_screen | Tech Debt | 15 min |

### 🟡 Medium Priority — First Sprint After Launch

| # | Improvement | Category | Effort |
|---|------------|----------|--------|
| 26 | Multi-page onboarding with illustrations | UX | 8 hrs |
| 27 | Add app logo asset (replace generic icon on splash) | Branding | 1 hr |
| 28 | Splash screen animation (scale + fade) | Polish | 1 hr |
| 29 | Splash screen timeout with retry | UX | 30 min |
| 30 | Add user avatar support on home screen (use existing UserAvatar widget) | UI | 30 min |
| 31 | Add messages icon with unread badge to home top bar | UX | 30 min |
| 32 | Fix `wordsLeft` negative display format | UI | 10 min |
| 33 | Remove duplicate Discover entry (grid + top bar search icon) | UX | 10 min |
| 34 | Add app version in profile settings | UX | 15 min |
| 35 | Celebration animation on Smart Learn completion | Polish | 2 hrs |
| 36 | Add leaderboard podium for top 3 | UI | 2 hrs |
| 37 | Highlight current user position in leaderboard | UX | 30 min |
| 38 | Add waveform visualization for speaking | UI | 3 hrs |
| 39 | Reduce battle poll interval or use WebSockets | Performance | 4 hrs |
| 40 | Add lesson sort options (alphabetical, date, word count) | UX | 2 hrs |
| 41 | Extract `_sameAnswer` into shared utility | Tech Debt | 15 min |
| 42 | Add password strength indicator on registration | UX | 2 hrs |
| 43 | Make quiz timer configurable (15/30/60 seconds) | Feature | 1 hr |
| 44 | Add skip question button in quiz | UX | 30 min |
| 45 | Add "review question" option instead of auto-advance after 1750ms | UX | 1 hr |
| 46 | Localize `'True / False'` mode title | i18n | 5 min |
| 47 | Add category filtering for lessons | UX | 2 hrs |
| 48 | Remove bottom padding 110px on home when no bottom nav exists | UI | 5 min |
| 49 | Time-of-day greeting on home ("Good morning, Name!") | UX | 30 min |
| 50 | Add daily goal motivation card on home | UX | 2 hrs |

### 🟢 Low Priority — Polish Phase

| # | Improvement | Category | Effort |
|---|------------|----------|--------|
| 51 | Add biometric authentication (fingerprint/face) | Security | 4 hrs |
| 52 | Add remember me / stay logged in option | UX | 1 hr |
| 53 | Add profile picture upload from existing `image_picker` | Feature | 2 hrs |
| 54 | Add streak freeze purchase/use UI | Feature | 3 hrs |
| 55 | Add badge/achievement system (BadgesScreen) | Feature | 8 hrs |
| 56 | Add flashcard and match modes back to quiz selection UI | Feature | 1 hr |
| 57 | Add haptic feedback to all interactive elements | Polish | 1 hr |
| 58 | Add confetti animation on quiz completion | Polish | 1 hr |
| 59 | Add sound effects for correct/wrong answers | Polish | 2 hrs |
| 60 | Add daily reminder notification customization UI | Feature | 2 hrs |
| 61 | Admin panel for content management | Feature | 8 hrs |
| 62 | Add offline indicator with cached data count | UX | 1 hr |
| 63 | Add word pronunciation on long-press | UX | 1 hr |
| 64 | Add lesson progress percentage on cards | UI | 30 min |
| 65 | Add share quiz results to social media | Feature | 2 hrs |
| 66 | Add typing test leaderboard | Feature | 3 hrs |
| 67 | Add dark mode preview in theme picker | UX | 1 hr |
| 68 | Add custom font (Inter/Outfit) instead of Roboto | Branding | 1 hr |
| 69 | Reduce messages polling to 5-10 seconds when not in chat | Performance | 30 min |
| 70 | Add chat message pagination | Performance | 3 hrs |
| 71 | Add image lazy loading in chat | Performance | 1 hr |
| 72 | Add connection quality indicator | UX | 2 hrs |
| 73 | Add error boundary widget for crash resilience | Stability | 2 hrs |
| 74 | Add analytics/tracking (Firebase Analytics) | Business | 4 hrs |
| 75 | Add A/B testing framework | Business | 8 hrs |
| 76 | Add widget tests for critical flows | QA | 8 hrs |
| 77 | Add integration tests for auth flow | QA | 4 hrs |
| 78 | Add Sentry/Crashlytics for error tracking | Stability | 2 hrs |
| 79 | Add semantic labels to all icons for screen readers | A11y | 2 hrs |
| 80 | Add minimum contrast ratios on all text | A11y | 2 hrs |
| 81 | Add large text support testing | A11y | 1 hr |
| 82 | Add keyboard navigation for web | A11y | 4 hrs |
| 83 | Rate limiting on auth endpoints (client side) | Security | 1 hr |
| 84 | Token refresh mechanism | Security | 3 hrs |
| 85 | Certificate pinning for API calls | Security | 2 hrs |
| 86 | Obfuscate API base URL | Security | 30 min |
| 87 | Add ProGuard/R8 rules for release builds | Security | 1 hr |
| 88 | Add splash screen branding per platform (Android 12 splash) | Polish | 1 hr |
| 89 | Add adaptive icon for Android | Branding | 30 min |
| 90 | Add iPad/tablet layout support | Platform | 8 hrs |
| 91 | Add landscape orientation support | Platform | 4 hrs |
| 92 | Reduce `GradientBackground` animation CPU usage on low-end devices | Performance | 1 hr |
| 93 | Use `const` constructors consistently | Performance | 1 hr |
| 94 | Add loading shimmer to home screen on first load | UX | 1 hr |
| 95 | Add empty/loading states for all FutureBuilder usage | UX | 2 hrs |
| 96 | Dispose all ScrollControllers properly | Bug Prevention | 30 min |
| 97 | Add `WillPopScope` equivalent to all quiz/learning flows | UX | 1 hr |
| 98 | Move API error messages to localization | i18n | 2 hrs |
| 99 | Remove `ftp_test.py` and `test_ftp.py` from root (security risk) | Security | 5 min |
| 100 | Remove `temp_migrate.php` from root (security risk) | Security | 5 min |

---

## CATEGORY SUMMARIES

### 🎨 UI Problems (22 issues)
- Dark mode completely broken on 3 screens (login, onboarding, home progress card)
- Hardcoded colors throughout (profile dividers, card backgrounds)
- Wrong icons (speaking, verified badge)
- Missing Material feedback (ripple/ink) on home grid items
- No user avatar support on home

### 🧠 UX Problems (18 issues)
- No Forgot Password
- No logout confirmation
- Dead buttons that do nothing
- No back buttons on several screens
- No exit confirmation on quizzes
- Auto-advance gives no control
- Single-page basic onboarding

### 🐛 Bugs (8 issues)
- BadgesScreen import from non-existent directory
- Force-unwrap crash on deep links
- Onboarding race condition
- Dark mode rendering on 3 screens

### ⚡ Performance Problems (5 issues)
- 3197-line God Object (messages_screen)
- Dual timers in battle mode
- Aggressive polling intervals
- 32-second looping gradient animation
- No message pagination

### ♿ Accessibility Problems (5 issues)
- No semantic labels on many icons
- Missing contrast ratios on muted text
- No large text testing
- No keyboard navigation (web)
- Some interactive elements below 44px minimum

### 🔒 Security Problems (6 issues)
- API base URL exposed in plain text
- No certificate pinning
- No token refresh mechanism
- No password strength enforcement
- FTP test files in repo root
- PHP migration script in repo root

### 📝 Technical Debt (6 issues)
- 3197-line messages_screen.dart
- Dead code (5+ unused methods)
- Duplicated answer comparison logic
- Hardcoded strings bypassing localization
- No automated tests
- `data/` directory exists but is empty

---

## IMPLEMENTATION ROADMAP

### Phase 1: Ship Blockers (Week 1) — 2 days
1. ~~Fix `BadgesScreen` compilation error~~
2. Fix all dark mode issues (login, onboarding, home, profile)
3. Localize all hardcoded strings
4. Add logout confirmation dialog
5. Fix deep link crash
6. Remove/implement dead buttons
7. Remove security-risk files from root

### Phase 2: Critical UX (Week 1-2) — 3 days
8. Add Forgot Password flow
9. Add account deletion
10. Add Terms of Service link
11. Add password toggle + validation
12. Add back buttons to Quiz Mode, Lesson List
13. Replace GestureDetector with InkWell everywhere
14. Add exit confirmations on learning flows

### Phase 3: Polish & Performance (Week 2-3) — 5 days
15. Split messages_screen.dart into 4-5 files
16. Multi-page onboarding redesign
17. Add splash animation and branded logo
18. Add pull-to-refresh on home
19. Reduce polling intervals
20. Add user avatar support
21. Fix verified badge logic

### Phase 4: Features & Engagement (Week 3-4) — 5 days
22. Implement BadgesScreen feature
23. Restore Flashcard + Match modes in quiz
24. Add celebration animations
25. Add leaderboard podium
26. Add daily goal motivation
27. Add sound effects

### Phase 5: Quality & Security (Week 4+) — Ongoing
28. Add widget/integration tests
29. Add crash reporting (Sentry)
30. Add analytics
31. Certificate pinning
32. Token refresh
33. Accessibility audit

> [!IMPORTANT]
> **Phase 1 must be completed before any release.** The `BadgesScreen` import alone prevents compilation, and dark mode issues affect 40%+ of users on modern Android/iOS.
