import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/uno_logo.dart';

/// Screen 1 — branded splash while the persisted session is restored.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.9,
            colors: [Color(0xFF1B1440), Color(0xFF07081A)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.03).animate(
                  CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
                ),
                child: UnoLogo(width: (width * 0.34).clamp(200.0, 320.0)),
              ),
              const SizedBox(height: AppDimens.xxxl),
              SizedBox(
                width: 160,
                child: ClipRRect(
                  borderRadius: AppDimens.brPill,
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: AppColors.surfaceHigh,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.md),
              Text('Loading...', style: AppTextStyles.caption),
            ],
          ),
        ),
      ),
    );
  }
}
