import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Ambient app background: deep gradient plus soft colour blooms.
class AppBackground extends StatelessWidget {
  final Widget child;
  final bool showBlobs;

  const AppBackground({super.key, required this.child, this.showBlobs = true});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: Stack(
        children: [
          if (showBlobs) ...[
            const _Blob(
              alignment: Alignment(-1.1, -0.85),
              color: AppColors.primary,
              size: 300,
              opacity: 0.30,
            ),
            const _Blob(
              alignment: Alignment(1.2, -0.55),
              color: AppColors.accent,
              size: 240,
              opacity: 0.16,
            ),
            const _Blob(
              alignment: Alignment(0.9, 1.05),
              color: AppColors.cardRed,
              size: 280,
              opacity: 0.14,
            ),
          ],
          child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final double size;
  final double opacity;

  const _Blob({
    required this.alignment,
    required this.color,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withValues(alpha: opacity), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}

/// Decorative scattered card suits/pips used on the auth screens.
class ScatteredCardsDecoration extends StatelessWidget {
  const ScatteredCardsDecoration({super.key});

  static const _specs = [
    (Alignment(-1.05, -0.72), AppColors.cardRed, -0.35, 74.0),
    (Alignment(1.08, -0.62), AppColors.cardBlue, 0.42, 66.0),
    (Alignment(-0.95, 0.62), AppColors.cardGreen, 0.28, 58.0),
    (Alignment(1.02, 0.78), AppColors.cardYellow, -0.30, 62.0),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          for (final (align, color, angle, size) in _specs)
            Align(
              alignment: align,
              child: Transform.rotate(
                angle: angle,
                child: Container(
                  width: size,
                  height: size / 0.68,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Transform.rotate(
                      angle: math.pi / 12,
                      child: Container(
                        width: size * 0.45,
                        height: size * 0.62,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
