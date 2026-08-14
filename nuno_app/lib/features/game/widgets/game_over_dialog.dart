import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/models/game_state.dart';

/// End-of-match result modal with rematch / exit.
class GameOverDialog extends StatelessWidget {
  final GameResultPayload result;
  final bool isWinner;
  final String winnerName;
  final VoidCallback onRematch;
  final VoidCallback onExit;

  const GameOverDialog({
    super.key,
    required this.result,
    required this.isWinner,
    required this.winnerName,
    required this.onRematch,
    required this.onExit,
  });

  static Future<void> show(
    BuildContext context, {
    required GameResultPayload result,
    required bool isWinner,
    required String winnerName,
    required VoidCallback onRematch,
    required VoidCallback onExit,
  }) =>
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => GameOverDialog(
          result: result,
          isWinner: isWinner,
          winnerName: winnerName,
          onRematch: onRematch,
          onExit: onExit,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final accent = isWinner ? AppColors.gold : AppColors.textMuted;

    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.all(AppDimens.xxl),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trophy / medal.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1),
                duration: const Duration(milliseconds: 520),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isWinner
                        ? AppColors.goldGradient
                        : LinearGradient(
                            colors: [
                              AppColors.surfaceHigh,
                              AppColors.surface,
                            ],
                          ),
                    boxShadow: isWinner
                        ? [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.5),
                              blurRadius: 32,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    isWinner
                        ? Icons.emoji_events_rounded
                        : Icons.sentiment_neutral_rounded,
                    size: 48,
                    color: isWinner ? const Color(0xFF3A2600) : accent,
                  ),
                ),
              ),

              const SizedBox(height: AppDimens.xl),

              Text(
                isWinner ? 'Victory!' : 'Defeat',
                style: AppTextStyles.h1.copyWith(
                  color: isWinner ? AppColors.gold : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppDimens.xs),
              Text(
                isWinner
                    ? 'You cleared your hand first.'
                    : '$winnerName won this round.',
                style: AppTextStyles.bodySm,
                textAlign: TextAlign.center,
              ),

              if (result.surrenderedBy != null) ...[
                const SizedBox(height: AppDimens.sm),
                Text(
                  'A player surrendered.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ],

              const SizedBox(height: AppDimens.xxl),

              // Match stats.
              Row(
                children: [
                  Expanded(
                    child: _ResultStat(
                      label: 'Duration',
                      value: result.durationLabel,
                      icon: Icons.timer_outlined,
                    ),
                  ),
                  const SizedBox(width: AppDimens.md),
                  Expanded(
                    child: _ResultStat(
                      label: 'Turns',
                      value: '${result.totalTurns}',
                      icon: Icons.repeat_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimens.xxl),

              AppButton(
                label: 'REMATCH',
                icon: Icons.refresh_rounded,
                onPressed: () {
                  Navigator.of(context).pop();
                  onRematch();
                },
              ),
              const SizedBox(height: AppDimens.md),
              AppButton(
                label: 'BACK TO HOME',
                variant: AppButtonVariant.ghost,
                onPressed: () {
                  Navigator.of(context).pop();
                  onExit();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ResultStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppDimens.brMd,
        border: Border.all(color: AppColors.surfaceStroke),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(height: AppDimens.sm),
          Text(value, style: AppTextStyles.numeric.copyWith(fontSize: 18)),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
