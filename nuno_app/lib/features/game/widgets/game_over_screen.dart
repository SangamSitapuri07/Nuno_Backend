import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/game_assets.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../data/models/game_state.dart';

/// Screen 12 — Game Over. Crowned winner on top, final standings below,
/// PLAY AGAIN (gold) and LOBBY (blue) actions.
class GameOverScreen extends StatelessWidget {
  final GameResultPayload result;
  final GameState? game;
  final String? myId;
  final VoidCallback onPlayAgain;
  final VoidCallback onLobby;

  const GameOverScreen({
    super.key,
    required this.result,
    required this.game,
    required this.myId,
    required this.onPlayAgain,
    required this.onLobby,
  });

  static Future<void> show(
    BuildContext context, {
    required GameResultPayload result,
    required GameState? game,
    required String? myId,
    required VoidCallback onPlayAgain,
    required VoidCallback onLobby,
  }) =>
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => GameOverScreen(
          result: result,
          game: game,
          myId: myId,
          onPlayAgain: onPlayAgain,
          onLobby: onLobby,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final winnerId = result.winner;
    final winnerName =
        winnerId == null ? 'Nobody' : (game?.playerInfo(winnerId).username ?? 'Player');
    final standings = _standings();

    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.all(AppDimens.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 330),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: AppDimens.panelHeaderHeight,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.panelHeader,
                  border: Border(
                    bottom: BorderSide(color: AppColors.surfaceStroke),
                  ),
                ),
                child: Text('GAME OVER', style: AppTextStyles.panelTitle),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimens.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ornate VICTORY banner above the winner.
                      if (winnerId == myId)
                        ArtImage(
                          Art.victoryBanner,
                          width: 240,
                          fallback: Text(
                            'VICTORY',
                            style: AppTextStyles.h2
                                .copyWith(color: AppColors.gold),
                          ),
                        )
                      else
                        ArtImage(Art.trophy, width: 74),
                      const SizedBox(height: AppDimens.xs),
                      PlayerAvatar(
                        username: winnerName,
                        size: 52,
                        ringColor: AppColors.gold,
                      ),
                      const SizedBox(height: AppDimens.sm),
                      Text(
                        winnerName,
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.gold,
                        ),
                      ),
                      Text(
                        winnerId == myId ? 'You won!' : 'Winner',
                        style: AppTextStyles.caption,
                      ),

                      const SizedBox(height: AppDimens.md),

                      // Standings
                      for (var i = 0; i < standings.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: _StandingRow(
                            place: i + 1,
                            name: standings[i].$1,
                            score: standings[i].$2,
                            isMe: standings[i].$3,
                          ),
                        ),

                      const SizedBox(height: AppDimens.md),

                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'PLAY AGAIN',
                              size: AppButtonSize.small,
                              variant: AppButtonVariant.gold,
                              onPressed: () {
                                Navigator.of(context).pop();
                                onPlayAgain();
                              },
                            ),
                          ),
                          const SizedBox(width: AppDimens.sm),
                          Expanded(
                            child: AppButton(
                              label: 'LOBBY',
                              size: AppButtonSize.small,
                              variant: AppButtonVariant.blue,
                              onPressed: () {
                                Navigator.of(context).pop();
                                onLobby();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ranks players: winner first, then fewest cards remaining.
  List<(String, int, bool)> _standings() {
    final g = game;
    if (g == null) return const [];

    final ids = [...g.players];
    ids.sort((a, b) {
      if (a == result.winner) return -1;
      if (b == result.winner) return 1;
      return g.cardCountOf(a).compareTo(g.cardCountOf(b));
    });

    return [
      for (var i = 0; i < ids.length; i++)
        (
          g.playerInfo(ids[i]).username,
          // Simple placement score, highest for the winner.
          (ids.length - i) * 100 + (i == 0 ? 50 : 0),
          ids[i] == myId,
        ),
    ];
  }
}

class _StandingRow extends StatelessWidget {
  final int place;
  final String name;
  final int score;
  final bool isMe;

  const _StandingRow({
    required this.place,
    required this.name,
    required this.score,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final isWinner = place == 1;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm),
      decoration: BoxDecoration(
        color: isWinner
            ? AppColors.gold.withValues(alpha: 0.14)
            : AppColors.surfaceHigh,
        borderRadius: AppDimens.brSm,
        border: Border.all(
          color: isWinner
              ? AppColors.gold.withValues(alpha: 0.5)
              : AppColors.surfaceStroke,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Text(
              '$place',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: isWinner ? AppColors.gold : AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              isMe ? '$name (You)' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                fontSize: 12,
                color: isWinner ? AppColors.gold : AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '$score',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
