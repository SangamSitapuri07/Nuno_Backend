import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../data/models/game_state.dart';

/// One opponent around the table: avatar, name, card count and turn timer ring.
class OpponentSeat extends StatelessWidget {
  final GamePlayerInfo player;
  final bool isCurrentTurn;
  final bool hasCalledUno;
  final double turnProgress;
  final bool compact;

  const OpponentSeat({
    super.key,
    required this.player,
    this.isCurrentTurn = false,
    this.hasCalledUno = false,
    this.turnProgress = 1,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatarSize = compact ? 44.0 : 52.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.sm,
        vertical: AppDimens.sm,
      ),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? AppColors.accent.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.22),
        borderRadius: AppDimens.brLg,
        border: Border.all(
          color: isCurrentTurn
              ? AppColors.accent.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.08),
          width: isCurrentTurn ? 1.6 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Turn countdown ring.
              if (isCurrentTurn)
                SizedBox(
                  width: avatarSize + 10,
                  height: avatarSize + 10,
                  child: CircularProgressIndicator(
                    value: turnProgress,
                    strokeWidth: 3,
                    backgroundColor: Colors.black.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation(
                      turnProgress < 0.3
                          ? AppColors.danger
                          : AppColors.accent,
                    ),
                  ),
                ),

              PlayerAvatar(
                username: player.username,
                size: avatarSize,
                level: player.level,
                isActive: isCurrentTurn,
              ),

              // UNO badge.
              if (hasCalledUno)
                Positioned(
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.dangerGradient,
                      borderRadius: AppDimens.brPill,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      'NUNO',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppDimens.xs),

          SizedBox(
            width: avatarSize + 22,
            child: Text(
              player.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: isCurrentTurn
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(height: 3),

          // Card count pill.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: player.cardCount == 1
                  ? AppColors.danger.withValues(alpha: 0.22)
                  : Colors.black.withValues(alpha: 0.35),
              borderRadius: AppDimens.brPill,
              border: Border.all(
                color: player.cardCount == 1
                    ? AppColors.danger
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.style_rounded,
                  size: 10,
                  color: player.cardCount == 1
                      ? AppColors.danger
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 3),
                Text(
                  '${player.cardCount}',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: player.cardCount == 1
                        ? AppColors.danger
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
