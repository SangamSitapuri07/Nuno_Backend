import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import '../../services/socket_events.dart';
import '../../services/voice_service.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/game_assets.dart';
import '../../data/models/enums.dart';
import '../../data/models/game_card.dart';
import '../../data/models/game_state.dart';
import '../auth/auth_controller.dart';
import '../matchmaking/matchmaking_providers.dart';
import '../store/cosmetics_provider.dart';
import 'game_providers.dart';
import 'widgets/card_action_popup.dart';
import 'widgets/draw_flight.dart';
import 'widgets/exit_confirm_dialog.dart';
import 'widgets/game_chat_sheet.dart';
import 'widgets/game_hud.dart';
import 'widgets/game_over_screen.dart';
import 'widgets/opponent_seat.dart';
import 'widgets/player_hand.dart';
import 'widgets/quick_chat_sheet.dart';
import 'widgets/shuffle_intro.dart';
import 'widgets/swap_target_dialog.dart';
import 'widgets/table_center.dart';
import 'widgets/table_overlays.dart';
import 'widgets/table_toasts.dart';

/// The landscape game table, matching the gameplay mockup.
///
/// Deep red radial background; NUNO badge + room info top-left; action buttons
/// and LEAVE ROOM top-right; players seated top / left / right with the local
/// player lower-left; glowing pile vortex in the middle; fanned hand along the
/// bottom; timer dial and UNO! button on the right.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _resultShown = false;
  bool _micOn = false;
  bool _soundOn = true;
  bool _voiceStarting = false;
  bool _introDone = false;

  /// Captured while the widget is alive.
  ///
  /// Reading a provider inside dispose() is not safe - the element is already
  /// being torn down - so the call was silently skipped and the microphone
  /// stayed live after leaving the table, which is why audio kept coming
  /// through back in the lobby.
  VoiceService? _voice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _voice = ref.read(voiceServiceProvider);
      ref.read(gameControllerProvider.notifier).requestSync();
      _joinVoice();
    });
  }

  /// Joins the voice channel as soon as the table opens, muted.
  ///
  /// Previously the channel was only joined when a player pressed the mic,
  /// which meant nobody could hear anyone until BOTH sides had pressed it -
  /// there was no peer connection to carry the audio otherwise. Joining up
  /// front establishes the connection; the mic button then only controls
  /// whether the local track is live, so one player unmuting is immediately
  /// audible to everyone else.
  Future<void> _joinVoice() async {
    final game = ref.read(gameControllerProvider).game;
    final roomId = game?.roomId;
    if (roomId == null || roomId.isEmpty) return;

    final voice = ref.read(voiceServiceProvider);
    if (voice.isActive) return;

    final ok = await voice.join(roomId);
    if (!ok || !mounted) return;

    // Connected but silent until the player opts in.
    voice.setMuted(true);
    if (mounted) setState(() => _micOn = false);
  }

  @override
  void dispose() {
    // Fire and forget: dispose cannot await, but leave() tears down the peer
    // connections and stops the local track immediately.
    _voice?.leave();
    super.dispose();
  }

  /// Mic starts off and joining is explicit, because the first tap is what
  /// triggers the runtime permission prompt.
  Future<void> _toggleMic(String roomId) async {
    final voice = ref.read(voiceServiceProvider);

    if (_micOn) {
      voice.setMuted(true);
      setState(() => _micOn = false);
      return;
    }

    if (_voiceStarting) return;
    setState(() => _voiceStarting = true);

    // Normally already joined from initState; this covers the case where
    // that first attempt failed, for example because permission was refused.
    final ok = voice.isActive ? true : await voice.join(roomId);
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _voiceStarting = false;
        _micOn = false;
      });
      AppSnack.error(
        context,
        'Microphone permission is required for voice chat.',
      );
      return;
    }

    voice.setMuted(false);
    setState(() {
      _voiceStarting = false;
      _micOn = true;
    });
  }

  void _toggleSound() {
    final next = !_soundOn;
    ref.read(voiceServiceProvider).setSpeakerEnabled(next);
    setState(() => _soundOn = next);
  }

  Future<void> _playCard(GameCard card) async {
    final controller = ref.read(gameControllerProvider.notifier);
    final game = ref.read(gameControllerProvider).game;
    final myId = ref.read(currentUserIdProvider);

    // Out of turn, but the card is an exact match and jump-in is on: this is
    // a jump-in rather than an illegal play.
    if (game != null &&
        myId != null &&
        game.houseRules.jumpIn &&
        !game.isMyTurn(myId) &&
        _canJumpIn(card, game)) {
      controller.jumpIn(card);
      return;
    }

    if (card.isWild) {
      final color = await CardActionPopup.show(context, card: card);
      if (color == null || !mounted) return;
      controller.playCard(card, selectedColor: color);
      return;
    }

    // A 7 under seven-zero needs a target before it means anything.
    if (game != null &&
        myId != null &&
        game.houseRules.sevenZero &&
        card.value == CardValue.seven &&
        game.players.length > 1) {
      final target = await SwapTargetDialog.show(
        context,
        game: game,
        myId: myId,
      );
      if (!mounted) return;
      controller.playCard(card, swapWith: target);
      return;
    }

    controller.playCard(card);
  }

  /// Mirrors RuleEngine.canJumpIn: exact colour and value, numbers only, and
  /// never while a draw stack is pending.
  bool _canJumpIn(GameCard card, GameState game) {
    if (game.pendingDraw > 0) return false;
    final top = game.topCard;
    if (top == null) return false;
    // Numbers only: an action card jumped in from another seat makes the
    // turn order unresolvable, which is why the server refuses it too.
    if (!card.value.isNumber) return false;
    return card.color == top.color && card.value == top.value;
  }

  Future<void> _confirmExit() async {
    final leave = await ExitConfirmDialog.show(context);
    if (leave == true && mounted) {
      final c = ref.read(gameControllerProvider.notifier);
      c.surrender();
      c.reset();
      context.go(AppRoutes.home);
    }
  }

  void _showResult(GameResultPayload result, String? myId) {
    if (_resultShown) return;
    _resultShown = true;

    GameOverScreen.show(
      context,
      result: result,
      game: ref.read(gameControllerProvider).game,
      myId: myId,
      // Called by the countdown and by the button; the dialog is already
      // popped by the time this runs.
      onLobby: () {
        // The server drops everyone from the room when a match ends, but say
        // so anyway: this also covers leaving before that has been processed,
        // and it is harmless when the room is already gone.
        ref.read(socketServiceProvider).emit(SocketEvents.roomLeave);
        ref.read(gameControllerProvider.notifier).reset();
        // The matchmaking controller is a provider too, and its status is
        // still `inGame` from the match that just ended. Left set, the next
        // visit to Quick Match skips the table-size picker, because that is
        // only drawn while the status is `idle`.
        ref.read(matchmakingControllerProvider.notifier).reset();
        ref.read(authControllerProvider.notifier).refreshProfile();
        if (context.mounted) context.go(AppRoutes.home);
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
      // The initial state usually arrives after the first frame, so the join
      // attempted in initState may have had no room id to work with yet.
      if (prev?.game == null && next.game != null) _joinVoice();

      if (next.result != null && next.result != prev?.result) {
        _showResult(next.result!, myId);
      }

      if (next.error != null && next.error != prev?.error) {
        AppSnack.error(context, next.error!);
        controller.clearError();
      }
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0618),
        body: ArtBackground(
          asset: ref.watch(equippedCosmeticsProvider).tableTheme.asset,
          colors: ref.watch(equippedCosmeticsProvider).tableTheme.colors,
          child: Stack(
            children: [
              // Clipped: the table is a fixed-size Stack on a viewport whose
              // height varies by device, and anything spilling past the edge
              // would paint the debug overflow stripes over the hand.
              ClipRect(
                child: SafeArea(
                // The table is full-bleed art; the cutout must not shrink it.
                left: false,
                child: game == null
                    ? const LoadingView(label: 'Joining the table...')
                    : _Table(
                        state: state,
                        game: game,
                        myId: myId,
                        isMyTurn: isMyTurn,
                        micOn: _micOn,
                        soundOn: _soundOn,
                        onToggleMic: () => _toggleMic(game.roomId),
                        onToggleSound: _toggleSound,
                        onPlayCard: _playCard,
                        onExit: _confirmExit,
                      ),
                ),
              ),

              // Shuffle-and-deal flourish over the first moment of the match.
              if (!_introDone)
                Positioned.fill(
                  child: ShuffleIntro(
                    onComplete: () {
                      if (mounted) setState(() => _introDone = true);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Table extends ConsumerWidget {
  final GameUiState state;
  final GameState game;
  final String? myId;
  final bool isMyTurn;
  final bool micOn;
  final bool soundOn;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleSound;
  final Future<void> Function(GameCard) onPlayCard;
  final VoidCallback onExit;

  const _Table({
    required this.state,
    required this.game,
    required this.myId,
    required this.isMyTurn,
    required this.micOn,
    required this.soundOn,
    required this.onToggleMic,
    required this.onToggleSound,
    required this.onPlayCard,
    required this.onExit,
  });

  /// Anchors for the draw animation.
  static final GlobalKey drawPileKey = GlobalKey();
  static final GlobalKey handKey = GlobalKey();

  /// Centre of a keyed widget in global coordinates, or null if unmounted.
  static Offset? _globalCentre(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  static const _ringColors = [
    AppColors.blue,
    AppColors.green,
    AppColors.gold,
    AppColors.rarityEpic,
    AppColors.cyan,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(gameControllerProvider.notifier);
    final opponents = game.opponentsFrom(myId ?? '');
    final seats = _seat(opponents);
    final me = myId == null ? null : game.playerInfo(myId!);
    final canCallUno =
        game.shouldCallUno && !state.unoCalledBy.contains(myId ?? '');

    Color ringFor(String userId) =>
        _ringColors[userId.hashCode.abs() % _ringColors.length];

    return Stack(
      children: [
        // ── Centre piles ─────────────────────────────
        Align(
          // Nudged down: at -0.10 the discard pile met the top seat's card
          // fan, so the two overlapped on a short landscape viewport.
          alignment: const Alignment(0, 0.06),
          child: TableCenter(
            topCard: game.topCard,
            currentColor: game.currentColor,
            drawPileCount: game.drawPileCount,
            direction: game.direction,
            canDraw: isMyTurn && state.pendingCardId == null,
            drawPileKey: drawPileKey,
            onDraw: () {
              // Fly a card from the pile into the hand before the state
              // update lands, so the new card has a visible origin.
              final from = _globalCentre(drawPileKey);
              final to = _globalCentre(handKey);
              if (from != null && to != null) {
                DrawFlight.play(
                  context,
                  from: from - const Offset(31, 46),
                  to: to - const Offset(31, 46),
                );
              }
              controller.drawCard();
            },
          ),
        ),

        // ── Top seat ─────────────────────────────────
        if (seats.top != null)
          Align(
            alignment: const Alignment(0, -1),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: OpponentSeat(
                player: seats.top!,
                placement: SeatPlacement.top,
                isCurrentTurn: seats.top!.userId == game.currentTurn,
                hasCalledUno: state.unoCalledBy.contains(seats.top!.userId),
                ringColor: ringFor(seats.top!.userId),
                score: 0,
              ),
            ),
          ),

        // ── Left seat ────────────────────────────────
        if (seats.left != null)
          Align(
            alignment: const Alignment(-1, -0.25),
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: OpponentSeat(
                player: seats.left!,
                placement: SeatPlacement.left,
                isCurrentTurn: seats.left!.userId == game.currentTurn,
                hasCalledUno: state.unoCalledBy.contains(seats.left!.userId),
                ringColor: ringFor(seats.left!.userId),
              ),
            ),
          ),

        // ── Right seat ───────────────────────────────
        if (seats.right != null)
          Align(
            alignment: const Alignment(1, -0.25),
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: OpponentSeat(
                player: seats.right!,
                placement: SeatPlacement.right,
                isCurrentTurn: seats.right!.userId == game.currentTurn,
                hasCalledUno: state.unoCalledBy.contains(seats.right!.userId),
                ringColor: ringFor(seats.right!.userId),
              ),
            ),
          ),

        // ── Extra seats, if more than three opponents ─
        if (seats.extra.isNotEmpty)
          Align(
            alignment: const Alignment(0, -0.72),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final o in seats.extra)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: OpponentSeat(
                      player: o,
                      placement: SeatPlacement.top,
                      isCurrentTurn: o.userId == game.currentTurn,
                      hasCalledUno: state.unoCalledBy.contains(o.userId),
                      ringColor: ringFor(o.userId),
                    ),
                  ),
              ],
            ),
          ),

        // ── You, lower-left ──────────────────────────
        Align(
          alignment: const Alignment(-1, 0.42),
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OpponentSeat(
                  player: GamePlayerInfo(
                    userId: myId ?? '',
                    username: 'You',
                    level: me?.level ?? 1,
                    cardCount: 0,
                  ),
                  placement: SeatPlacement.bottom,
                  isCurrentTurn: isMyTurn,
                  hasCalledUno: state.unoCalledBy.contains(myId ?? ''),
                  ringColor: AppColors.primary,
                  // Our own seat, so it wears our equipped avatar and frame.
                  isSelf: true,
                ),
                if (isMyTurn)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 26),
                  ),
              ],
            ),
          ),
        ),

        // ── Top-left info ────────────────────────────
        Positioned(
          top: 4,
          left: 8,
          child: GameTopLeft(
            roomCode: game.roomId.isEmpty
                ? '------'
                : game.roomId.substring(0, game.roomId.length.clamp(0, 8)),
            mode: 'Classic',
            pingMs: 52,
          ),
        ),

        // ── Top-right controls ───────────────────────
        Positioned(
          top: 4,
          right: 8,
          child: GameTopRight(
            micEnabled: micOn,
            soundEnabled: soundOn,
            onChat: () => GameChatSheet.show(context),
            onMic: onToggleMic,
            onSound: onToggleSound,
            onMenu: onExit,
            onLeave: onExit,
          ),
        ),

        // ── Current card readout ─────────────────────
        Align(
          alignment: const Alignment(0.62, 0.30),
          child: CurrentCardChip(
            value: game.currentValue.glyph,
            color: AppColors.forCardColor(game.currentColor.wire),
            colorName: game.currentColor.isWild
                ? 'Wild'
                : game.currentColor.label,
          ),
        ),

        // ── Timer dial ───────────────────────────────
        Align(
          alignment: const Alignment(0.95, 0.44),
          child: TurnTimerDial(
            seconds: state.turnSecondsLeft,
            totalSeconds: AppConfig.turnTimerSeconds,
          ),
        ),

        // ── UNO! button ──────────────────────────────
        Align(
          alignment: const Alignment(0.95, 0.86),
          child: _UnoButton(
            enabled: canCallUno,
            onPressed: controller.callUno,
          ),
        ),

        // ── Emote button ─────────────────────────────
        Align(
          alignment: const Alignment(-0.97, 0.95),
          child: GestureDetector(
            onTap: () => QuickChatSheet.show(
              context,
              onEmote: controller.sendEmote,
              onQuickChat: controller.sendQuickChat,
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_emotions_rounded,
                  size: 24, color: Color(0xFF2A0507)),
            ),
          ),
        ),

        // ── My hand ──────────────────────────────────
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: PlayerHand(
              key: handKey,
              cards: game.myHand,
              isPlayable: game.isCardPlayable,
              isMyTurn: isMyTurn && state.pendingCardId == null,
              canJumpIn: (card) =>
                  state.pendingCardId == null &&
                  game.houseRules.jumpIn &&
                  game.pendingDraw == 0 &&
                  card.value.isNumber &&
                  game.topCard != null &&
                  card.color == game.topCard!.color &&
                  card.value == game.topCard!.value,
              pendingCardId: state.pendingCardId,
              onPlay: onPlayCard,
            ),
          ),
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

  /// Seats opponents: first to the top, then left, then right.
  _Seats _seat(List<GamePlayerInfo> o) {
    return switch (o.length) {
      0 => const _Seats(),
      1 => _Seats(top: o[0]),
      2 => _Seats(left: o[0], right: o[1]),
      3 => _Seats(left: o[0], top: o[1], right: o[2]),
      _ => _Seats(
          left: o[0],
          top: o[1],
          right: o[2],
          extra: o.sublist(3),
        ),
    };
  }
}

class _Seats {
  final GamePlayerInfo? left;
  final GamePlayerInfo? top;
  final GamePlayerInfo? right;
  final List<GamePlayerInfo> extra;

  const _Seats({this.left, this.top, this.right, this.extra = const []});
}

/// Large rounded UNO! button, bottom-right.
class _UnoButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _UnoButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.xxl,
          vertical: AppDimens.md,
        ),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [Color(0xFFFF7A3D), Color(0xFFEF3A2E)],
                )
              : null,
          color: enabled ? null : Colors.black.withValues(alpha: 0.45),
          borderRadius: AppDimens.brPill,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF5A2E).withValues(alpha: 0.6),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Text(
          'UNO!',
          style: AppTextStyles.h2.copyWith(
            color: enabled ? Colors.white : Colors.white38,
            fontSize: 24,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
