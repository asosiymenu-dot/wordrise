import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shared app canvas with two slow ambient light ribbons.
///
/// The ribbons are intentionally broad and low-contrast. They keep the glass
/// surfaces alive without using expensive animated blur circles.
class GradientBackground extends StatefulWidget {
  const GradientBackground({
    required this.child,
    this.safeArea = true,
    this.maxContentWidth = 760,
    super.key,
  });

  final Widget child;
  final bool safeArea;
  final double maxContentWidth;

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 32),
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
    final isDark = AppColors.isDark(context);
    final content = widget.safeArea
        ? SafeArea(child: widget.child)
        : widget.child;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  AppColors.darkBgStart,
                  AppColors.darkBgMiddle,
                  AppColors.darkBgEnd,
                ]
              : const [AppColors.bgStart, AppColors.bgMiddle, AppColors.bgEnd],
          stops: const [0, .52, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final phase = _controller.value * math.pi * 2;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: -90 + math.sin(phase) * 20,
                          left: -230 + math.cos(phase) * 24,
                          child: Transform.rotate(
                            angle: -.18,
                            child: _AmbientRibbon(
                              width: 680,
                              height: 190,
                              color: isDark
                                  ? AppColors.blue.withValues(alpha: .10)
                                  : AppColors.blue.withValues(alpha: .13),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -70 + math.cos(phase) * 18,
                          right: -260 + math.sin(phase) * 26,
                          child: Transform.rotate(
                            angle: .22,
                            child: _AmbientRibbon(
                              width: 720,
                              height: 210,
                              color: isDark
                                  ? AppColors.purple.withValues(alpha: .08)
                                  : AppColors.purple.withValues(alpha: .10),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropGroup(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: SizedBox(
                        width: math.min(
                          constraints.maxWidth,
                          widget.maxContentWidth,
                        ),
                        height: constraints.maxHeight,
                        child: content,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _AmbientRibbon extends StatelessWidget {
  const _AmbientRibbon({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: LinearGradient(
          colors: [Colors.transparent, color, color, Colors.transparent],
          stops: const [0, .28, .72, 1],
        ),
      ),
    );
  }
}
