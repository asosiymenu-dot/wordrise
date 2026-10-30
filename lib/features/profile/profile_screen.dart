import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../../services/audio_haptic_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/ios_selection_sheet.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/api_models.dart';
import '../../services/app_notification_service.dart';
import '../../services/auth_service.dart';
import '../../services/offline_cache_service.dart';
import 'edit_profile_screen.dart';
import 'notification_preferences_screen.dart';
import 'sessions_screen.dart';
import '../focus/focus_setup_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.user,
    this.stats,
    required this.authService,
    required this.notificationService,
    this.offlineCacheService,
    required this.themeMode,
    required this.locale,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    required this.onProfileChanged,
    required this.onLogout,
    super.key,
  });

  final UserModel user;
  final ProfileStatsModel? stats;
  final AuthService authService;
  final AppNotificationService notificationService;
  final OfflineCacheService? offlineCacheService;
  final ThemeMode themeMode;
  final Locale locale;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<UserModel> onProfileChanged;
  final VoidCallback onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _soundEnabled = prefs.getBool('wordrise_sound_effects') ?? true;
      _hapticsEnabled = prefs.getBool('wordrise_haptics') ?? true;
    });
  }

  Future<void> _toggleSound(bool val) async {
    setState(() => _soundEnabled = val);
    AudioHapticService.instance.setSoundEnabled(val);
  }

  Future<void> _toggleHaptics(bool val) async {
    setState(() => _hapticsEnabled = val);
    if (val) AudioHapticService.instance.mediumImpact();
    AudioHapticService.instance.setHapticEnabled(val);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppColors.isDark(context);
    final bgColor = isDark ? AppColors.darkBgStart : AppColors.bgStart;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final user = widget.user;

    final progress = levelProgress(user.xp);
    final currentTitle = levelTitle(user.level);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(CupertinoIcons.back, color: textColor),
                    style: IconButton.styleFrom(
                      backgroundColor: cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      l10n.t('profile.title'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Balancing back button
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                children: [
                  // Creative Profile Hero Banner Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                            : [Colors.white, const Color(0xFFF8FAFC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black12,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            UserAvatar(
                              name: user.name,
                              avatarUrl: user.avatar,
                              size: 72,
                              online: true,
                              border: Border.all(
                                color: Colors.blueAccent.withValues(alpha: 0.8),
                                width: 2.5,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          user.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 18),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user.username.isNotEmpty ? '@${user.username}' : user.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isDark ? Colors.white60 : Colors.black54,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.military_tech_rounded, color: Colors.amber, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          'LVL ${user.level} • $currentTitle',
                                          style: const TextStyle(
                                            color: Colors.amber,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Level Progress Bar
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Daraja ${user.level} progressi',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${(progress * 100).toInt()}% • ${user.xp} XP',
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: progress.clamp(0.0, 1.0),
                                  minHeight: 6,
                                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                  valueColor: const AlwaysStoppedAnimation(Colors.blueAccent),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Single Clean Edit Profile Button
                        OutlinedButton.icon(
                          onPressed: () => _openEditProfile(context),
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: Text(l10n.t('profile.edit')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.white : Colors.black87,
                            side: BorderSide(
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                            minimumSize: const Size(double.infinity, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stats overview row
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: Colors.orange,
                          title: '${user.streak} kun',
                          subtitle: 'Streak',
                        ),
                        _StatItem(
                          icon: Icons.ac_unit_rounded,
                          iconColor: Colors.cyan,
                          title: '${user.streakFreezes} ta',
                          subtitle: 'Muzlatish',
                        ),
                        _StatItem(
                          icon: Icons.military_tech_rounded,
                          iconColor: Colors.amber,
                          title: '${user.xp} XP',
                          subtitle: 'Ballar',
                        ),
                        _StatItem(
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: Colors.green,
                          title: '${widget.stats?.masteredWords ?? user.totalLearned}',
                          subtitle: 'O‘rganilgan',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _SectionHeader(title: 'ILOVA SOZLAMALARI'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: [
                        _ProfileMenuRow(
                          icon: Icons.language_rounded,
                          iconBgColor: Colors.teal,
                          title: l10n.t('profile.language'),
                          trailingText: _localeLabel(context),
                          onTap: () => _pickLocale(context),
                        ),
                        _divider(isDark),
                        _ProfileMenuRow(
                          icon: Icons.dark_mode_rounded,
                          iconBgColor: Colors.purpleAccent,
                          title: l10n.t('profile.theme'),
                          trailingText: _themeLabel(context),
                          onTap: () => _pickTheme(context),
                        ),
                        _divider(isDark),
                        _ProfileMenuRow(
                          icon: Icons.notifications_active_rounded,
                          iconBgColor: Colors.orangeAccent,
                          title: l10n.t('notifications.settingsTitle'),
                          subtitle: 'Kunlik eslatmalar va vaqtlar',
                          onTap: () => Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => NotificationPreferencesScreen(service: widget.notificationService),
                            ),
                          ),
                        ),
                        _divider(isDark),
                        _ProfileSwitchRow(
                          icon: Icons.volume_up_rounded,
                          iconBgColor: Colors.blue,
                          title: 'Ovoz effektlari',
                          subtitle: 'Test va mashg‘ulot tovushlari',
                          value: _soundEnabled,
                          onChanged: _toggleSound,
                        ),
                        _divider(isDark),
                        _ProfileSwitchRow(
                          icon: Icons.vibration_rounded,
                          iconBgColor: Colors.deepOrange,
                          title: 'Vibratsiya & Haptika',
                          subtitle: 'Tugma bosish va javob tebranishlari',
                          value: _hapticsEnabled,
                          onChanged: _toggleHaptics,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _SectionHeader(title: 'ULASHISH VA QO‘LLAB-QUVVATLASH'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: [
                        _ProfileMenuRow(
                          icon: Icons.rocket_launch_rounded,
                          iconBgColor: Colors.purpleAccent,
                          title: 'WordRise ni ulashish',
                          subtitle: 'Do‘stlarga taklifnoma yuborish',
                          onTap: () => _showShareBottomSheet(context),
                        ),
                        _divider(isDark),
                        _ProfileMenuRow(
                          icon: Icons.telegram_rounded,
                          iconBgColor: const Color(0xFF229ED9),
                          title: 'Telegram Qo‘llab-quvvatlash',
                          subtitle: '@uzsly bilan bog‘lanish',
                          onTap: () => _launchUrl('https://t.me/uzsly'),
                        ),
                        _divider(isDark),
                        _ProfileMenuRow(
                          icon: Icons.cleaning_services_rounded,
                          iconBgColor: Colors.amber.shade700,
                          title: 'Keshni tozalash',
                          subtitle: 'Oflayn saqlangan ma‘lumotlar',
                          onTap: () => _clearCache(context),
                        ),
                        _divider(isDark),
                        _ProfileMenuRow(
                          icon: Icons.info_outline_rounded,
                          iconBgColor: Colors.blueGrey,
                          title: 'WordRise haqida',
                          trailingText: 'v1.2.0',
                          onTap: () => _showAboutDialog(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _SectionHeader(title: 'DIQQAT REJIMI (FOCUS MODE)'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: [
                        _ProfileMenuRow(
                          icon: Icons.lock_clock_rounded,
                          iconBgColor: Colors.deepPurpleAccent,
                          title: 'Diqqat rejimini yoqish',
                          subtitle: 'Maqsadga yetguncha telefon qulflanadi',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FocusSetupScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _SectionHeader(title: 'XAVFSIZLIK VA HISOB'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: [
                        _ProfileMenuRow(
                          icon: Icons.lock_outline_rounded,
                          iconBgColor: Colors.indigoAccent,
                          title: 'Parolni o‘zgartirish',
                          subtitle: 'Yangi xavfsiz parol o‘rnatish',
                          onTap: () => _showChangePasswordDialog(context),
                        ),
                        _divider(isDark),
                        _ProfileMenuRow(
                          icon: Icons.devices_rounded,
                          iconBgColor: Colors.teal,
                          title: 'Faol qurilmalar',
                          subtitle: 'Barcha faol sessiyalarni boshqarish',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SessionsScreen(authService: widget.authService)),
                            );
                          },
                        ),
                        _divider(isDark),
                        _ProfileMenuRow(
                          icon: Icons.delete_outline_rounded,
                          iconBgColor: Colors.redAccent.shade700,
                          title: 'Hisobni o‘chirish',
                          subtitle: 'Barcha ma‘lumotlarni butunlay o‘chirish',
                          textColor: Colors.redAccent,
                          onTap: () => _showDeleteAccountDialog(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: l10n.t('profile.logout'),
                    icon: Icons.logout_rounded,
                    color: Colors.redAccent.shade700,
                    onPressed: () => _confirmLogout(context, l10n),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(height: 1, color: isDark ? const Color(0xFF334155) : Colors.black12);
  }

  Future<void> _showShareBottomSheet(BuildContext context) async {
    final user = widget.user;
    final shareText = 'Ingliz tilini qiziqarli testlar, 1v1 janglar va darslar orqali birga o‘rganaylik!\n'
        'Mening natijam: ${user.streak} kunlik streak, ${user.xp} XP!\n'
        'Ilovani yuklab olish: https://t.me/wordriseapp';

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rocket_launch_rounded, color: Colors.blueAccent, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'WordRise ni Ulashish',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Do‘stlaringizni taklif qiling va 1v1 janglarda kuch sinashing!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Preview Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      name: user.name,
                      avatarUrl: user.avatar,
                      size: 52,
                      online: true,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 14),
                              const SizedBox(width: 3),
                              Text(
                                '${user.streak} kun streak',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.military_tech_rounded, color: Colors.amberAccent, size: 14),
                              const SizedBox(width: 3),
                              Text(
                                '${user.xp} XP',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'WordRise da ingliz tilini o‘rganmoqda',
                            style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        final encoded = Uri.encodeComponent(shareText);
                        _launchUrl('https://t.me/share/url?url=https://t.me/wordriseapp&text=$encoded');
                      },
                      icon: const Icon(Icons.telegram_rounded, color: Colors.white),
                      label: const Text('Telegram'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF229ED9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shareText));
                        AudioHapticService.instance.lightImpact();
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Taklif havolasi nusxalandi!'),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, color: Colors.white),
                      label: const Text('Nusxa olish'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Future<void> _clearCache(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Keshni tozalash'),
        content: const Text('Oflayn saqlangan vaqtinchalik ma‘lumotlar tozalanadi. Davom etasizmi?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Bekor qilish'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tozalash'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (widget.offlineCacheService != null) {
        await widget.offlineCacheService!.clearAllCache();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Kesh muvaffaqiyatli tozalandi!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorMsg;
    bool loading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            return Container(
              color: Theme.of(ctx).scaffoldBackgroundColor,
              child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Parolni o‘zgartirish',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Yangi parolingiz kamida 6 belgidan iborat bo‘lishi lozim.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: passwordCtrl,
                    label: 'Yangi parol',
                    icon: Icons.lock_outline_rounded,
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: confirmCtrl,
                    label: 'Yangi parolni tasdiqlang',
                    icon: Icons.lock_rounded,
                    obscureText: true,
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMsg!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Saqlash',
                    icon: Icons.check_rounded,
                    loading: loading,
                    onPressed: () async {
                      final p1 = passwordCtrl.text.trim();
                      final p2 = confirmCtrl.text.trim();
                      if (p1.length < 6) {
                        setStateSheet(() => errorMsg = 'Parol kamida 6 belgidan iborat bo‘lishi shart.');
                        return;
                      }
                      if (p1 != p2) {
                        setStateSheet(() => errorMsg = 'Kiritilgan parollar bir-biriga mos kelmadi.');
                        return;
                      }
                      setStateSheet(() {
                        loading = true;
                        errorMsg = null;
                      });
                      try {
                        final updated = await widget.authService.updateProfile(
                          name: widget.user.name,
                          username: widget.user.username,
                          email: widget.user.email,
                          password: p1,
                        );
                        widget.onProfileChanged(updated);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Parol muvaffaqiyatli yangilandi!'),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        setStateSheet(() {
                          loading = false;
                          errorMsg = e.toString();
                        });
                      }
                    },
                  ),
                ],
              ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Hisobni butunlay o‘chirish?'),
        content: const Text(
          'DIQQAT: Hisobingiz, barcha o‘rganilgan so‘zlar, erishilgan yutuqlar va darslar butunlay o‘chib ketadi va ularni tiklab bo‘lmaydi!',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Bekor qilish'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ha, o‘chirilsin'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await widget.authService.deleteAccount();
        widget.onLogout();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_book_rounded, color: Colors.blueAccent),
            ),
            const SizedBox(width: 12),
            const Text('WordRise', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WordRise — Zamonaviy va qulay ingliz tili lug‘at hamda viktorina platformasi.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 12),
            Text('• Versiya: 1.2.0 (Build 4.0.2)', style: TextStyle(color: Colors.grey, fontSize: 13)),
            Text('• Dasturchi: WordRise Team', style: TextStyle(color: Colors.grey, fontSize: 13)),
            Text('• Aloqa: @uzsly', style: TextStyle(color: Colors.blueAccent, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Yopish'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmLogout(BuildContext context, AppLocalizations l10n) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.t('profile.logoutConfirmTitle')),
        content: Text(l10n.t('profile.logoutConfirmBody')),
        actions: [
          CupertinoDialogAction(
            child: Text(l10n.t('common.cancel')),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.t('profile.logoutConfirm')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onLogout();
    }
  }

  Future<void> _openEditProfile(BuildContext context) async {
    final updated = await Navigator.of(context).push<UserModel>(
      CupertinoPageRoute(
        builder: (_) => EditProfileScreen(user: widget.user, authService: widget.authService),
      ),
    );
    if (updated != null) {
      widget.onProfileChanged(updated);
    }
  }

  String _localeLabel(BuildContext context) {
    return context.l10n.t('language.${widget.locale.languageCode}');
  }

  String _themeLabel(BuildContext context) {
    return context.l10n.t(switch (widget.themeMode) {
      ThemeMode.light => 'profile.light',
      ThemeMode.dark => 'profile.dark',
      ThemeMode.system => 'profile.system',
    });
  }

  Future<void> _pickLocale(BuildContext context) async {
    final value = await showIosSelectionSheet<Locale>(
      context: context,
      title: context.l10n.t('profile.language'),
      selected: widget.locale,
      options: [
        IosSelectionOption(value: const Locale('uz'), label: context.l10n.t('language.uz')),
        IosSelectionOption(value: const Locale('en'), label: context.l10n.t('language.en')),
        IosSelectionOption(value: const Locale('ru'), label: context.l10n.t('language.ru')),
      ],
    );
    if (value != null) widget.onLocaleChanged(value);
  }

  Future<void> _pickTheme(BuildContext context) async {
    final value = await showIosSelectionSheet<ThemeMode>(
      context: context,
      title: context.l10n.t('profile.theme'),
      selected: widget.themeMode,
      options: [
        IosSelectionOption(value: ThemeMode.light, label: context.l10n.t('profile.light')),
        IosSelectionOption(value: ThemeMode.dark, label: context.l10n.t('profile.dark')),
        IosSelectionOption(value: ThemeMode.system, label: context.l10n.t('profile.system')),
      ],
    );
    if (value != null) widget.onThemeModeChanged(value);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.icon,
    required this.iconBgColor,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailingText,
    this.textColor,
  });

  final IconData icon;
  final Color iconBgColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final String? trailingText;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final defaultColor = isDark ? Colors.white : Colors.black;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBgColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconBgColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor ?? defaultColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText!,
                style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ProfileSwitchRow extends StatelessWidget {
  const _ProfileSwitchRow({
    required this.icon,
    required this.iconBgColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconBgColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final defaultColor = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconBgColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: defaultColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: Colors.blueAccent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
