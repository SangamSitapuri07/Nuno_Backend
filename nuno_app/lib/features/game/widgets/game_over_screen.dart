import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/game_assets.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../data/models/game_state.dart';
import '../game_providers.dart';

/// Screen 12 — Game Over. Crowned winner on top, final standings below,
/// PLAY AGAIN (gold) and LOBBY (blue) actions.
class GameOverScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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

                      // ── Play again vote ──────────────────
                      //
                      // The dialog stays open after voting. It used to pop
                      // immediately, which left the player staring at an
                      // empty table with no idea whether anyone else had
                      // agreed - and the server needs every player to accept
                      // before it can start the next match.
                      Builder(
                        builder: (context) {
                          final ui = ref.watch(gameControllerProvider);
                          final everyone = game?.players ?? const <String>[];
                          final accepted = ui.rematchAcceptedBy;
                          final declined = ui.rematchDeclinedBy;

                          final iVoted =
                              myId != null && accepted.contains(myId);
                          final someoneLeft = declined.isNotEmpty;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (someoneLeft)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppDimens.sm,
                                  ),
                                  child: Text(
                                    'Someone left - a rematch is off.',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.danger,
                                    ),
                                  ),
                                )
                              else if (iVoted && everyone.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppDimens.sm,
                                  ),
                                  child: Text(
                                    'Waiting for the others... '
                                    '${accepted.length}/${everyone.length} '
                                    'ready',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.gold,
                                    ),
                                  ),
                                ),

                              Row(
                                children: [
                                  Expanded(
                                    child: AppButton(
                                      label: iVoted
                                          ? 'WAITING...'
                                          : 'PLAY AGAIN',
                                      size: AppButtonSize.small,
                                      variant: AppButtonVariant.gold,
                                      // Disabled once voted, so the same
                                      // player cannot be counted twice, and
                                      // once a rematch is impossible.
                                      onPressed: (iVoted || someoneLeft)
                                          ? null
                                          : onPlayAgain,
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
                          );
                        },
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
