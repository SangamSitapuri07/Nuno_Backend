import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/player_avatar.dart';
import '../../data/models/game_card.dart';
import '../../data/models/game_state.dart';
import '../auth/auth_controller.dart';
import 'game_providers.dart';
import 'widgets/card_action_popup.dart';
import 'widgets/exit_confirm_dialog.dart';
import 'widgets/game_chat_sheet.dart';
import 'widgets/game_over_screen.dart';
import 'widgets/opponent_seat.dart';
import 'widgets/quick_chat_sheet.dart';
import 'widgets/player_hand.dart';
import 'widgets/table_center.dart';
import 'widgets/table_overlays.dart';
import 'widgets/table_toasts.dart';

/// Screens 7 & 8 — the landscape game table.
///
/// Layout mirrors the reference: timer top-left, a chat bubble top-right,
/// opponents seated left / top / right, the draw+discard piles centred, and the
/// local player's fanned hand along the bottom. The whole table glows RED on an
/// opponent's turn and GREEN on yours.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameControllerProvider.notifier).requestSync();
    });
  }

  Future<void> _playCard(GameCard card) async {
    final controller = ref.read(gameControllerProvider.notifier);

    if (card.isWild) {
      // Screen 9 — Card Action popup.
      final color = await CardActionPopup.show(context, card: card);
      if (color == null || !mounted) return;
      controller.playCard(card, selectedColor: color);
    } else {
      controller.playCard(card);
    }
  }

  Future<void> _confirmExit() async {
    // Screen 30 — Exit Confirm.
    final leave = await ExitConfirmDialog.show(context);
    if (leave == true && mounted) {
      final controller = ref.read(gameControllerProvider.notifier);
      controller.surrender();
      controller.reset();
      context.go(AppRoutes.home);
    }
  }

  void _showResult(GameResultPayload result, String? myId) {
    if (_resultShown) return;
    _resultShown = true;

    // Screen 12 — Game Over.
    final game = ref.read(gameControllerProvider).game;
    GameOverScreen.show(
      context,
      result: result,
      game: game,
      myId: myId,
      onPlayAgain: () {
        _resultShown = false;
        ref.read(gameControllerProvider.notifier).requestRematch();
      },
      onLobby: () {
        ref.read(gameControllerProvider.notifier).reset();
        ref.read(authControllerProvider.notifier).refreshProfile();
        context.go(AppRoutes.home);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);
    final myId = ref.watch(currentUserIdProvider);
    final isMyTurn = ref.watch(isMyTurnProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    ref.listen<GameUiState>(gameControllerProvider, (prev, next) {
      if (next.result != null && next.result != prev?.result) {
        _showResult(next.result!, myId);
      }
      if (next.error != null && next.error != prev?.error) {
        AppSnack.error(context, next.error!);
        controller.clearError();
      }
      // Screen 11 — Draw Penalty.
      // Screen 10 — UNO! burst when I successfully declare.
      final me = myId;
      if (me != null &&
          next.unoCalledBy.contains(me) &&
          !(prev?.unoCalledBy.contains(me) ?? false)) {
        UnoDeclaredOverlay.show(context);
      }
      if (next.penaltyDraw != null && next.penaltyDraw != prev?.penaltyDraw) {
        DrawPenaltyOverlay.show(context, count: next.penaltyDraw!);
        controller.clearPenalty();
      }
    });

    final game = state.game;

    // Table ambience follows whose turn it is.
    final glow = isMyTurn ? AppColors.tableGlowGreen : AppColors.tableGlowRed;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.tableBase,
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          decoration: BoxDecoration(
            gradient: AppColors.tableGradient(glow),
          ),
          child: SafeArea(
            child: game == null
                ? const LoadingView(label: 'Joining the table...')
                : _TableLayout(
                    state: state,
                    game: game,
                    myId: myId,
                    isMyTurn: isMyTurn,
                    onPlayCard: _playCard,
                    onExit: _confirmExit,
                  ),
          ),
        ),
      ),
    );
  }
}

class _TableLayout extends ConsumerWidget {
  final GameUiState state;
  final GameState game;
  final String? myId;
  final bool isMyTurn;
  final Future<void> Function(GameCard) onPlayCard;
  final VoidCallback onExit;

  const _TableLayout({
    required this.state,
    required this.game,
    required this.myId,
    required this.isMyTurn,
    required this.onPlayCard,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(gameControllerProvider.notifier);
    final opponents = game.opponentsFrom(myId ?? '');
    final seats = _distributeSeats(opponents);
    final turnProgress =
        (state.turnSecondsLeft / AppConfig.turnTimerSeconds).clamp(0.0, 1.0);

    return Stack(
      children: [
        // ── Main table column ────────────────────────
        Column(
          children: [
            // Top row: timer · top opponents · chat
            SizedBox(
              height: 74,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TurnTimer(
                    seconds: state.turnSecondsLeft,
                    isMyTurn: isMyTurn,
                    onTap: onExit,
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final o in seats.top)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimens.md,
                            ),
                            child: OpponentSeat(
                              player: o,
                              placement: SeatPlacement.top,
                              isCurrentTurn: o.userId == game.currentTurn,
                              hasCalledUno:
                                  state.unoCalledBy.contains(o.userId),
                              turnProgress: turnProgress,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _ChatButton(
                    onTap: () => GameChatSheet.show(context),
                    unread: state.messages.length,
                  ),
                ],
              ),
            ),

            // Middle: side seats + centre piles
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final o in seats.left)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppDimens.sm,
                            ),
                            child: OpponentSeat(
                              player: o,
                              placement: SeatPlacement.left,
                              isCurrentTurn: o.userId == game.currentTurn,
                              hasCalledUno:
                                  state.unoCalledBy.contains(o.userId),
                              turnProgress: turnProgress,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: TableCenter(
                        topCard: game.topCard,
                        currentColor: game.currentColor,
                        drawPileCount: game.drawPileCount,
                        direction: game.direction,
                        canDraw: isMyTurn && state.pendingCardId == null,
                        onDraw: controller.drawCard,
                        showYourTurn: isMyTurn,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final o in seats.right)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppDimens.sm,
                            ),
                            child: OpponentSeat(
                              player: o,
                              placement: SeatPlacement.right,
                              isCurrentTurn: o.userId == game.currentTurn,
                              hasCalledUno:
                                  state.unoCalledBy.contains(o.userId),
                              turnProgress: turnProgress,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom: you + hand + UNO
            _BottomBar(
              state: state,
              game: game,
              myId: myId,
              isMyTurn: isMyTurn,
              onPlayCard: onPlayCard,
              onCallUno: controller.callUno,
              onEmote: controller.sendEmote,
              onQuickChat: controller.sendQuickChat,
            ),
          ],
        ),

        TableToasts(toasts: state.toasts),

        if (state.isSyncing)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.5),
              child: const LoadingView(label: 'Syncing...'),
            ),
          ),
      ],
    );
  }

  /// Spreads opponents around the table: with few players they sit on the
  /// sides, and overflow fills the top edge.
  _Seats _distributeSeats(List<GamePlayerInfo> opponents) {
    final left = <GamePlayerInfo>[];
    final top = <GamePlayerInfo>[];
    final right = <GamePlayerInfo>[];

    switch (opponents.length) {
      case 0:
        break;
      case 1:
        top.add(opponents[0]);
      case 2:
        left.add(opponents[0]);
        right.add(opponents[1]);
      case 3:
        left.add(opponents[0]);
        top.add(opponents[1]);
        right.add(opponents[2]);
      case 4:
        left.add(opponents[0]);
        top.addAll([opponents[1], opponents[2]]);
        right.add(opponents[3]);
      default:
        // 5+: two per side, remainder across the top.
        left.addAll(opponents.take(2));
        right.addAll(opponents.skip(opponents.length - 2));
        top.addAll(opponents.skip(2).take(opponents.length - 4));
    }

    return _Seats(left: left, top: top, right: right);
  }
}

class _Seats {
  final List<GamePlayerInfo> left;
  final List<GamePlayerInfo> top;
  final List<GamePlayerInfo> right;

  const _Seats({required this.left, required this.top, required this.right});
}

// ── Turn timer (top-left) ─────────────────────────────────────

class _TurnTimer extends StatelessWidget {
  final int seconds;
  final bool isMyTurn;
  final VoidCallback onTap;

  const _TurnTimer({
    required this.seconds,
    required this.isMyTurn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final urgent = seconds <= 5;
    final label =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.all(AppDimens.sm),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: AppDimens.brPill,
            border: Border.all(
              color: urgent
                  ? AppColors.danger
                  : Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 14,
                color: urgent ? AppColors.danger : AppColors.gold,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: urgent ? AppColors.danger : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatButton extends StatelessWidget {
  final VoidCallback onTap;
  final int unread;

  const _ChatButton({required this.onTap, this.unread = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.sm),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: const Icon(Icons.chat_bubble_outline_rounded,
              size: 16, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

// ── Bottom bar: you + hand + UNO ──────────────────────────────

class _BottomBar extends StatelessWidget {
  final GameUiState state;
  final GameState game;
  final String? myId;
  final bool isMyTurn;
  final Future<void> Function(GameCard) onPlayCard;
  final VoidCallback onCallUno;
  final void Function(String) onEmote;
  final void Function(String) onQuickChat;

  const _BottomBar({
    required this.state,
    required this.game,
    required this.myId,
    required this.isMyTurn,
    required this.onPlayCard,
    required this.onCallUno,
    required this.onEmote,
    required this.onQuickChat,
  });

  @override
  Widget build(BuildContext context) {
    final me = myId == null ? null : game.playerInfo(myId!);
    final canCallUno =
        game.shouldCallUno && !state.unoCalledBy.contains(myId ?? '');

    return SizedBox(
      height: AppDimens.handCardHeight + 26,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // You
          Padding(
            padding: const EdgeInsets.only(
              left: AppDimens.sm,
              bottom: AppDimens.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PlayerAvatar(
                  username: me?.username ?? 'You',
                  size: 38,
                  isActive: isMyTurn,
                  ringColor: isMyTurn ? AppColors.green : null,
                ),
                const SizedBox(height: 2),
                Text(
                  'You',
                  style: AppTextStyles.caption.copyWith(fontSize: 9),
                ),
                Text(
                  '${game.myHand.length}',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ),

          // Hand
          Expanded(
            child: PlayerHand(
              cards: game.myHand,
              isPlayable: game.isCardPlayable,
              isMyTurn: isMyTurn && state.pendingCardId == null,
              pendingCardId: state.pendingCardId,
              onPlay: onPlayCard,
            ),
          ),

          // Emote + UNO
          Padding(
            padding: const EdgeInsets.only(
              right: AppDimens.sm,
              bottom: AppDimens.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => QuickChatSheet.show(
                    context,
                    onEmote: onEmote,
                    onQuickChat: onQuickChat,
                  ),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: const Icon(Icons.emoji_emotions_outlined,
                        size: 16, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: AppDimens.sm),
                _UnoButton(enabled: canCallUno, onPressed: onCallUno),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The red pill UNO button from the reference's hand strip.
class _UnoButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _UnoButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.playGradient : null,
          color: enabled ? null : Colors.black.withValues(alpha: 0.4),
          borderRadius: AppDimens.brPill,
          border: Border.all(
            color: enabled
                ? Colors.white
                : Colors.white.withValues(alpha: 0.12),
            width: enabled ? 1.8 : 1,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.6),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Text(
          'UNO',
          style: AppTextStyles.button.copyWith(
            fontSize: 13,
            color: enabled ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
