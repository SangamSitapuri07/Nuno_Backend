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
              alignment: Alignment(-1.1, -0.9),
              color: AppColors.violet,
              size: 260,
              opacity: 0.22,
            ),
            const _Blob(
              alignment: Alignment(1.15, 1.0),
              color: AppColors.primary,
              size: 240,
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
