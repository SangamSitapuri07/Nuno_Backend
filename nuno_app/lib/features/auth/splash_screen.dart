import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/server_wakeup.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/uno_logo.dart';

/// Screen 1 — branded splash while the session is restored.
///
/// Also surfaces the hosted backend's cold start: a free-tier Render instance
/// sleeps after ~15 minutes and can take about a minute to wake, so we say so
/// rather than appearing to hang.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
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
    final status = ref.watch(serverWakeupProvider);

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
                width: 180,
                child: ClipRRect(
                  borderRadius: AppDimens.brPill,
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: AppColors.surfaceHigh,
                    valueColor: AlwaysStoppedAnimation(
                      status == ServerStatus.unreachable
                          ? AppColors.danger
                          : AppColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppDimens.md),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _StatusMessage(
                  key: ValueKey(status),
                  status: status,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final ServerStatus status;

  const _StatusMessage({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ServerStatus.waking:
        return Column(
          children: [
            Text(
              'Waking the server...',
              style: AppTextStyles.body.copyWith(color: AppColors.gold),
            ),
            const SizedBox(height: 2),
            Text(
              'The free hosting tier sleeps when idle.\nThis can take up to a minute.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(fontSize: 10),
            ),
          ],
        );

      case ServerStatus.unreachable:
        return Column(
          children: [
            Text(
              'Cannot reach the server',
              style: AppTextStyles.body.copyWith(color: AppColors.danger),
            ),
            const SizedBox(height: 2),
            Text(
              AppConfig.baseUrl,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(fontSize: 9),
            ),
          ],
        );

      case ServerStatus.awake:
      case ServerStatus.unknown:
        return Text('Loading...', style: AppTextStyles.caption);
    }
  }
}
