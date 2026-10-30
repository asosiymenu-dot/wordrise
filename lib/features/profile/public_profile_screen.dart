import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/api_models.dart';

class PublicProfileScreen extends StatelessWidget {
  const PublicProfileScreen({required this.user, this.onMessage, super.key});

  final PublicUserModel user;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.t('profile.viewProfile'),
                    style: AppTextStyles.titleFor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                children: [
                  UserAvatar(
                    name: user.name,
                    avatarUrl: user.avatar,
                    size: 96,
                    backgroundColor: AppColors.blue,
                    online: user.isOnline,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.name,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleFor(context),
                  ),
                  if (user.username.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '@${user.username}',
                      style: AppTextStyles.captionFor(
                        context,
                      ).copyWith(color: AppColors.purple),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: user.isOnline
                              ? AppColors.green
                              : AppColors.textMuted(context),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _publicPresenceLabel(context, user),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.captionFor(context).copyWith(
                            color: user.isOnline
                                ? AppColors.green
                                : AppColors.textMuted(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _PublicStat(
                          label: l10n.t('profile.level'),
                          value: '${user.level}',
                          icon: Icons.bolt_rounded,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PublicStat(
                          label: l10n.t('profile.streak'),
                          value: l10n.f('profile.days', {'count': user.streak}),
                          icon: Icons.local_fire_department_rounded,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onMessage != null) ...[
              const SizedBox(height: 16),
              PrimaryButton(
                label: l10n.t('messages.sendMessage'),
                icon: Icons.chat_bubble_rounded,
                onPressed: onMessage,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _publicPresenceLabel(BuildContext context, PublicUserModel user) {
  if (user.isOnline) return context.l10n.t('messages.online');
  final seen = user.localLastSeenAt;
  if (seen == null) return context.l10n.t('messages.offline');
  final now = DateTime.now();
  final time = DateFormat('HH:mm').format(seen);
  if (_profileSameDay(seen, now)) {
    return context.l10n.f('messages.lastSeenToday', {'time': time});
  }
  if (_profileSameDay(seen, now.subtract(const Duration(days: 1)))) {
    return context.l10n.f('messages.lastSeenYesterday', {'time': time});
  }
  return context.l10n.f('messages.lastSeenDate', {
    'date': DateFormat('dd.MM.yyyy HH:mm').format(seen),
  });
}

bool _profileSameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

class _PublicStat extends StatelessWidget {
  const _PublicStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.sectionFor(context)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.captionFor(context)),
        ],
      ),
    );
  }
}
