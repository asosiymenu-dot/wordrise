<?php

require_once __DIR__ . '/../../config/database.php';

$pdo = Database::connection();
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

function table_name(string $name): string
{
    return '`' . str_replace('`', '``', Database::table($name)) . '`';
}

function column_exists(PDO $pdo, string $table, string $column): bool
{
    $stmt = $pdo->prepare('SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?');
    $stmt->execute([Database::table($table), $column]);
    return (int)$stmt->fetchColumn() > 0;
}

function index_exists(PDO $pdo, string $table, string $index): bool
{
    $stmt = $pdo->prepare('SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?');
    $stmt->execute([Database::table($table), $index]);
    return (int)$stmt->fetchColumn() > 0;
}

function add_column(PDO $pdo, string $table, string $column, string $sql): void
{
    if (!column_exists($pdo, $table, $column)) {
        $pdo->exec('ALTER TABLE ' . table_name($table) . ' ADD COLUMN ' . $sql);
    }
}

$pdo->exec('CREATE TABLE IF NOT EXISTS ' . table_name('grammar_levels') . " (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(4) NOT NULL UNIQUE,
  title_uz VARCHAR(120) NOT NULL,
  order_index INT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_grammar_levels_order (order_index)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

$pdo->exec('CREATE TABLE IF NOT EXISTS ' . table_name('grammar_topics') . " (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  level_id INT UNSIGNED NOT NULL,
  title VARCHAR(160) NOT NULL,
  order_index INT UNSIGNED NOT NULL DEFAULT 0,
  icon VARCHAR(32) NULL,
  duration_minutes INT UNSIGNED NOT NULL DEFAULT 8,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (level_id) REFERENCES " . table_name('grammar_levels') . "(id) ON DELETE CASCADE,
  UNIQUE KEY unique_level_topic (level_id, title),
  INDEX idx_grammar_topics_level (level_id, order_index)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

add_column($pdo, 'grammar_lessons', 'topic_id', 'topic_id INT UNSIGNED NULL AFTER id');
add_column($pdo, 'grammar_lessons', 'examples_json', 'examples_json JSON NULL AFTER content');
add_column($pdo, 'grammar_lessons', 'common_mistakes', 'common_mistakes MEDIUMTEXT NULL AFTER examples_json');
add_column($pdo, 'grammar_lessons', 'status', "status ENUM('draft', 'published') NOT NULL DEFAULT 'published' AFTER common_mistakes");
if (!index_exists($pdo, 'grammar_lessons', 'unique_grammar_lesson_topic')) {
    $pdo->exec('ALTER TABLE ' . table_name('grammar_lessons') . ' ADD UNIQUE INDEX unique_grammar_lesson_topic (topic_id)');
}

add_column($pdo, 'grammar_exercises', 'exercise_type', "exercise_type VARCHAR(40) NOT NULL DEFAULT 'multiple_choice' AFTER lesson_id");
add_column($pdo, 'grammar_exercises', 'correct_answers', 'correct_answers JSON NULL AFTER correct_answer');

$pdo->exec('CREATE TABLE IF NOT EXISTS ' . table_name('user_grammar_progress') . " (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  topic_id INT UNSIGNED NOT NULL,
  progress_percent TINYINT UNSIGNED NOT NULL DEFAULT 0,
  correct_count INT UNSIGNED NOT NULL DEFAULT 0,
  wrong_count INT UNSIGNED NOT NULL DEFAULT 0,
  wrong_exercise_ids JSON NULL,
  completed_at DATETIME NULL,
  last_attempt_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES " . table_name('users') . "(id) ON DELETE CASCADE,
  FOREIGN KEY (topic_id) REFERENCES " . table_name('grammar_topics') . "(id) ON DELETE CASCADE,
  UNIQUE KEY unique_user_grammar_topic (user_id, topic_id),
  INDEX idx_user_grammar_user (user_id, progress_percent)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

$levels = [
    ['A1', 'Boshlang‘ich', 10],
    ['A2', 'Elementar', 20],
    ['B1', 'O‘rta', 30],
    ['B2', 'Yuqori o‘rta', 40],
    ['C1', 'Ilg‘or', 50],
    ['C2', 'Mukammal', 60],
];
$levelIds = [];
$levelStmt = $pdo->prepare('INSERT IGNORE INTO ' . table_name('grammar_levels') . ' (code, title_uz, order_index) VALUES (?, ?, ?)');
foreach ($levels as $level) {
    $levelStmt->execute($level);
    $select = $pdo->prepare('SELECT id FROM ' . table_name('grammar_levels') . ' WHERE code = ? LIMIT 1');
    $select->execute([$level[0]]);
    $levelIds[$level[0]] = (int)$select->fetchColumn();
}

$topics = [
    ['A1', 'Present Simple', 'repeat', 10, 'Present Simple odat, har kuni takrorlanadigan ish va umumiy haqiqatlar uchun ishlatiladi. I/you/we/they bilan feʼl oddiy keladi: I study. He/she/it bilan -s yoki -es qo‘shiladi: She studies.', [['I study English every day.', 'Men har kuni ingliz tilini o‘rganaman.'], ['She likes tea.', 'U choyni yaxshi ko‘radi.'], ['They play football on Sundays.', 'Ular yakshanba kunlari futbol o‘ynaydi.']], 'He/she/it bilan -s qo‘shishni unutish eng ko‘p uchraydi: She like emas, She likes.', [
        ['multiple_choice', 'She ____ English every day.', ['study', 'studies', 'studied', 'studying'], 'studies', 'He/she/it bilan Present Simpleda -s/-es ishlatiladi.'],
        ['fill_blank', 'I ____ tea in the morning.', [], 'drink', 'I bilan feʼl oddiy shaklda keladi.'],
        ['translate', 'U maktabga boradi.', [], 'She goes to school.', 'Go feʼli he/she/it bilan goes bo‘ladi.'],
        ['error_correction', 'He play football.', [], 'He plays football.', 'He bilan plays kerak.'],
    ]],
    ['A1', 'Present Continuous', 'timelapse', 20, 'Present Continuous hozir ayni paytda bo‘layotgan ish-harakat uchun ishlatiladi. Tuzilishi: am/is/are + V-ing.', [['I am reading now.', 'Men hozir o‘qiyapman.'], ['They are working.', 'Ular ishlayapti.'], ['She is cooking dinner.', 'U kechki ovqat pishiryapti.']], 'Am/is/are yordamchi feʼlini tushirib qoldirmang: I reading emas, I am reading.', [
        ['multiple_choice', 'They ____ watching TV now.', ['is', 'am', 'are', 'be'], 'are', 'They bilan are ishlatiladi.'],
        ['fill_blank', 'She is ____ a book.', [], 'reading', 'Continuousda feʼlga -ing qo‘shiladi.'],
        ['translate', 'Men hozir ishlayapman.', [], 'I am working now.', 'Hozirgi davomiy zamon am + working.'],
        ['error_correction', 'We is learning.', [], 'We are learning.', 'We bilan are kerak.'],
    ]],
    ['A1', 'Articles: a/an/the', 'article', 30, 'A/an birinchi marta aytilayotgan bitta narsa uchun, the esa aniq yoki avval tilga olingan narsa uchun ishlatiladi. An unli tovushdan oldin keladi.', [['I have a book.', 'Menda kitob bor.'], ['She eats an apple.', 'U olma yeydi.'], ['The book is on the table.', 'Kitob stol ustida.']], 'O‘zbek tilida artikl yo‘qligi sababli ko‘pincha a/an/the tushirib qoldiriladi.', [
        ['multiple_choice', 'I saw ____ elephant.', ['a', 'an', 'the', '-'], 'an', 'Elephant unli tovush bilan boshlanadi.'],
        ['fill_blank', 'This is ____ new phone.', [], 'a', 'New phone birinchi marta aytilmoqda.'],
        ['multiple_choice', 'Open ____ door, please.', ['a', 'an', 'the', '-'], 'the', 'Gapdagi eshik aniq.'],
        ['error_correction', 'She is an teacher.', [], 'She is a teacher.', 'Teacher undosh tovush bilan boshlanadi.'],
    ]],
    ['A2', 'Past Simple', 'history', 10, 'Past Simple o‘tmishda tugagan ish-harakat uchun ishlatiladi. Regular feʼllarga -ed qo‘shiladi, irregular feʼllar alohida yodlanadi.', [['I visited Sam yesterday.', 'Men kecha Samnikiga bordim.'], ['She went home.', 'U uyga ketdi.'], ['We watched a movie.', 'Biz kino ko‘rdik.']], 'Did bilan savol/inkorda asosiy feʼl oddiy shaklga qaytadi: Did you went emas, Did you go.', [
        ['multiple_choice', 'Yesterday I ____ to school.', ['go', 'went', 'gone', 'going'], 'went', 'Go feʼlining past shakli went.'],
        ['fill_blank', 'They ____ football last week.', [], 'played', 'Regular feʼlga -ed qo‘shiladi.'],
        ['translate', 'U kecha kelmadi.', [], 'He did not come yesterday.', 'Did not dan keyin come oddiy shaklda.'],
        ['error_correction', 'Did you watched it?', [], 'Did you watch it?', 'Did bilan watch bo‘ladi.'],
    ]],
    ['A2', 'Future: will / going to', 'rocket', 20, 'Will ko‘pincha tez qaror yoki taxmin uchun, going to esa reja yoki dalilga asoslangan kelajak uchun ishlatiladi.', [['I will help you.', 'Men sizga yordam beraman.'], ['She is going to travel.', 'U sayohat qilmoqchi.'], ['Look! It is going to rain.', 'Qara! Yomg‘ir yog‘moqchi.']], 'Reja haqida gapirganda faqat will ishlatish har doim tabiiy emas; going to ko‘proq mos bo‘ladi.', [
        ['multiple_choice', 'Look at the clouds. It ____ rain.', ['will', 'is going to', 'was', 'did'], 'is going to', 'Dalil bor: bulutlar.'],
        ['fill_blank', 'I think he ____ win.', [], 'will', 'I think bilan taxmin uchun will mos.'],
        ['translate', 'Biz ertaga uchrashmoqchimiz.', [], 'We are going to meet tomorrow.', 'Reja uchun going to.'],
        ['error_correction', 'She going to call me.', [], 'She is going to call me.', 'Going to oldidan be kerak.'],
    ]],
    ['A2', 'Comparatives and Superlatives', 'trending_up', 30, 'Comparative ikki narsani solishtiradi: bigger, more interesting. Superlative eng yuqori darajani bildiradi: the biggest, the most interesting.', [['This bag is cheaper.', 'Bu sumka arzonroq.'], ['English is more useful for me.', 'Ingliz tili men uchun foydaliroq.'], ['He is the tallest student.', 'U eng baland o‘quvchi.']], 'Long adjective bilan -er qo‘shmang: more beautiful, beautifuler emas.', [
        ['multiple_choice', 'This test is ____ than yesterday’s test.', ['easy', 'easier', 'easiest', 'more easy'], 'easier', 'Easy -> easier.'],
        ['fill_blank', 'She is the ____ student in class.', [], 'best', 'Good superlative shakli best.'],
        ['translate', 'Bu kitob qiziqroq.', [], 'This book is more interesting.', 'Interesting uzun sifat, more bilan keladi.'],
        ['error_correction', 'This is more cheap.', [], 'This is cheaper.', 'Cheap qisqa sifat, cheaper.'],
    ]],
    ['B1', 'Present Perfect', 'verified', 10, 'Present Perfect o‘tmishda boshlangan yoki natijasi hozirga bog‘liq holatlar uchun ishlatiladi. Tuzilishi: have/has + V3.', [['I have finished my homework.', 'Men uy vazifamni tugatdim.'], ['She has visited London.', 'U Londonga borgan.'], ['We have lived here for two years.', 'Biz bu yerda ikki yildan beri yashaymiz.']], 'Aniq o‘tgan vaqt bilan Present Perfect ishlatmang: I have seen him yesterday emas, I saw him yesterday.', [
        ['multiple_choice', 'I ____ already finished the task.', ['has', 'have', 'did', 'am'], 'have', 'I bilan have ishlatiladi.'],
        ['fill_blank', 'She has ____ her keys.', [], 'lost', 'Lose feʼlining V3 shakli lost.'],
        ['translate', 'Men hech qachon Parijda bo‘lmaganman.', [], 'I have never been to Paris.', 'Never + have been tajriba uchun.'],
        ['error_correction', 'I have seen him yesterday.', [], 'I saw him yesterday.', 'Yesterday aniq past time.'],
    ]],
    ['B1', 'Modal Verbs', 'rule', 20, 'Can, must, should, may kabi modal feʼllardan keyin asosiy feʼl doim oddiy shaklda keladi. Ular qobiliyat, majburiyat, maslahat va ehtimolni bildiradi.', [['You should rest.', 'Siz dam olishingiz kerak.'], ['She can swim.', 'U suza oladi.'], ['We must leave now.', 'Biz hozir ketishimiz shart.']], 'Modal feʼldan keyin to qo‘shmang: should to go emas, should go.', [
        ['multiple_choice', 'You ____ see a doctor.', ['should', 'to should', 'should to', 'must to'], 'should', 'Modal + V1.'],
        ['fill_blank', 'He can ____ fast.', [], 'run', 'Can dan keyin run oddiy shaklda.'],
        ['translate', 'Biz hozir ketishimiz shart.', [], 'We must leave now.', 'Majburiyat uchun must.'],
        ['error_correction', 'She can to swim.', [], 'She can swim.', 'Can dan keyin to ishlatilmaydi.'],
    ]],
    ['B1', 'Conditionals 0 and 1', 'fork_right', 30, 'Zero conditional umumiy haqiqatlar uchun: if + present, present. First conditional real kelajak natijasi uchun: if + present, will + V1.', [['If you heat water, it boils.', 'Suvni qizdirsangiz, u qaynaydi.'], ['If it rains, I will stay home.', 'Yomg‘ir yog‘sa, uyda qolaman.'], ['If you study, you will improve.', 'O‘qisangiz, rivojlanasiz.']], 'If qismida will ishlatmang: If it will rain emas, If it rains.', [
        ['multiple_choice', 'If it rains, we ____ stay home.', ['will', 'would', 'are', 'did'], 'will', 'First conditional natija qismida will.'],
        ['fill_blank', 'If you heat ice, it ____.', [], 'melts', 'Zero conditional umumiy haqiqat.'],
        ['translate', 'Agar u kelsa, men xursand bo‘laman.', [], 'If he comes, I will be happy.', 'If qismida comes.'],
        ['error_correction', 'If it will rain, I will stay.', [], 'If it rains, I will stay.', 'If qismida will kerak emas.'],
    ]],
    ['B2', 'Passive Voice', 'sync_alt', 10, 'Passive voice ishni kim qilganidan ko‘ra natija yoki obyekt muhim bo‘lganda ishlatiladi. Tuzilishi: be + V3.', [['The book was written in 1990.', 'Kitob 1990-yilda yozilgan.'], ['English is spoken worldwide.', 'Ingliz tili butun dunyoda gapiriladi.'], ['The room has been cleaned.', 'Xona tozalangan.']], 'Passive voice’da be feʼlini yoki V3 shaklni unutish keng tarqalgan xato.', [
        ['multiple_choice', 'The car ____ repaired yesterday.', ['is', 'was', 'were', 'has'], 'was', 'Yesterday past, car singular: was repaired.'],
        ['fill_blank', 'English is ____ in many countries.', [], 'spoken', 'Speak feʼlining V3 shakli spoken.'],
        ['translate', 'Xat yuborildi.', [], 'The letter was sent.', 'Passive: was + sent.'],
        ['error_correction', 'The room cleaned yesterday.', [], 'The room was cleaned yesterday.', 'Passive uchun was kerak.'],
    ]],
    ['B2', 'Relative Clauses', 'link', 20, 'Relative clause noun haqida qo‘shimcha maʼlumot beradi: who odamlar uchun, which narsalar uchun, where joy uchun, that umumiy holatda ishlatiladi.', [['The man who called you is my teacher.', 'Sizga qo‘ng‘iroq qilgan kishi mening o‘qituvchim.'], ['This is the book that I bought.', 'Bu men sotib olgan kitob.'], ['I know a cafe where we can study.', 'Men o‘qiy oladigan kafe bilaman.']], 'Who va whichni almashtirib yuborish yoki relative pronounni noto‘g‘ri joyga qo‘yish xato bo‘ladi.', [
        ['multiple_choice', 'The woman ____ teaches us is kind.', ['which', 'who', 'where', 'when'], 'who', 'Odam uchun who.'],
        ['fill_blank', 'This is the place ____ I was born.', [], 'where', 'Joy uchun where.'],
        ['translate', 'Men sotib olgan telefon yangi.', [], 'The phone that I bought is new.', 'Narsa uchun that/which.'],
        ['error_correction', 'The book who I read was useful.', [], 'The book that I read was useful.', 'Book odam emas.'],
    ]],
    ['B2', 'Second Conditional', 'psychology', 30, 'Second conditional hozirgi yoki kelajakdagi real bo‘lmagan tasavvur uchun ishlatiladi: if + past, would + V1.', [['If I had more time, I would travel.', 'Vaqtim ko‘proq bo‘lsa, sayohat qilardim.'], ['If she knew, she would tell us.', 'U bilsa, bizga aytardi.'], ['If I were you, I would wait.', 'Men sizning o‘rningizda bo‘lsam, kutardim.']], 'If qismida would ishlatmang: If I would have emas, If I had.', [
        ['multiple_choice', 'If I ____ rich, I would help more people.', ['am', 'was', 'were', 'will be'], 'were', 'Hypothetical holatda were ko‘p ishlatiladi.'],
        ['fill_blank', 'If he studied, he ____ pass.', [], 'would', 'Natija qismida would.'],
        ['translate', 'Men sizning o‘rningizda bo‘lsam, kutardim.', [], 'If I were you, I would wait.', 'Fixed expression: If I were you.'],
        ['error_correction', 'If I would know, I would tell you.', [], 'If I knew, I would tell you.', 'If qismida past simple.'],
    ]],
    ['C1', 'Conditionals 3 and Mixed', 'account_tree', 10, 'Third conditional o‘tmishda bo‘lmagan holatni tasavvur qiladi: if + had V3, would have V3. Mixed conditional o‘tmish sababining hozirgi natijasini ko‘rsatadi.', [['If I had studied, I would have passed.', 'O‘qiganimda, o‘tgan bo‘lardim.'], ['If she had left earlier, she would be here now.', 'U ertaroq chiqqanida, hozir shu yerda bo‘lardi.'], ['If I were more careful, I would not have made that mistake.', 'Ehtiyotkorroq bo‘lganimda, o‘sha xatoni qilmagan bo‘lardim.']], 'Would have o‘rniga would of yozish yoki if qismida would ishlatish xato.', [
        ['multiple_choice', 'If he had called, I ____ answered.', ['would have', 'will have', 'would', 'had'], 'would have', 'Third conditional natija: would have + V3.'],
        ['fill_blank', 'If I had known, I would have ____.', [], 'helped', 'Have dan keyin V3.'],
        ['translate', 'U ertaroq kelganida, uchrashuvni o‘tkazib yubormasdi.', [], 'If he had come earlier, he would not have missed the meeting.', 'Third conditional.'],
        ['error_correction', 'If I would have known, I would have helped.', [], 'If I had known, I would have helped.', 'If qismida had V3.'],
    ]],
    ['C1', 'Advanced Articles', 'auto_stories', 20, 'Advanced article usage abstrakt maʼno, institution, unique objects va generic reference farqlarini tushunishni talab qiladi.', [['The rich should help the poor.', 'Boylar kambag‘allarga yordam berishi kerak.'], ['I go to school by bus.', 'Men maktabga avtobusda boraman.'], ['The school near my house is old.', 'Uyim yonidagi maktab eski.']], 'Institution maʼnosida artikl ishlatilmasligi, aniq bino haqida esa the ishlatilishi farqini ko‘pincha unutishadi.', [
        ['multiple_choice', 'She is in ____ hospital after the accident.', ['a', 'an', 'the', '-'], 'the', 'American Englishda aniq joy sifatida the hospital bo‘lishi mumkin; context aniq.'],
        ['fill_blank', '____ Internet has changed communication.', [], 'The', 'Internet unique system sifatida the bilan keladi.'],
        ['translate', 'Men odatda maktabga piyoda boraman.', [], 'I usually go to school on foot.', 'Institution maʼnosida school artiklsiz.'],
        ['error_correction', 'The life is difficult.', [], 'Life is difficult.', 'Umumiy abstrakt maʼnoda article kerak emas.'],
    ]],
    ['C1', 'Inversion for Emphasis', 'swap_vert', 30, 'Inversion rasmiy yoki urg‘uli uslubda negative adverbial boshida kelganda yordamchi feʼl subyektdan oldin keladi.', [['Never have I seen such a view.', 'Bunday manzarani hech qachon ko‘rmaganman.'], ['Rarely do we get this chance.', 'Bunday imkoniyat kamdan-kam bo‘ladi.'], ['Not only did she help, but she also stayed.', 'U nafaqat yordam berdi, balki qoldi ham.']], 'Inversionda yordamchi feʼlni unutish yoki asosiy feʼlni noto‘g‘ri shaklda ishlatish xato.', [
        ['multiple_choice', 'Never ____ I heard such news.', ['have', 'has', 'did', 'do'], 'have', 'Never + have + subject + V3.'],
        ['fill_blank', 'Rarely ____ he speak in public.', [], 'does', 'Present simple inversionda does.'],
        ['translate', 'Men bunday narsani hech qachon ko‘rmaganman.', [], 'Never have I seen such a thing.', 'Urg‘u uchun inversion.'],
        ['error_correction', 'Never I have seen it.', [], 'Never have I seen it.', 'Never boshida inversion kerak.'],
    ]],
    ['C2', 'Subjunctive and Formal Structures', 'gavel', 10, 'Subjunctive rasmiy taklif, talab va zaruratdan keyin asosiy feʼlning oddiy shaklini ishlatadi: insist that he be, recommend that she go.', [['I suggest that he be informed.', 'Men unga xabar berilishini taklif qilaman.'], ['It is essential that she arrive on time.', 'Uning vaqtida kelishi muhim.'], ['They demanded that the rule be changed.', 'Ular qoidani o‘zgartirishni talab qilishdi.']], 'He is o‘rniga he be ishlatilishini g‘alati tuyilishi mumkin, lekin formal subjunctiveda to‘g‘ri.', [
        ['multiple_choice', 'They insisted that he ____ present.', ['is', 'was', 'be', 'will be'], 'be', 'Subjunctive: that he be.'],
        ['fill_blank', 'It is vital that she ____ early.', [], 'arrive', 'Subjunctiveda V1.'],
        ['translate', 'Ular qaror qayta ko‘rib chiqilishini talab qilishdi.', [], 'They demanded that the decision be reviewed.', 'Passive subjunctive: be reviewed.'],
        ['error_correction', 'I recommend that he goes.', [], 'I recommend that he go.', 'Subjunctive V1.'],
    ]],
    ['C2', 'Discourse Markers', 'format_quote', 20, 'Discourse markers fikrlarni bog‘laydi va matn oqimini tabiiy qiladi: nevertheless, moreover, consequently, on the contrary.', [['The task was hard; nevertheless, we finished it.', 'Vazifa qiyin edi; shunga qaramay, tugatdik.'], ['Moreover, the plan is affordable.', 'Bundan tashqari, reja hamyonbop.'], ['Consequently, sales increased.', 'Natijada savdo oshdi.']], 'Moreover va however kabi bog‘lovchilarni punctuation bilan ajratmaslik matnni noaniq qiladi.', [
        ['multiple_choice', 'The evidence was weak; ____, the claim was accepted.', ['nevertheless', 'because', 'so that', 'unless'], 'nevertheless', 'Kontrast uchun nevertheless.'],
        ['fill_blank', 'The costs rose; ____, we delayed the project.', [], 'consequently', 'Natija bildiradi.'],
        ['translate', 'Bundan tashqari, natijalar ishonchli.', [], 'Moreover, the results are reliable.', 'Moreover qo‘shimcha fikr qo‘shadi.'],
        ['error_correction', 'However the data was clear.', [], 'However, the data was clear.', 'Howeverdan keyin vergul kerak.'],
    ]],
    ['C2', 'Nuanced Modality', 'tune', 30, 'Advanced modality certainty, criticism, deduction va past speculation farqlarini aniq ifodalaydi: must have, might have, should have, needn’t have.', [['He must have forgotten.', 'U unutgan bo‘lsa kerak.'], ['You should have told me.', 'Menga aytishingiz kerak edi.'], ['She might have misunderstood.', 'U noto‘g‘ri tushungan bo‘lishi mumkin.']], 'Must have va should have farqi: must have deduction, should have criticism/regret bildiradi.', [
        ['multiple_choice', 'He ____ missed the train; he looks upset.', ['must have', 'should have', 'need have', 'can have'], 'must have', 'Dalilga asoslangan taxmin.'],
        ['fill_blank', 'You ____ have called me earlier.', [], 'should', 'Tanqid yoki afsus uchun should have.'],
        ['translate', 'U noto‘g‘ri tushungan bo‘lishi mumkin.', [], 'She might have misunderstood.', 'Might have ehtimol.'],
        ['error_correction', 'He must forgot.', [], 'He must have forgotten.', 'Past deduction: must have V3.'],
    ]],
];

$topicStmt = $pdo->prepare('INSERT IGNORE INTO ' . table_name('grammar_topics') . ' (level_id, title, order_index, icon, duration_minutes) VALUES (?, ?, ?, ?, ?)');
$lessonStmt = $pdo->prepare('INSERT INTO ' . table_name('grammar_lessons') . ' (topic_id, title, level, content, examples_json, common_mistakes, status, sort_order) VALUES (?, ?, ?, ?, ?, ?, "published", ?) ON DUPLICATE KEY UPDATE title=VALUES(title), content=VALUES(content), examples_json=VALUES(examples_json), common_mistakes=VALUES(common_mistakes), status="published"');
$selectTopic = $pdo->prepare('SELECT id FROM ' . table_name('grammar_topics') . ' WHERE level_id = ? AND title = ? LIMIT 1');
$selectLesson = $pdo->prepare('SELECT id FROM ' . table_name('grammar_lessons') . ' WHERE topic_id = ? LIMIT 1');
$deleteExercises = $pdo->prepare('DELETE FROM ' . table_name('grammar_exercises') . ' WHERE lesson_id = ?');
$exerciseStmt = $pdo->prepare('INSERT INTO ' . table_name('grammar_exercises') . ' (lesson_id, exercise_type, question, options, correct_answer, correct_answers, explanation) VALUES (?, ?, ?, ?, ?, ?, ?)');

foreach ($topics as $topic) {
    [$level, $title, $icon, $order, $content, $examples, $mistakes, $exercises] = $topic;
    $levelId = $levelIds[$level];
    $topicStmt->execute([$levelId, $title, $order, $icon, 10]);
    $selectTopic->execute([$levelId, $title]);
    $topicId = (int)$selectTopic->fetchColumn();
    $lessonStmt->execute([$topicId, $title, $level, $content, json_encode($examples, JSON_UNESCAPED_UNICODE), $mistakes, $order]);
    $selectLesson->execute([$topicId]);
    $lessonId = (int)$selectLesson->fetchColumn();
    $deleteExercises->execute([$lessonId]);
    foreach ($exercises as $exercise) {
        [$type, $question, $options, $answer, $explanation] = $exercise;
        $exerciseStmt->execute([
            $lessonId,
            $type,
            $question,
            json_encode($options, JSON_UNESCAPED_UNICODE),
            $answer,
            json_encode([$answer], JSON_UNESCAPED_UNICODE),
            $explanation,
        ]);
    }
}

$badgeStmt = $pdo->prepare('INSERT IGNORE INTO ' . table_name('badges') . ' (id, title, description, icon, required_condition) VALUES (?, ?, ?, ?, ?)');
$badgeStmt->execute([7, 'Grammar Starter', 'Finish your first grammar practice.', 'school', 'grammar_completed>=1']);
$badgeStmt->execute([8, 'Grammar Master', 'Complete a grammar level.', 'workspace_premium', 'grammar_level_complete=true']);

echo json_encode(['success' => true, 'seeded_topics' => count($topics)], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . PHP_EOL;
