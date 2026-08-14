import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_states.dart';
import '../../data/models/game_card.dart';
import '../../data/models/game_state.dart';
import '../auth/auth_controller.dart';
import 'game_providers.dart';
import 'widgets/color_picker_sheet.dart';
import 'widgets/game_chat_sheet.dart';
import 'widgets/game_hud.dart';
import 'widgets/game_over_dialog.dart';
import 'widgets/opponent_seat.dart';
import 'widgets/player_hand.dart';
import 'widgets/table_center.dart';
import 'widgets/table_toasts.dart';

/// The live match table.
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
      final color = await ColorPickerSheet.show(context);
      if (color == null || !mounted) return;
      controller.playCard(card, selectedColor: color);
    } else {
      controller.playCard(card);
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave the match?'),
        content: const Text(
          'Leaving counts as a surrender and your opponent wins.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep playing', style: AppTextStyles.body),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Surrender',
              style: AppTextStyles.body.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (leave == true && mounted) {
      ref.read(gameControllerProvider.notifier).surrender();
      ref.read(gameControllerProvider.notifier).reset();
      context.go(AppRoutes.home);
    }
  }

  void _showResult(GameResultPayload result, String? myId) {
    if (_resultShown) return;
    _resultShown = true;

    final game = ref.read(gameControllerProvider).game;
    final winnerName = result.winner == null
        ? 'Nobody'
        : (game?.playerInfo(result.winner!).username ?? 'Player');

    GameOverDialog.show(
      context,
      result: result,
      isWinner: result.winner != null && result.winner == myId,
      winnerName: winnerName,
      onRematch: () {
        _resultShown = false;
        ref.read(gameControllerProvider.notifier).requestRematch();
      },
      onExit: () {
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
    });

    final game = state.game;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D2A22),
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.feltGradient),
          child: SafeArea(
            child: game == null
                ? const LoadingView(label: 'Joining the table...')
                : _TableLayout(
                    state: state,
                    game: game,
                    myId: myId,
                    isMyTurn: isMyTurn,
                    onPlayCard: _playCard,
                    onLeave: _confirmLeave,
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
  final VoidCallback onLeave;

  const _TableLayout({
    required this.state,
    required this.game,
    required this.myId,
    required this.isMyTurn,
    required this.onPlayCard,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(gameControllerProvider.notifier);
    final opponents = game.opponentsFrom(myId ?? '');
    final turnProgress =
        (state.turnSecondsLeft / AppConfig.turnTimerSeconds).clamp(0.0, 1.0);

    return Stack(
      children: [
        Column(
          children: [
            // ── HUD ────────────────────────────────────
            GameHud(
              turnLabel: isMyTurn
                  ? 'Your turn'
                  : '${game.playerInfo(game.currentTurn).username}\'s turn',
              secondsLeft: state.turnSecondsLeft,
              isMyTurn: isMyTurn,
              onLeave: onLeave,
              onChat: () => GameChatSheet.show(context),
              unreadChat: state.messages.length,
            ),

            // ── Opponents ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.md,
                vertical: AppDimens.sm,
              ),
              child: _OpponentRow(
                opponents: opponents,
                currentTurn: game.currentTurn,
                unoCalledBy: state.unoCalledBy,
                turnProgress: turnProgress,
              ),
            ),

            // ── Table centre ───────────────────────────
            Expanded(
              child: Center(
                child: TableCenter(
                  topCard: game.topCard,
                  currentColor: game.currentColor,
                  drawPileCount: game.drawPileCount,
                  direction: game.direction,
                  canDraw: isMyTurn && state.pendingCardId == null,
                  onDraw: controller.drawCard,
                ),
              ),
            ),

            // ── Turn banner ────────────────────────────
            if (isMyTurn && !game.hasAnyPlayable)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.sm),
                child: _HintBanner(
                  text: 'No playable card — draw from the pile',
                  color: AppColors.warning,
                ),
              ),

            // ── My hand ────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.sm),
              child: PlayerHand(
                cards: game.myHand,
                isPlayable: game.isCardPlayable,
                isMyTurn: isMyTurn && state.pendingCardId == null,
                pendingCardId: state.pendingCardId,
                onPlay: onPlayCard,
              ),
            ),

            // ── Action bar ─────────────────────────────
            _ActionBar(
              cardCount: game.myHand.length,
              canCallUno: game.shouldCallUno &&
                  !state.unoCalledBy.contains(myId ?? ''),
              hasCalledUno: state.unoCalledBy.contains(myId ?? ''),
              onCallUno: controller.callUno,
              onEmote: (key) => controller.sendEmote(key),
              onQuickChat: (key) => controller.sendQuickChat(key),
            ),
          ],
        ),

        // ── Floating toasts ──────────────────────────
        TableToasts(toasts: state.toasts),

        // ── Syncing overlay ──────────────────────────
        if (state.isSyncing)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.45),
              child: const LoadingView(label: 'Syncing...'),
            ),
          ),
      ],
    );
  }
}

class _OpponentRow extends StatelessWidget {
  final List<GamePlayerInfo> opponents;
  final String currentTurn;
  final Set<String> unoCalledBy;
  final double turnProgress;

  const _OpponentRow({
    required this.opponents,
    required this.currentTurn,
    required this.unoCalledBy,
    required this.turnProgress,
  });

  @override
  Widget build(BuildContext context) {
    if (opponents.isEmpty) return const SizedBox.shrink();

    final compact = opponents.length > 3;

    // Up to 4 seats share the width; beyond that the row scrolls.
    final perSeat = (MediaQuery.sizeOf(context).width -
                AppDimens.md * 2 -
                AppDimens.sm * (opponents.length.clamp(1, 4) - 1)) /
            opponents.length.clamp(1, 4);
    final seatWidth = perSeat.clamp(72.0, 160.0);

    return SizedBox(
      height: compact ? 104 : 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: opponents.length <= 4
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm),
        itemCount: opponents.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppDimens.sm),
        itemBuilder: (context, i) {
          final o = opponents[i];
          return SizedBox(
            width: seatWidth,
            child: OpponentSeat(
              player: o,
              isCurrentTurn: o.userId == currentTurn,
              hasCalledUno: unoCalledBy.contains(o.userId),
              turnProgress: turnProgress,
              compact: compact,
            ),
          );
        },
      ),
    );
  }
}

class _HintBanner extends StatelessWidget {
  final String text;
  final Color color;

  const _HintBanner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimens.xxl),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: AppDimens.brPill,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: color),
          const SizedBox(width: AppDimens.sm),
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final int cardCount;
  final bool canCallUno;
  final bool hasCalledUno;
  final VoidCallback onCallUno;
  final void Function(String) onEmote;
  final void Function(String) onQuickChat;

  const _ActionBar({
    required this.cardCount,
    required this.canCallUno,
    required this.hasCalledUno,
    required this.onCallUno,
    required this.onEmote,
    required this.onQuickChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimens.lg,
        AppDimens.sm,
        AppDimens.lg,
        MediaQuery.paddingOf(context).bottom > 0 ? 0 : AppDimens.sm,
      ),
      child: Row(
        children: [
          // Emote / quick chat.
          AppIconButton(
            icon: Icons.emoji_emotions_outlined,
            background: Colors.black.withValues(alpha: 0.3),
            tooltip: 'Emotes',
            onPressed: () => _showEmoteSheet(context),
          ),
          const SizedBox(width: AppDimens.md),

          // Card counter.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.md,
              vertical: AppDimens.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: AppDimens.brPill,
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.style_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 5),
                Text(
                  '$cardCount',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // UNO button.
          _UnoButton(
            enabled: canCallUno,
            called: hasCalledUno,
            onPressed: onCallUno,
          ),
        ],
      ),
    );
  }

  void _showEmoteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmoteSheet(
        onEmote: (k) {
          onEmote(k);
          Navigator.pop(context);
        },
        onQuickChat: (k) {
          onQuickChat(k);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _UnoButton extends StatelessWidget {
  final bool enabled;
  final bool called;
  final VoidCallback onPressed;

  const _UnoButton({
    required this.enabled,
    required this.called,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.xxl,
          vertical: AppDimens.md,
        ),
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.dangerGradient : null,
          color: enabled ? null : Colors.black.withValues(alpha: 0.3),
          borderRadius: AppDimens.brPill,
          border: Border.all(
            color: enabled
                ? Colors.white
                : Colors.white.withValues(alpha: 0.12),
            width: enabled ? 2 : 1,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.danger.withValues(alpha: 0.55),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Text(
          called ? 'CALLED' : 'NUNO!',
          style: AppTextStyles.button.copyWith(
            color: enabled ? Colors.white : AppColors.textMuted,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _EmoteSheet extends StatelessWidget {
  final void Function(String) onEmote;
  final void Function(String) onQuickChat;

  const _EmoteSheet({required this.onEmote, required this.onQuickChat});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundAlt,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXxl)),
        border: Border(top: BorderSide(color: AppColors.surfaceStroke)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppDimens.xl,
        AppDimens.xl,
        AppDimens.xl,
        MediaQuery.paddingOf(context).bottom + AppDimens.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EMOTES', style: AppTextStyles.label),
          const SizedBox(height: AppDimens.md),
          Wrap(
            spacing: AppDimens.md,
            runSpacing: AppDimens.md,
            children: [
              for (final entry in EmotesCatalog.entries)
                GestureDetector(
                  onTap: () => onEmote(entry.key),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppDimens.brMd,
                      border: Border.all(color: AppColors.surfaceStroke),
                    ),
                    alignment: Alignment.center,
                    child: Text(entry.value,
                        style: const TextStyle(fontSize: 24)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.xl),
          Text('QUICK CHAT', style: AppTextStyles.label),
          const SizedBox(height: AppDimens.md),
          Wrap(
            spacing: AppDimens.sm,
            runSpacing: AppDimens.sm,
            children: [
              for (final entry in QuickChatCatalog.entries)
                GestureDetector(
                  onTap: () => onQuickChat(entry.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.lg,
                      vertical: AppDimens.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppDimens.brPill,
                      border: Border.all(color: AppColors.surfaceStroke),
                    ),
                    child: Text(entry.value, style: AppTextStyles.body),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Re-exported catalogues so the sheet stays declarative.
class EmotesCatalog {
  static Iterable<MapEntry<String, String>> get entries =>
      const {
        'laugh': '😂',
        'angry': '😠',
        'cool': '😎',
        'cry': '😭',
        'love': '😍',
        'shock': '😱',
        'think': '🤔',
        'clap': '👏',
        'fire': '🔥',
        'skull': '💀',
        'crown': '👑',
        'dab': '🕺',
      }.entries;
}

class QuickChatCatalog {
  static Iterable<MapEntry<String, String>> get entries =>
      const {
        'NICE_MOVE': 'Nice move!',
        'GOOD_GAME': 'Good game!',
        'HURRY_UP': 'Hurry up!',
        'OOPS': 'Oops...',
        'WELL_PLAYED': 'Well played!',
        'THANKS': 'Thanks!',
        'SORRY': 'Sorry!',
        'LETS_GO': "Let's go!",
      }.entries;
}
