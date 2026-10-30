import 'dart:ui';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';

/// Five-destination iOS-style tab bar with persistent, readable labels.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    required this.currentIndex,
    required this.onChanged,
    this.unreadMessages = 0,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;
  final int unreadMessages;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppColors.isDark(context);

    final navTheme = NavigationBarThemeData(
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.blue
              : AppColors.textMuted(context),
          size: states.contains(WidgetState.selected) ? 23 : 22,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.blue
              : AppColors.textMuted(context),
          fontSize: 10.5,
          height: 1.15,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          letterSpacing: 0,
        );
      }),
    );

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? .24 : .08),
                    blurRadius: 24,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.glassSurface(
                        context,
                        alpha: isDark ? .76 : .82,
                      ),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: .10)
                            : Colors.white.withValues(alpha: .88),
                        width: .8,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: NavigationBarTheme(
                      data: navTheme,
                      child: NavigationBar(
                        selectedIndex: currentIndex,
                        height: 62,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        backgroundColor: Colors.transparent,
                        indicatorColor: Colors.transparent,
                        labelBehavior:
                            NavigationDestinationLabelBehavior.alwaysShow,
                        onDestinationSelected: onChanged,
                        destinations: [
                          NavigationDestination(
                            icon: const Icon(Icons.home_outlined),
                            selectedIcon: const Icon(Icons.home_rounded),
                            label: l10n.t('nav.home'),
                          ),
                          NavigationDestination(
                            icon: const Icon(Icons.menu_book_outlined),
                            selectedIcon: const Icon(Icons.menu_book_rounded),
                            label: l10n.t('nav.lessons'),
                          ),
                          NavigationDestination(
                            icon: const Icon(Icons.quiz_outlined),
                            selectedIcon: const Icon(Icons.quiz_rounded),
                            label: l10n.t('nav.quiz'),
                          ),
                          NavigationDestination(
                            icon: _BadgeIcon(
                              icon: Icons.chat_bubble_outline_rounded,
                              count: unreadMessages,
                              size: 22,
                            ),
                            selectedIcon: _BadgeIcon(
                              icon: Icons.chat_bubble_rounded,
                              count: unreadMessages,
                              size: 23,
                            ),
                            label: l10n.t('nav.messages'),
                          ),
                          NavigationDestination(
                            icon: const Icon(Icons.person_outline_rounded),
                            selectedIcon: const Icon(Icons.person_rounded),
                            label: l10n.t('nav.profile'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({
    required this.icon,
    required this.count,
    required this.size,
  });

  final IconData icon;
  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: Icon(icon, size: size)),
          if (count > 0)
            Positioned(
              right: -3,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.softRed,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
