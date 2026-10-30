import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class QuizOptionCard extends StatelessWidget {
  const QuizOptionCard({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.index,
    this.correct,
    super.key,
  });

  final String label;
  final bool selected;
  final bool? correct;
  final VoidCallback? onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final isCorrect = correct == true;
    final isWrongSelection = correct == false && selected;
    final isRevealedOther = correct != null && !isCorrect && !isWrongSelection;

    final letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    final badgeLetter = index < letters.length ? letters[index] : '${index + 1}';

    // Gradients for modern feel
    final Gradient? gradient = isCorrect
        ? const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : isWrongSelection
            ? const LinearGradient(
                colors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : selected
                ? const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null;

    final Color solidBg = isDark
        ? const Color(0xFF1E293B).withValues(alpha: isRevealedOther ? 0.35 : 0.85)
        : Colors.white.withValues(alpha: isRevealedOther ? 0.45 : 0.95);

    final Color textColor = (selected || isCorrect || isWrongSelection)
        ? Colors.white
        : isDark
            ? (isRevealedOther ? Colors.white38 : Colors.white)
            : (isRevealedOther ? Colors.black38 : const Color(0xFF0F172A));

    final Color badgeBg = (selected || isCorrect || isWrongSelection)
        ? Colors.white.withValues(alpha: 0.22)
        : isDark
            ? const Color(0xFF334155).withValues(alpha: isRevealedOther ? 0.3 : 0.8)
            : const Color(0xFFF1F5F9).withValues(alpha: isRevealedOther ? 0.4 : 0.9);

    final Color badgeTextColor = (selected || isCorrect || isWrongSelection)
        ? Colors.white
        : isDark
            ? (isRevealedOther ? Colors.white38 : const Color(0xFF94A3B8))
            : (isRevealedOther ? Colors.black38 : const Color(0xFF64748B));

    final border = isCorrect
        ? Border.all(color: const Color(0xFF34D399), width: 1.5)
        : isWrongSelection
            ? Border.all(color: const Color(0xFFFB7185), width: 1.5)
            : selected
                ? Border.all(color: const Color(0xFF818CF8), width: 1.5)
                : Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    width: 1,
                  );

    return Opacity(
      opacity: isRevealedOther ? 0.45 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            if (isCorrect)
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              )
            else if (isWrongSelection)
              BoxShadow(
                color: const Color(0xFFF43F5E).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              )
            else if (selected)
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            splashColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
            highlightColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: gradient == null ? solidBg : null,
                gradient: gradient,
                borderRadius: BorderRadius.circular(18),
                border: border,
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeLetter,
                      style: TextStyle(
                        color: badgeTextColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                  if (isCorrect) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Color(0xFF059669),
                        size: 16,
                      ),
                    ),
                  ] else if (isWrongSelection) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFFE11D48),
                        size: 16,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
