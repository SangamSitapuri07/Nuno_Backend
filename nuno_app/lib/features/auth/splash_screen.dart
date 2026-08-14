import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_background.dart';

/// Shown while the persisted session is being restored.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: Tween(begin: 0.94, end: 1.04).animate(
                  CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
                ),
                child: const NunoLogo(size: 96),
              ),
              const SizedBox(height: AppDimens.xxl),
              Text('NUNO', style: AppTextStyles.logo),
              const SizedBox(height: AppDimens.sm),
              Text(
                'PLAY. MATCH. WIN.',
                style: AppTextStyles.label.copyWith(color: AppColors.accent),
              ),
              const SizedBox(height: AppDimens.huge),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stacked-cards logo mark.
class NunoLogo extends StatelessWidget {
  final double size;

  const NunoLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.5,
      height: size * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _card(AppColors.cardRed, -0.34, const Offset(-22, 4)),
          _card(AppColors.cardYellow, -0.12, const Offset(-8, -2)),
          _card(AppColors.cardGreen, 0.12, const Offset(8, -2)),
          _card(AppColors.cardBlue, 0.34, const Offset(22, 4)),
          Container(
            width: size * 0.52,
            height: size * 0.52,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.6),
                  blurRadius: 20,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'N',
              style: AppTextStyles.cardGlyph(size * 0.3)
                  .copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Color color, double angle, Offset offset) {
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: size * 0.42,
          height: size * 0.62,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(size * 0.08),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
