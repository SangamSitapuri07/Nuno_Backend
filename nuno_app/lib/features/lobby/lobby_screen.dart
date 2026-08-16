import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/game_assets.dart';
import '../../core/widgets/player_avatar.dart';
import '../../core/widgets/titled_panel.dart';
import '../../data/models/enums.dart';
import '../../data/models/game_card.dart';
import '../../data/models/room_models.dart';
import '../../services/socket_service.dart';
import '../auth/auth_controller.dart';
import '../game/widgets/playing_card.dart';
import 'lobby_providers.dart';
import 'widgets/invite_friends_sheet.dart';

/// Screen 5 — Room Lobby. Landscape split: room code + card art on the left,
/// player slots on the right, actions beneath.
class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lobbyControllerProvider);
    final myId = ref.watch(currentUserIdProvider);
    final controller = ref.read(lobbyControllerProvider.notifier);

    ref.listen<LobbyState>(lobbyControllerProvider, (prev, next) {
      if (next.gameStarted && !(prev?.gameStarted ?? false)) {
        context.pushReplacement(AppRoutes.game);
      }
      if (next.wasKicked && !(prev?.wasKicked ?? false)) {
        AppSnack.error(context, next.error ?? 'You were removed.');
        context.go(AppRoutes.home);
      }
      if (next.error != null && next.error != prev?.error && !next.wasKicked) {
        AppSnack.error(context, next.error!);
      }
    });

    final room = state.room;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        controller.leave();
        controller.clear();
        context.go(AppRoutes.home);
      },
      child: PanelScreen(
        title: 'Room Lobby',
        maxWidth: 860,
        onBack: () {
          controller.leave();
          controller.clear();
          context.go(AppRoutes.home);
        },
        child: room == null
            ? SingleChildScrollView(
                child: state.error != null && !state.isConnecting
                    ? Column(
                        children: [
                          EmptyState(
                            icon: Icons.meeting_room_outlined,
                            title: 'Could not join',
                            message: state.error,
                            // Retrying in place beats sending the user home:
                            // the usual cause is a server still waking up,
                            // and the request is now safe to repeat.
                            actionLabel: 'Try again',
                            onAction: () {
                              controller.reset();
                              controller.retryLast();
                            },
                          ),
                          // The transport log is most useful precisely when
                          // something failed, so keep it on this screen too.
                          _TracePanel(
                            trace:
                                ref.watch(socketTraceProvider).valueOrNull ??
                                    const [],
                          ),
                          const SizedBox(height: AppDimens.lg),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimens.xxxl,
                        ),
                        child: _ConnectingView(
                          state: ref.watch(socketStateProvider).valueOrNull,
                          trace: ref.watch(socketTraceProvider).valueOrNull ??
                              const [],
                        ),
                      ),
              )
            : _LobbyBody(
                room: room,
                state: state,
                myId: myId,
                controller: controller,
              ),
      ),
    );
  }
}

class _LobbyBody extends StatelessWidget {
  final GameRoom room;
  final LobbyState state;
  final String? myId;
  final LobbyController controller;

  const _LobbyBody({
    required this.room,
    required this.state,
    required this.myId,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isHost = myId != null && room.isHost(myId!);
    final isReady = myId == null
        ? false
        : (room.playerById(myId!)?.isReady ?? false);

    // The host is implicitly ready - they are the one pressing START - so
    // only the guests need to have confirmed. This mirrors the server check
    // in room.handler.ts, so the button is never enabled for a request the
    // server would refuse.
    final guestsReady = room.players
        .where((p) => p.userId != room.hostId)
        .every((p) => p.isReady);
    final canStart = room.players.length >= 2 && guestsReady;

    // Scrollable: a short landscape viewport plus the system inset left the
    // action row 134px past the bottom edge on the reporter's device.
    return SingleChildScrollView(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left: code + card art ──────────────────
        SizedBox(
          width: 210,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ROOM CODE', style: AppTextStyles.label),
              const SizedBox(height: AppDimens.xs),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: room.roomCode));
                  HapticFeedback.lightImpact();
                  AppSnack.show(context, 'Room code copied');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.md,
                    vertical: AppDimens.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: AppDimens.brSm,
                    border: Border.all(color: AppColors.surfaceStroke),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        room.roomCode,
                        style: AppTextStyles.h2.copyWith(letterSpacing: 4),
                      ),
                      const SizedBox(width: AppDimens.sm),
                      const Icon(Icons.copy_rounded,
                          size: 14, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.sm),
              const PlayingCardView(
                card: GameCard(
                  cardId: 'preview',
                  color: CardColor.red,
                  value: CardValue.eight,
                ),
                width: 78,
              ),
              const SizedBox(height: AppDimens.sm),
              if (state.isCountingDown)
                Text(
                  'Starting in ${state.countdown}',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),

        // Vertical divider, as in the concept render.
        Container(
          width: 1,
          height: 170,
          margin: const EdgeInsets.symmetric(horizontal: AppDimens.md),
          color: AppColors.surfaceStroke,
        ),

        // ── Right: players + actions ───────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PLAYERS (${room.players.length}/${room.maxPlayers})',
                style: AppTextStyles.label,
              ),
              const SizedBox(height: AppDimens.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 158),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var i = 0; i < room.maxPlayers; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _PlayerRow(
                            player: i < room.players.length
                                ? room.players[i]
                                : null,
                            isMe: i < room.players.length &&
                                room.players[i].userId == myId,
                            canKick: isHost &&
                                i < room.players.length &&
                                room.players[i].userId != myId,
                            onKick: i < room.players.length
                                ? () => controller
                                    .kick(room.players[i].userId)
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.sm),
              // Side by side rather than stacked: two 190px buttons in a
              // column overflowed the panel on a phone in landscape.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: _LobbyAction(
                      label: 'INVITE',
                      color: AppColors.blue,
                      icon: Icons.person_add_alt_1_rounded,
                      onTap: () => InviteFriendsSheet.show(
                        context,
                        onInvite: controller.invite,
                        alreadyIn:
                            room.players.map((p) => p.userId).toSet(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.sm),
                  Expanded(
                    child: isHost
                        // Only the host can start, as in every other lobby
                        // players will have used.
                        ? _LobbyAction(
                            label: state.isCountingDown
                                ? 'STARTING'
                                : 'START',
                            color: AppColors.green,
                            icon: Icons.play_arrow_rounded,
                            enabled: canStart && !state.isCountingDown,
                            onTap: controller.startMatch,
                          )
                        : _LobbyAction(
                            label: isReady ? 'READY' : 'NOT READY',
                            color: isReady
                                ? AppColors.green
                                : AppColors.surfaceHigh,
                            icon: isReady
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            onTap: () => controller.setReady(!isReady),
                          ),
                  ),
                ],
              ),
              if (isHost && !canStart) ...[
                const SizedBox(height: 4),
                Text(
                  room.players.length < 2
                      ? 'Waiting for another player'
                      : 'Waiting for everyone to be ready',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final RoomPlayer? player;
  final bool isMe;
  final bool canKick;
  final VoidCallback? onKick;

  const _PlayerRow({
    this.player,
    this.isMe = false,
    this.canKick = false,
    this.onKick,
  });

  @override
  Widget build(BuildContext context) {
    if (player == null) {
      return Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh.withValues(alpha: 0.4),
          borderRadius: AppDimens.brSm,
          border: Border.all(color: AppColors.surfaceStroke),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_outline_rounded,
                size: 15, color: AppColors.textMuted),
            const SizedBox(width: AppDimens.sm),
            Text(
              'Waiting for player...',
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ],
        ),
      );
    }

    final p = player!;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppDimens.brSm,
        border: Border.all(
          color: p.isReady
              ? AppColors.green.withValues(alpha: 0.6)
              : AppColors.surfaceStroke,
        ),
      ),
      child: Row(
        children: [
          PlayerAvatar(
            username: p.username,
            avatarUrl: p.avatarUrl,
            size: 30,
          ),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Text(
              isMe ? '${p.username} (You)' : p.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          if (p.isHost)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.star_rounded, size: 13, color: AppColors.gold),
            ),
          if (canKick)
            GestureDetector(
              onTap: onKick,
              child: const Icon(Icons.close_rounded,
                  size: 15, color: AppColors.danger),
            )
          else
            Icon(
              p.isReady
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: p.isReady ? AppColors.green : AppColors.textMuted,
            ),
        ],
      ),
    );
  }
}


/// Live transport state, so the lobby spinner can say what it is waiting on
/// instead of showing an identical message for every stage.
/// `onStateChanged` is a broadcast stream, so a listener that subscribes after
/// the socket has already settled receives nothing until the *next* change.
/// The lobby usually opens in exactly that position, which made the spinner
/// report "Connecting to the server..." while the socket was authenticated.
/// Seeding with the current value keeps the label honest.
final socketStateProvider = StreamProvider<SocketConnectionState>((ref) {
  final socket = ref.watch(socketServiceProvider);
  return socket.onStateChanged.startWith(socket.state);
});

/// Live transport trace, seeded with whatever has already been recorded.
final socketTraceProvider = StreamProvider<List<String>>((ref) {
  final socket = ref.watch(socketServiceProvider);
  return socket.onTrace.startWith(socket.trace);
});

extension _StartWith<T> on Stream<T> {
  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}

/// Spinner that names the current stage. A silent spinner is impossible to
/// diagnose from a screenshot, which is exactly how "stuck on Setting up the
/// room..." kept getting reported without a cause.
class _ConnectingView extends StatelessWidget {
  final SocketConnectionState? state;
  final List<String> trace;

  const _ConnectingView({this.state, this.trace = const []});

  @override
  Widget build(BuildContext context) {
    final label = switch (state) {
      SocketConnectionState.disconnected ||
      null =>
        'Connecting to the server...',
      SocketConnectionState.connecting => 'Connecting to the server...',
      SocketConnectionState.connected => 'Signing in...',
      SocketConnectionState.authenticated => 'Setting up the room...',
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LoadingView(label: label),
        if (trace.isNotEmpty) ...[
          const SizedBox(height: AppDimens.lg),
          _TracePanel(trace: trace),
        ],
      ],
    );
  }
}

/// Shows what the transport actually did. A spinner alone gives the player -
/// and anyone debugging a report - nothing to go on.
class _TracePanel extends StatelessWidget {
  final List<String> trace;

  const _TracePanel({required this.trace});

  @override
  Widget build(BuildContext context) {
    if (trace.isEmpty) return const SizedBox.shrink();
    final recent = trace.length > 6 ? trace.sublist(trace.length - 6) : trace;
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDimens.brSm,
        border: Border.all(color: AppColors.surfaceStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in recent)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                line,
                style: AppTextStyles.bodySm.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}


/// Compact lobby action button. Replaces the art buttons here, which were
/// fixed at 190px and could not shrink to fit the panel.
class _LobbyAction extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _LobbyAction({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: color,
        borderRadius: AppDimens.brSm,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
