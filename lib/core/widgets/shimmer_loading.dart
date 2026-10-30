import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'glass_card.dart';

class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 14,
    super.key,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations && _controller.isAnimating) {
      _controller.stop();
    } else if (!disableAnimations && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppColors.isDark(context)
        ? Colors.white.withValues(alpha: .10)
        : AppColors.navy.withValues(alpha: .07);
    final highlight = AppColors.isDark(context)
        ? Colors.white.withValues(alpha: .22)
        : Colors.white.withValues(alpha: .78);

    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              final slide = _controller.value * 2 - 1;
              return LinearGradient(
                begin: Alignment(-1 + slide, 0),
                end: Alignment(1 + slide, 0),
                colors: [base, highlight, base],
                stops: const [.20, .50, .80],
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: child,
          );
        },
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        ),
      ),
    );
  }
}

class ShimmerLoadingList extends StatelessWidget {
  const ShimmerLoadingList({
    this.itemCount = 4,
    this.compact = false,
    super.key,
  });

  final int itemCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < itemCount; index++) ...[
          GlassCard(
            padding: EdgeInsets.all(compact ? 14 : 16),
            opacity: AppColors.isDark(context) ? .20 : .38,
            child: Row(
              children: [
                ShimmerBox(
                  width: compact ? 42 : 52,
                  height: compact ? 42 : 52,
                  borderRadius: compact ? 16 : 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(
                        width: double.infinity,
                        height: compact ? 14 : 16,
                      ),
                      const SizedBox(height: 9),
                      FractionallySizedBox(
                        widthFactor: .62,
                        child: ShimmerBox(
                          width: double.infinity,
                          height: compact ? 10 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (index != itemCount - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}
