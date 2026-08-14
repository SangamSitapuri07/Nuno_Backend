import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../data/models/game_state.dart';
import 'playing_card.dart';

enum SeatPlacement { left, top, right }

/// An opponent around the landscape table: avatar with turn ring, name, and a
/// fan of face-down cards oriented toward the table centre.
class OpponentSeat extends StatelessWidget {
  final GamePlayerInfo player;
  final SeatPlacement placement;
  final bool isCurrentTurn;
  final bool hasCalledUno;
  final double turnProgress;

  const OpponentSeat({
    super.key,
    required this.player,
    this.placement = SeatPlacement.top,
    this.isCurrentTurn = false,
    this.hasCalledUno = false,
    this.turnProgress = 1,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = _Avatar(
      player: player,
      isCurrentTurn: isCurrentTurn,
      hasCalledUno: hasCalledUno,
      turnProgress: turnProgress,
    );

    final fan = _MiniFan(
      count: player.cardCount,
      vertical: placement != SeatPlacement.top,
    );

    return switch (placement) {
      // Top seats stack avatar over a horizontal fan.
      SeatPlacement.top => Column(
          mainAxisSize: MainAxisSize.min,
          children: [avatar, const SizedBox(height: 3), fan],
        ),
      // Side seats put the fan toward the centre of the table.
      SeatPlacement.left => Row(
          mainAxisSize: MainAxisSize.min,
          children: [avatar, const SizedBox(width: 3), fan],
        ),
      SeatPlacement.right => Row(
          mainAxisSize: MainAxisSize.min,
          children: [fan, const SizedBox(width: 3), avatar],
        ),
    };
  }
}

class _Avatar extends StatelessWidget {
  final GamePlayerInfo player;
  final bool isCurrentTurn;
  final bool hasCalledUno;
  final double turnProgress;

  const _Avatar({
    required this.player,
    required this.isCurrentTurn,
    required this.hasCalledUno,
    required this.turnProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (isCurrentTurn)
              SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  value: turnProgress,
                  strokeWidth: 2.5,
                  backgroundColor: Colors.black.withValues(alpha: 0.35),
                  valueColor: AlwaysStoppedAnimation(
                    turnProgress < 0.3 ? AppColors.danger : AppColors.gold,
                  ),
                ),
              ),
            PlayerAvatar(
              username: player.username,
              size: 34,
              isActive: isCurrentTurn,
              ringColor: isCurrentTurn ? AppColors.gold : null,
            ),
            if (hasCalledUno)
              Positioned(
                top: -7,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppDimens.brPill,
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  child: Text(
                    'UNO',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 58,
          child: Text(
            player.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isCurrentTurn
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Small fan of face-down cards with the count badge.
class _MiniFan extends StatelessWidget {
  final int count;
  final bool vertical;

  const _MiniFan({required this.count, this.vertical = false});

  @override
  Widget build(BuildContext context) {
    const w = AppDimens.opponentCardWidth;
    const h = w / 0.68;
    final visible = count.clamp(0, 5);
    const step = 6.0;

    if (visible == 0) {
      return SizedBox(width: w, height: h);
    }

    return SizedBox(
      width: vertical ? w + 6 : w + step * (visible - 1),
      height: vertical ? h + step * (visible - 1) : h + 6,
      child: Stack(
        children: [
          for (var i = 0; i < visible; i++)
            Positioned(
              left: vertical ? 0 : i * step,
              top: vertical ? i * step : 0,
              child: const CardBackView(width: w),
            ),
          // Count badge.
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: count == 1 ? AppColors.primary : Colors.black87,
                borderRadius: AppDimens.brPill,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                '$count',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
