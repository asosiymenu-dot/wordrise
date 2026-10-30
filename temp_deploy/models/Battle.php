<?php

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/Lesson.php';
require_once __DIR__ . '/User.php';
require_once __DIR__ . '/AppNotification.php';

final class Battle
{
    public static function create(array $user, ?int $lessonId, int $limit, int $durationSeconds, string $direction): array
    {
        $created = self::createRoom($user, null, $lessonId, $limit, $durationSeconds, $direction, null);
        return self::state($user, $created['battle_id']);
    }

    public static function invite(
        array $user,
        int $receiverId,
        ?int $lessonId,
        int $limit,
        int $durationSeconds,
        string $direction,
        ?int $rematchOfId = null
    ): array {
        if ($receiverId <= 0 || $receiverId === (int)$user['id']) {
            throw new InvalidArgumentException('Battle opponent is invalid.');
        }
        if (!User::findById($receiverId)) {
            throw new RuntimeException('User not found.');
        }
        $invites = Database::table('battle_invites');
        $pending = Database::connection()->prepare(
            "SELECT id FROM {$invites}
             WHERE ((sender_id = ? AND receiver_id = ?)
                 OR (sender_id = ? AND receiver_id = ?))
               AND status = 'pending' AND expires_at > NOW()
             LIMIT 1"
        );
        $pending->execute([(int)$user['id'], $receiverId, $receiverId, (int)$user['id']]);
        if ($pending->fetch()) {
            throw new RuntimeException('Bu foydalanuvchiga yuborilgan battle taklifi hali kutilmoqda.');
        }
        $created = self::createRoom(
            $user,
            $receiverId,
            $lessonId,
            $limit,
            $durationSeconds,
            $direction,
            $rematchOfId
        );
        return self::inviteById($created['invite_id'], (int)$user['id']);
    }

    public static function respondInvite(array $user, int $inviteId, string $action): array
    {
        if (!in_array($action, ['accept', 'decline', 'cancel'], true)) {
            throw new InvalidArgumentException('Invalid battle invite action.');
        }
        $pdo = Database::connection();
        $invites = Database::table('battle_invites');
        $rooms = Database::table('battle_rooms');
        $pdo->beginTransaction();
        try {
            $stmt = $pdo->prepare("SELECT * FROM {$invites} WHERE id = ? LIMIT 1 FOR UPDATE");
            $stmt->execute([$inviteId]);
            $invite = $stmt->fetch();
            if (!$invite) {
                throw new RuntimeException('Battle invite not found.');
            }
            if ($invite['status'] === 'pending' && strtotime((string)$invite['expires_at']) <= time()) {
                self::expireInviteRows($invite);
                $invite['status'] = 'expired';
            }
            if ($invite['status'] !== 'pending') {
                $pdo->commit();
                return [
                    'invite' => self::inviteById($inviteId, (int)$user['id']),
                    'battle' => null,
                ];
            }

            $userId = (int)$user['id'];
            if ($action === 'cancel') {
                if ((int)$invite['sender_id'] !== $userId) {
                    throw new LogicException('Only the sender can cancel this invite.');
                }
                $nextStatus = 'cancelled';
            } else {
                if ((int)$invite['receiver_id'] !== $userId) {
                    throw new LogicException('Only the invited user can respond.');
                }
                $nextStatus = $action === 'accept' ? 'accepted' : 'declined';
            }

            $update = $pdo->prepare(
                "UPDATE {$invites} SET status = ?, responded_at = NOW(), updated_at = NOW()
                 WHERE id = ? AND status = 'pending'"
            );
            $update->execute([$nextStatus, $inviteId]);
            if ($update->rowCount() !== 1) {
                throw new RuntimeException('Battle invite was already updated.');
            }

            if ($nextStatus === 'accepted') {
                $startsAt = (new DateTimeImmutable('+3 seconds'))->format('Y-m-d H:i:s');
                $roomUpdate = $pdo->prepare(
                    "UPDATE {$rooms}
                     SET opponent_id = ?, status = 'active', starts_at = ?, started_at = ?,
                         version = version + 1, updated_at = NOW()
                     WHERE id = ? AND status = 'waiting'"
                );
                $roomUpdate->execute([$userId, $startsAt, $startsAt, (int)$invite['battle_id']]);
                if ($roomUpdate->rowCount() !== 1) {
                    throw new RuntimeException('Battle could not be started.');
                }
                AppNotification::create(
                    (int)$invite['sender_id'],
                    'battle_accepted',
                    'Battle qabul qilindi',
                    $user['name'] . ' battle taklifingizni qabul qildi.',
                    [
                        'battle_id' => (int)$invite['battle_id'],
                        'invite_id' => $inviteId,
                        'responder_name' => (string)$user['name'],
                    ]
                );
            } else {
                $roomUpdate = $pdo->prepare(
                    "UPDATE {$rooms}
                     SET status = 'cancelled', finished_at = NOW(), finished_reason = ?,
                         version = version + 1, updated_at = NOW()
                     WHERE id = ? AND status = 'waiting'"
                );
                $roomUpdate->execute([$nextStatus, (int)$invite['battle_id']]);
                $notifyUserId = $nextStatus === 'declined'
                    ? (int)$invite['sender_id']
                    : (int)$invite['receiver_id'];
                AppNotification::create(
                    $notifyUserId,
                    'battle_' . $nextStatus,
                    'Battle taklifi yangilandi',
                    $nextStatus === 'declined' ? 'Battle taklifi rad etildi.' : 'Battle taklifi bekor qilindi.',
                    [
                        'battle_id' => (int)$invite['battle_id'],
                        'invite_id' => $inviteId,
                        'actor_name' => (string)$user['name'],
                    ]
                );
            }

            $pdo->commit();
            return [
                'invite' => self::inviteById($inviteId, $userId),
                'battle' => $nextStatus === 'accepted'
                    ? self::state($user, (int)$invite['battle_id'])
                    : null,
            ];
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }
    }

    public static function rematch(array $user, int $battleId): array
    {
        $room = self::roomForUser($battleId, $user);
        if (!$room || $room['status'] !== 'finished') {
            throw new RuntimeException('Only a finished battle can be replayed.');
        }
        $userId = (int)$user['id'];
        $receiverId = (int)$room['creator_id'] === $userId
            ? (int)$room['opponent_id']
            : (int)$room['creator_id'];
        if ($receiverId <= 0) {
            throw new RuntimeException('Battle opponent not found.');
        }
        return self::invite(
            $user,
            $receiverId,
            empty($room['lesson_id']) ? null : (int)$room['lesson_id'],
            (int)$room['question_limit'],
            (int)$room['duration_seconds'],
            (string)$room['direction'],
            $battleId
        );
    }

    public static function join(array $user, string $roomCode): array
    {
        $roomCode = strtoupper(trim($roomCode));
        if ($roomCode === '') {
            throw new InvalidArgumentException('Battle kodi kerak.');
        }
        $rooms = Database::table('battle_rooms');
        $stmt = Database::connection()->prepare("SELECT * FROM {$rooms} WHERE room_code = ? LIMIT 1");
        $stmt->execute([$roomCode]);
        $room = $stmt->fetch();
        if (!$room) {
            throw new RuntimeException('Battle xonasi topilmadi.');
        }
        $userId = (int)$user['id'];
        if ((int)$room['creator_id'] === $userId) {
            return self::state($user, (int)$room['id']);
        }
        if (!empty($room['invited_user_id'])) {
            if ((int)$room['invited_user_id'] !== $userId) {
                throw new LogicException('This room is reserved for another user.');
            }
            $invites = Database::table('battle_invites');
            $stmt = Database::connection()->prepare(
                "SELECT id FROM {$invites} WHERE battle_id = ? LIMIT 1"
            );
            $stmt->execute([(int)$room['id']]);
            $inviteId = (int)$stmt->fetchColumn();
            if ($inviteId > 0) {
                $result = self::respondInvite($user, $inviteId, 'accept');
                if ($result['battle'] !== null) {
                    return $result['battle'];
                }
            }
        }
        if ($room['status'] !== 'waiting' || !empty($room['opponent_id'])) {
            throw new RuntimeException('Bu battle allaqachon boshlangan.');
        }
        $startsAt = (new DateTimeImmutable('+3 seconds'))->format('Y-m-d H:i:s');
        $stmt = Database::connection()->prepare(
            "UPDATE {$rooms}
             SET opponent_id = ?, status = 'active', starts_at = ?, started_at = ?,
                 version = version + 1, updated_at = NOW()
             WHERE id = ? AND status = 'waiting' AND opponent_id IS NULL"
        );
        $stmt->execute([$userId, $startsAt, $startsAt, (int)$room['id']]);
        if ($stmt->rowCount() === 0) {
            throw new RuntimeException('Battle xonasiga qoʼshilib boʼlmadi.');
        }
        return self::state($user, (int)$room['id']);
    }

    public static function answer(array $user, int $battleId, int $questionId, string $answer, int $clientAnswerMs): array
    {
        $pdo = Database::connection();
        $rooms = Database::table('battle_rooms');
        $questions = Database::table('battle_questions');
        $answers = Database::table('battle_answers');
        $pdo->beginTransaction();
        try {
            $stmt = $pdo->prepare(
                "SELECT * FROM {$rooms}
                 WHERE id = ? AND (creator_id = ? OR opponent_id = ?)
                 LIMIT 1 FOR UPDATE"
            );
            $stmt->execute([$battleId, (int)$user['id'], (int)$user['id']]);
            $room = $stmt->fetch();
            if (!$room) {
                throw new RuntimeException('Battle topilmadi.');
            }
            if ($room['status'] !== 'active') {
                $pdo->commit();
                return self::state($user, $battleId);
            }
            if (self::countdownSeconds($room) > 0) {
                throw new LogicException('Battle countdown is still active.');
            }
            if (self::timeLeft($room) <= 0) {
                $pdo->commit();
                self::markFinished($battleId, 'time');
                return self::state($user, $battleId);
            }

            $expectedQuestionId = self::nextQuestionId($battleId, (int)$user['id']);
            if ($expectedQuestionId === null) {
                $pdo->commit();
                self::finishIfComplete($battleId);
                return self::state($user, $battleId);
            }
            if ($expectedQuestionId !== $questionId) {
                throw new LogicException('Only the current server question can be answered.');
            }

            $stmt = $pdo->prepare(
                "SELECT * FROM {$questions} WHERE id = ? AND battle_id = ? LIMIT 1"
            );
            $stmt->execute([$questionId, $battleId]);
            $question = $stmt->fetch();
            if (!$question) {
                throw new RuntimeException('Battle savoli topilmadi.');
            }

            $isCorrect = self::sameAnswer($answer, (string)$question['correct_answer']);
            $serverAnswerMs = self::serverAnswerMs($room, $battleId, (int)$user['id']);
            $stmt = $pdo->prepare(
                "INSERT INTO {$answers}
                 (battle_id, question_id, user_id, given_answer, is_correct, answered_ms, client_answer_ms)
                 VALUES (?, ?, ?, ?, ?, ?, ?)"
            );
            $stmt->execute([
                $battleId,
                $questionId,
                (int)$user['id'],
                trim($answer),
                $isCorrect ? 1 : 0,
                $serverAnswerMs,
                max(0, min($clientAnswerMs, 300000)),
            ]);
            $version = $pdo->prepare(
                "UPDATE {$rooms} SET version = version + 1, updated_at = NOW() WHERE id = ?"
            );
            $version->execute([$battleId]);
            $pdo->commit();

            self::finishIfComplete($battleId);
            return self::state($user, $battleId);
        } catch (PDOException $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            if ((int)$error->errorInfo[1] === 1062) {
                return self::state($user, $battleId);
            }
            throw $error;
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }
    }

    public static function state(array $user, int $battleId): array
    {
        $room = self::roomForUser($battleId, $user);
        if (!$room) {
            throw new RuntimeException('Battle topilmadi.');
        }
        if ($room['status'] === 'active' && self::countdownSeconds($room) <= 0 && self::timeLeft($room) <= 0) {
            self::markFinished($battleId, 'time');
            $room = self::roomForUser($battleId, $user);
        }

        $myAnswers = self::answersForUser($battleId, (int)$user['id']);
        $answeredByQuestion = [];
        foreach ($myAnswers as $answer) {
            $answeredByQuestion[(int)$answer['question_id']] = true;
        }
        $questionsTable = Database::table('battle_questions');
        $stmt = Database::connection()->prepare(
            "SELECT * FROM {$questionsTable} WHERE battle_id = ? ORDER BY order_index ASC"
        );
        $stmt->execute([$battleId]);
        $finished = in_array($room['status'], ['finished', 'cancelled'], true);
        $answeredCount = count($myAnswers);
        $questions = [];
        foreach ($stmt->fetchAll() as $row) {
            $options = json_decode((string)$row['options'], true);
            $reveal = $finished || isset($answeredByQuestion[(int)$row['id']]);
            $visible = $finished || (int)$row['order_index'] <= $answeredCount;
            $questions[] = [
                'id' => (int)$row['id'],
                'word_id' => $visible ? (int)$row['word_id'] : 0,
                'prompt' => $visible ? $row['prompt'] : '',
                'correct_answer' => $reveal ? $row['correct_answer'] : null,
                'options' => $visible && is_array($options)
                    ? array_values(array_map('strval', $options))
                    : [],
                'order_index' => (int)$row['order_index'],
            ];
        }

        $countdown = self::countdownSeconds($room);
        $phase = $room['status'];
        if ($room['status'] === 'active' && $countdown > 0) {
            $phase = 'countdown';
        }
        return [
            'id' => (int)$room['id'],
            'room_code' => $room['room_code'],
            'status' => $room['status'],
            'phase' => $phase,
            'direction' => $room['direction'],
            'question_limit' => (int)$room['question_limit'],
            'duration_seconds' => (int)$room['duration_seconds'],
            'time_left' => self::timeLeft($room),
            'countdown_seconds' => $countdown,
            'started_at' => $room['started_at'],
            'starts_at' => $room['starts_at'],
            'finished_at' => $room['finished_at'],
            'finished_reason' => $room['finished_reason'],
            'version' => (int)$room['version'],
            'server_now' => (new DateTimeImmutable())->format('Y-m-d H:i:s'),
            'creator' => self::publicUser((int)$room['creator_id']),
            'opponent' => empty($room['opponent_id']) ? null : self::publicUser((int)$room['opponent_id']),
            'questions' => $questions,
            'my_answers' => $myAnswers,
            'scoreboard' => self::scoreboard($room),
        ];
    }

    public static function inviteForMessage(int $messageId, int $viewerId): ?array
    {
        $invites = Database::table('battle_invites');
        $stmt = Database::connection()->prepare(
            "SELECT id FROM {$invites}
             WHERE message_id = ? AND (sender_id = ? OR receiver_id = ?) LIMIT 1"
        );
        $stmt->execute([$messageId, $viewerId, $viewerId]);
        $inviteId = (int)$stmt->fetchColumn();
        return $inviteId > 0 ? self::inviteById($inviteId, $viewerId) : null;
    }

    private static function createRoom(
        array $user,
        ?int $invitedUserId,
        ?int $lessonId,
        int $limit,
        int $durationSeconds,
        string $direction,
        ?int $rematchOfId
    ): array {
        $direction = self::sanitizeDirection($direction);
        $limit = max(5, min($limit, 50));
        $durationSeconds = max(30, min($durationSeconds, 300));
        $words = self::wordsPool($user, $lessonId);
        if (count($words) < 4) {
            throw new RuntimeException('Battle uchun kamida 4 ta soʼz kerak.');
        }
        shuffle($words);
        $selected = array_slice($words, 0, min($limit, count($words)));
        $pdo = Database::connection();
        $rooms = Database::table('battle_rooms');
        $questions = Database::table('battle_questions');
        $invites = Database::table('battle_invites');
        $messages = Database::table('messages');
        $pdo->beginTransaction();
        try {
            if ($invitedUserId !== null) {
                self::lockInvitePair((int)$user['id'], $invitedUserId);
                self::assertNoPendingInvite((int)$user['id'], $invitedUserId);
            }
            $code = self::generateRoomCode();
            $stmt = $pdo->prepare(
                "INSERT INTO {$rooms}
                 (room_code, creator_id, invited_user_id, lesson_id, direction,
                  question_limit, duration_seconds, rematch_of_id)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
            );
            $stmt->execute([
                $code,
                (int)$user['id'],
                $invitedUserId,
                $lessonId === null || $lessonId <= 0 ? null : $lessonId,
                $direction,
                count($selected),
                $durationSeconds,
                $rematchOfId,
            ]);
            $battleId = (int)$pdo->lastInsertId();

            $questionStmt = $pdo->prepare(
                "INSERT INTO {$questions}
                 (battle_id, word_id, prompt, correct_answer, options, order_index)
                 VALUES (?, ?, ?, ?, ?, ?)"
            );
            foreach ($selected as $index => $word) {
                $question = self::questionPayload($word, $words, $direction);
                $questionStmt->execute([
                    $battleId,
                    (int)$word['id'],
                    $question['prompt'],
                    $question['correct_answer'],
                    json_encode($question['options'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
                    $index,
                ]);
            }

            $inviteId = null;
            if ($invitedUserId !== null) {
                $expiresAt = (new DateTimeImmutable('+10 minutes'))->format('Y-m-d H:i:s');
                $inviteStmt = $pdo->prepare(
                    "INSERT INTO {$invites}
                     (battle_id, sender_id, receiver_id, expires_at) VALUES (?, ?, ?, ?)"
                );
                $inviteStmt->execute([$battleId, (int)$user['id'], $invitedUserId, $expiresAt]);
                $inviteId = (int)$pdo->lastInsertId();
                $metadata = json_encode(
                    ['battle_id' => $battleId, 'invite_id' => $inviteId],
                    JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
                );
                $messageStmt = $pdo->prepare(
                    "INSERT INTO {$messages}
                     (sender_id, receiver_id, body, message_type, metadata_json)
                     VALUES (?, ?, ?, 'battle_invite', ?)"
                );
                $messageStmt->execute([
                    (int)$user['id'],
                    $invitedUserId,
                    'Vocabulary Battle taklifi',
                    $metadata,
                ]);
                $messageId = (int)$pdo->lastInsertId();
                $link = $pdo->prepare("UPDATE {$invites} SET message_id = ? WHERE id = ?");
                $link->execute([$messageId, $inviteId]);
                AppNotification::create(
                    $invitedUserId,
                    'battle_invite',
                    'Yangi Battle taklifi',
                    $user['name'] . ' sizni Vocabulary Battleʼga taklif qildi.',
                    [
                        'battle_id' => $battleId,
                        'invite_id' => $inviteId,
                        'sender_id' => (int)$user['id'],
                        'sender_name' => (string)$user['name'],
                    ]
                );
            }
            $pdo->commit();
            return ['battle_id' => $battleId, 'invite_id' => $inviteId];
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }
    }

    private static function inviteById(int $inviteId, int $viewerId): array
    {
        $invites = Database::table('battle_invites');
        $rooms = Database::table('battle_rooms');
        $lessons = Database::table('lessons');
        $stmt = Database::connection()->prepare(
            "SELECT i.*, r.direction, r.question_limit, r.duration_seconds, r.status AS battle_status,
                    r.room_code, r.lesson_id, r.rematch_of_id, l.title AS lesson_title
             FROM {$invites} i
             INNER JOIN {$rooms} r ON r.id = i.battle_id
             LEFT JOIN {$lessons} l ON l.id = r.lesson_id
             WHERE i.id = ? AND (i.sender_id = ? OR i.receiver_id = ?) LIMIT 1"
        );
        $stmt->execute([$inviteId, $viewerId, $viewerId]);
        $row = $stmt->fetch();
        if (!$row) {
            throw new RuntimeException('Battle invite not found.');
        }
        if ($row['status'] === 'pending' && strtotime((string)$row['expires_at']) <= time()) {
            self::expireInviteRows($row);
            $row['status'] = 'expired';
            $row['battle_status'] = 'cancelled';
        }
        return [
            'id' => (int)$row['id'],
            'battle_id' => (int)$row['battle_id'],
            'message_id' => empty($row['message_id']) ? null : (int)$row['message_id'],
            'sender_id' => (int)$row['sender_id'],
            'receiver_id' => (int)$row['receiver_id'],
            'sender' => self::publicUser((int)$row['sender_id']),
            'receiver' => self::publicUser((int)$row['receiver_id']),
            'status' => $row['status'],
            'battle_status' => $row['battle_status'],
            'room_code' => $row['room_code'],
            'lesson_id' => empty($row['lesson_id']) ? null : (int)$row['lesson_id'],
            'lesson_title' => $row['lesson_title'] ?: null,
            'direction' => $row['direction'],
            'question_limit' => (int)$row['question_limit'],
            'duration_seconds' => (int)$row['duration_seconds'],
            'rematch_of_id' => empty($row['rematch_of_id']) ? null : (int)$row['rematch_of_id'],
            'expires_at' => $row['expires_at'],
            'created_at' => $row['created_at'],
            'can_accept' => $row['status'] === 'pending' && (int)$row['receiver_id'] === $viewerId,
            'can_decline' => $row['status'] === 'pending' && (int)$row['receiver_id'] === $viewerId,
            'can_cancel' => $row['status'] === 'pending' && (int)$row['sender_id'] === $viewerId,
        ];
    }

    private static function expireInviteRows(array $invite): void
    {
        $invites = Database::table('battle_invites');
        $rooms = Database::table('battle_rooms');
        $stmt = Database::connection()->prepare(
            "UPDATE {$invites} SET status = 'expired', responded_at = NOW(), updated_at = NOW()
             WHERE id = ? AND status = 'pending'"
        );
        $stmt->execute([(int)$invite['id']]);
        $stmt = Database::connection()->prepare(
            "UPDATE {$rooms}
             SET status = 'cancelled', finished_at = NOW(), finished_reason = 'expired',
                 version = version + 1, updated_at = NOW()
             WHERE id = ? AND status = 'waiting'"
        );
        $stmt->execute([(int)$invite['battle_id']]);
    }

    private static function wordsPool(array $user, ?int $lessonId): array
    {
        $words = Database::table('words');
        $lessons = Database::table('lessons');
        $users = Database::table('users');
        if ($lessonId !== null && $lessonId > 0) {
            if (!Lesson::findVisible($lessonId, $user)) {
                throw new RuntimeException('Dars topilmadi.');
            }
            $stmt = Database::connection()->prepare(
                "SELECT * FROM {$words} WHERE lesson_id = ? ORDER BY created_at DESC"
            );
            $stmt->execute([$lessonId]);
            return $stmt->fetchAll();
        }
        if ($user['role'] === 'admin') {
            return Database::connection()->query(
                "SELECT w.* FROM {$words} w INNER JOIN {$lessons} l ON l.id = w.lesson_id ORDER BY w.created_at DESC"
            )->fetchAll();
        }
        $stmt = Database::connection()->prepare(
            "SELECT w.* FROM {$words} w
             INNER JOIN {$lessons} l ON l.id = w.lesson_id
             INNER JOIN {$users} u ON u.id = l.user_id
             WHERE l.user_id = ? OR u.role IN ('teacher', 'admin') OR l.is_public = 1
             ORDER BY w.created_at DESC"
        );
        $stmt->execute([(int)$user['id']]);
        return $stmt->fetchAll();
    }

    private static function questionPayload(array $word, array $words, string $direction): array
    {
        if ($direction === 'mixed') {
            $direction = random_int(0, 1) === 1 ? 'uz_to_eng' : 'eng_to_uz';
        }
        $answerField = $direction === 'uz_to_eng' ? 'english_word' : 'uzbek_translation';
        $promptField = $direction === 'uz_to_eng' ? 'uzbek_translation' : 'english_word';
        return [
            'prompt' => $word[$promptField],
            'correct_answer' => $word[$answerField],
            'options' => self::options($words, (int)$word['id'], $answerField, (string)$word[$answerField]),
        ];
    }

    private static function options(array $words, int $correctId, string $field, string $correct): array
    {
        $wrong = [];
        foreach ($words as $word) {
            $candidate = (string)$word[$field];
            if ((int)$word['id'] !== $correctId && !self::sameAnswer($candidate, $correct)) {
                $wrong[self::normalize($candidate)] = $candidate;
            }
        }
        $wrong = array_values($wrong);
        shuffle($wrong);
        $options = array_merge([$correct], array_slice($wrong, 0, 3));
        shuffle($options);
        return $options;
    }

    private static function roomForUser(int $battleId, array $user): ?array
    {
        $rooms = Database::table('battle_rooms');
        $stmt = Database::connection()->prepare(
            "SELECT * FROM {$rooms}
             WHERE id = ? AND (creator_id = ? OR opponent_id = ? OR invited_user_id = ?)
             LIMIT 1"
        );
        $userId = (int)$user['id'];
        $stmt->execute([$battleId, $userId, $userId, $userId]);
        $room = $stmt->fetch();
        return $room ?: null;
    }

    private static function countdownSeconds(array $room): int
    {
        if ($room['status'] !== 'active' || empty($room['starts_at'])) {
            return 0;
        }
        return max(0, strtotime((string)$room['starts_at']) - time());
    }

    private static function timeLeft(array $room): int
    {
        if ($room['status'] === 'waiting' || empty($room['starts_at'])) {
            return (int)$room['duration_seconds'];
        }
        $elapsed = time() - strtotime((string)$room['starts_at']);
        return max(0, (int)$room['duration_seconds'] - max(0, $elapsed));
    }

    private static function nextQuestionId(int $battleId, int $userId): ?int
    {
        $questions = Database::table('battle_questions');
        $answers = Database::table('battle_answers');
        $stmt = Database::connection()->prepare(
            "SELECT q.id FROM {$questions} q
             LEFT JOIN {$answers} a ON a.question_id = q.id AND a.user_id = ?
             WHERE q.battle_id = ? AND a.id IS NULL
             ORDER BY q.order_index ASC LIMIT 1"
        );
        $stmt->execute([$userId, $battleId]);
        $value = $stmt->fetchColumn();
        return $value === false ? null : (int)$value;
    }

    private static function serverAnswerMs(array $room, int $battleId, int $userId): int
    {
        $answers = Database::table('battle_answers');
        $stmt = Database::connection()->prepare(
            "SELECT created_at FROM {$answers}
             WHERE battle_id = ? AND user_id = ? ORDER BY id DESC LIMIT 1"
        );
        $stmt->execute([$battleId, $userId]);
        $last = $stmt->fetchColumn();
        $base = $last === false ? (string)$room['starts_at'] : (string)$last;
        $elapsed = (int)round((microtime(true) - strtotime($base)) * 1000);
        return max(250, min($elapsed, (int)$room['duration_seconds'] * 1000));
    }

    private static function finishIfComplete(int $battleId): void
    {
        $room = self::roomById($battleId);
        if (!$room || empty($room['opponent_id']) || $room['status'] !== 'active') {
            return;
        }
        $answers = Database::table('battle_answers');
        $stmt = Database::connection()->prepare("SELECT COUNT(*) FROM {$answers} WHERE battle_id = ?");
        $stmt->execute([$battleId]);
        if ((int)$stmt->fetchColumn() >= (int)$room['question_limit'] * 2) {
            self::markFinished($battleId, 'completed');
        }
    }

    private static function markFinished(int $battleId, string $reason): void
    {
        $rooms = Database::table('battle_rooms');
        $stmt = Database::connection()->prepare(
            "UPDATE {$rooms}
             SET status = 'finished', finished_at = COALESCE(finished_at, NOW()), finished_reason = ?,
                 version = version + 1, updated_at = NOW()
             WHERE id = ? AND status = 'active'"
        );
        $stmt->execute([$reason, $battleId]);
        if ($stmt->rowCount() === 1) {
            $room = self::roomById($battleId);
            if ($room) {
                self::announceResult($room);
            }
        }
    }

    private static function announceResult(array $room): void
    {
        if (empty($room['opponent_id'])) {
            return;
        }
        $scores = self::scoreboard($room);
        $winner = count($scores) > 0 ? $scores[0] : null;
        $draw = count($scores) > 1
            && $scores[0]['correct_count'] === $scores[1]['correct_count']
            && $scores[0]['average_ms'] === $scores[1]['average_ms'];
        $body = $draw || $winner === null
            ? 'Battle durang bilan yakunlandi.'
            : 'Battle gʼolibi: ' . $winner['user']['name'];
        $winnerName = $draw || $winner === null ? null : (string)$winner['user']['name'];
        $messages = Database::table('messages');
        $metadata = json_encode(
            [
                'battle_id' => (int)$room['id'],
                'result' => $scores,
                'draw' => $draw,
                'winner_name' => $winnerName,
            ],
            JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
        );
        $stmt = Database::connection()->prepare(
            "INSERT INTO {$messages}
             (sender_id, receiver_id, body, message_type, metadata_json)
             VALUES (?, ?, ?, 'battle_result', ?)"
        );
        $stmt->execute([(int)$room['creator_id'], (int)$room['opponent_id'], $body, $metadata]);
        foreach ([(int)$room['creator_id'], (int)$room['opponent_id']] as $userId) {
            AppNotification::create(
                $userId,
                'battle_result',
                'Battle yakunlandi',
                $body,
                [
                    'battle_id' => (int)$room['id'],
                    'draw' => $draw,
                    'winner_name' => $winnerName,
                ]
            );
        }
    }

    private static function roomById(int $battleId): ?array
    {
        $rooms = Database::table('battle_rooms');
        $stmt = Database::connection()->prepare("SELECT * FROM {$rooms} WHERE id = ? LIMIT 1");
        $stmt->execute([$battleId]);
        $room = $stmt->fetch();
        return $room ?: null;
    }

    private static function lockInvitePair(int $senderId, int $receiverId): void
    {
        $users = Database::table('users');
        $first = min($senderId, $receiverId);
        $second = max($senderId, $receiverId);
        $stmt = Database::connection()->prepare(
            "SELECT id FROM {$users} WHERE id IN (?, ?) ORDER BY id ASC FOR UPDATE"
        );
        $stmt->execute([$first, $second]);
        if (count($stmt->fetchAll()) !== 2) {
            throw new RuntimeException('Battle opponent is unavailable.');
        }
    }

    private static function assertNoPendingInvite(int $senderId, int $receiverId): void
    {
        $invites = Database::table('battle_invites');
        $stmt = Database::connection()->prepare(
            "SELECT id FROM {$invites}
             WHERE ((sender_id = ? AND receiver_id = ?)
                 OR (sender_id = ? AND receiver_id = ?))
               AND status = 'pending' AND expires_at > NOW()
             LIMIT 1 FOR UPDATE"
        );
        $stmt->execute([$senderId, $receiverId, $receiverId, $senderId]);
        if ($stmt->fetch()) {
            throw new RuntimeException('Bu foydalanuvchi bilan battle taklifi hali kutilmoqda.');
        }
    }

    private static function answersForUser(int $battleId, int $userId): array
    {
        $answers = Database::table('battle_answers');
        $stmt = Database::connection()->prepare(
            "SELECT question_id, given_answer, is_correct, answered_ms
             FROM {$answers} WHERE battle_id = ? AND user_id = ? ORDER BY id ASC"
        );
        $stmt->execute([$battleId, $userId]);
        return array_map(static function (array $row): array {
            return [
                'question_id' => (int)$row['question_id'],
                'given_answer' => $row['given_answer'],
                'is_correct' => (int)$row['is_correct'] === 1,
                'answered_ms' => (int)$row['answered_ms'],
            ];
        }, $stmt->fetchAll());
    }

    private static function scoreboard(array $room): array
    {
        $participants = array_values(array_filter([
            (int)$room['creator_id'],
            empty($room['opponent_id']) ? null : (int)$room['opponent_id'],
        ]));
        $scores = [];
        foreach ($participants as $userId) {
            $scores[$userId] = [
                'user' => self::publicUser($userId),
                'correct_count' => 0,
                'answered_count' => 0,
                'average_ms' => 0,
            ];
        }
        if (count($participants) === 0) {
            return [];
        }
        $answers = Database::table('battle_answers');
        $stmt = Database::connection()->prepare(
            "SELECT user_id, SUM(is_correct) AS correct_count, COUNT(*) AS answered_count,
                    ROUND(AVG(NULLIF(answered_ms, 0))) AS average_ms
             FROM {$answers} WHERE battle_id = ? GROUP BY user_id"
        );
        $stmt->execute([(int)$room['id']]);
        foreach ($stmt->fetchAll() as $row) {
            $userId = (int)$row['user_id'];
            if (!isset($scores[$userId])) {
                continue;
            }
            $scores[$userId]['correct_count'] = (int)$row['correct_count'];
            $scores[$userId]['answered_count'] = (int)$row['answered_count'];
            $scores[$userId]['average_ms'] = (int)$row['average_ms'];
        }
        usort($scores, static function (array $a, array $b): int {
            if ($a['correct_count'] !== $b['correct_count']) {
                return $b['correct_count'] <=> $a['correct_count'];
            }
            return $a['average_ms'] <=> $b['average_ms'];
        });
        return array_values($scores);
    }

    private static function publicUser(int $userId): ?array
    {
        $user = User::findById($userId);
        return $user ? User::publicProfile($user) : null;
    }

    private static function generateRoomCode(): string
    {
        $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        $rooms = Database::table('battle_rooms');
        do {
            $code = '';
            for ($i = 0; $i < 6; $i++) {
                $code .= $alphabet[random_int(0, strlen($alphabet) - 1)];
            }
            $stmt = Database::connection()->prepare("SELECT id FROM {$rooms} WHERE room_code = ? LIMIT 1");
            $stmt->execute([$code]);
        } while ($stmt->fetch());
        return $code;
    }

    private static function sanitizeDirection(string $direction): string
    {
        if ($direction === 'mixed') {
            return 'mixed';
        }
        return $direction === 'uz_to_eng' ? 'uz_to_eng' : 'eng_to_uz';
    }

    private static function sameAnswer(string $left, string $right): bool
    {
        return self::normalize($left) === self::normalize($right);
    }

    private static function normalize(string $value): string
    {
        $value = trim((string)preg_replace('/\s+/u', ' ', $value));
        return function_exists('mb_strtolower') ? mb_strtolower($value, 'UTF-8') : strtolower($value);
    }
}
