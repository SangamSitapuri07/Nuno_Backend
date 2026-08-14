import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../data/models/game_state.dart';
import 'playing_card.dart';

enum SeatPlacement { left, top, right, bottom }

/// A player around the table, matching the gameplay mockup: circular avatar
/// with a coloured ring and a level badge, a dark name plate carrying a trophy
/// score, an angled fan of card backs, and a small card-count badge.
class OpponentSeat extends StatelessWidget {
  final GamePlayerInfo player;
  final SeatPlacement placement;
  final bool isCurrentTurn;
  final bool hasCalledUno;
  final double turnProgress;
  final Color ringColor;
  final int score;

  const OpponentSeat({
    super.key,
    required this.player,
    this.placement = SeatPlacement.top,
    this.isCurrentTurn = false,
    this.hasCalledUno = false,
    this.turnProgress = 1,
    this.ringColor = AppColors.blue,
    this.score = 0,
  });

  @override
  Widget build(BuildContext context) {
    final identity = _Identity(
      player: player,
      isCurrentTurn: isCurrentTurn,
      hasCalledUno: hasCalledUno,
      ringColor: ringColor,
      score: score,
    );

    final fan = _CardFan(count: player.cardCount, placement: placement);

    switch (placement) {
      case SeatPlacement.top:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [identity, const SizedBox(height: 2), fan],
        );
      case SeatPlacement.left:
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [identity, const SizedBox(width: 2), fan],
        );
      case SeatPlacement.right:
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [fan, const SizedBox(width: 2), identity],
        );
      case SeatPlacement.bottom:
        return identity;
    }
  }
}

class _Identity extends StatelessWidget {
  final GamePlayerInfo player;
  final bool isCurrentTurn;
  final bool hasCalledUno;
  final Color ringColor;
  final int score;

  const _Identity({
    required this.player,
    required this.isCurrentTurn,
    required this.hasCalledUno,
    required this.ringColor,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Avatar with a thick coloured ring.
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 3),
                boxShadow: isCurrentTurn
                    ? [
                        BoxShadow(
                          color: ringColor.withValues(alpha: 0.65),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: PlayerAvatar(username: player.username, size: 46),
            ),

            // Level badge, top-right on the ring.
            Positioned(
              top: -4,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                constraints: const BoxConstraints(minWidth: 22),
                decoration: BoxDecoration(
                  color: ringColor,
                  borderRadius: AppDimens.brPill,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '${player.level}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),

            if (hasCalledUno)
              Positioned(
                bottom: -6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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

        const SizedBox(height: 4),

        // Name plate with trophy score.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: AppDimens.brSm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                player.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (score > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events_rounded,
                        size: 11, color: AppColors.gold),
                    const SizedBox(width: 3),
                    Text(
                      _formatScore(score),
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatScore(int v) {
    if (v < 1000) return '$v';
    final s = v.toString();
    return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }
}

/// Angled fan of card backs with a count badge, oriented toward the table.
class _CardFan extends StatelessWidget {
  final int count;
  final SeatPlacement placement;

  const _CardFan({required this.count, required this.placement});

  @override
  Widget build(BuildContext context) {
    final visible = count.clamp(0, 7);
    if (visible == 0) return const SizedBox.shrink();

    const cardW = 26.0;
    final cardH = cardW / 0.68;
    const step = 11.0;
    const spread = 0.10;

    final isSide =
        placement == SeatPlacement.left || placement == SeatPlacement.right;

    final width = cardW + step * (visible - 1) + 10;
    final height = cardH + 16;

    return SizedBox(
      width: isSide ? width * 0.92 : width,
      height: height + 14,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < visible; i++)
            Positioned(
              left: i * step,
              top: 6 - math.cos((i - (visible - 1) / 2) * 0.5) * 3,
              child: Transform.rotate(
                angle: (i - (visible - 1) / 2) * spread,
                child: const CardBackView(width: cardW),
              ),
            ),

          // Count badge below the fan.
          Positioned(
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: count == 1
                    ? AppColors.primary
                    : Colors.black.withValues(alpha: 0.82),
                borderRadius: AppDimens.brSm,
              ),
              child: Text(
                '$count',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
