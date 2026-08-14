import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';

/// Top bar of the game table: exit, turn indicator + timer, chat.
class GameHud extends StatelessWidget {
  final String turnLabel;
  final int secondsLeft;
  final bool isMyTurn;
  final VoidCallback onLeave;
  final VoidCallback onChat;
  final int unreadChat;

  const GameHud({
    super.key,
    required this.turnLabel,
    required this.secondsLeft,
    required this.isMyTurn,
    required this.onLeave,
    required this.onChat,
    this.unreadChat = 0,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        (secondsLeft / AppConfig.turnTimerSeconds).clamp(0.0, 1.0);
    final urgent = secondsLeft <= 5;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.sm,
      ),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.close_rounded,
            size: 40,
            background: Colors.black.withValues(alpha: 0.3),
            tooltip: 'Leave match',
            onPressed: onLeave,
          ),

          const SizedBox(width: AppDimens.md),

          // Turn pill with timer bar.
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.lg,
                vertical: AppDimens.sm,
              ),
              decoration: BoxDecoration(
                color: isMyTurn
                    ? AppColors.accent.withValues(alpha: 0.16)
                    : Colors.black.withValues(alpha: 0.3),
                borderRadius: AppDimens.brPill,
                border: Border.all(
                  color: isMyTurn
                      ? AppColors.accent.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isMyTurn
                            ? Icons.play_circle_fill_rounded
                            : Icons.hourglass_top_rounded,
                        size: 15,
                        color: isMyTurn
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          turnLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isMyTurn
                                ? AppColors.accent
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimens.sm),
                      Text(
                        '${secondsLeft}s',
                        style: AppTextStyles.caption.copyWith(
                          color: urgent
                              ? AppColors.danger
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: AppDimens.brPill,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: Colors.black.withValues(alpha: 0.35),
                      valueColor: AlwaysStoppedAnimation(
                        urgent
                            ? AppColors.danger
                            : (isMyTurn
                                ? AppColors.accent
                                : AppColors.textMuted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: AppDimens.md),

          AppIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            size: 40,
            background: Colors.black.withValues(alpha: 0.3),
            tooltip: 'Chat',
            onPressed: onChat,
          ),
        ],
      ),
    );
  }
}
