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
            ? SizedBox(
                height: 180,
                child: state.error != null && !state.isConnecting
                    ? EmptyState(
                        icon: Icons.meeting_room_outlined,
                        title: 'Could not join',
                        message: state.error,
                        // Retrying in place beats sending the user home: the
                        // usual cause is a server still waking up, and the
                        // create/join request is now safe to repeat.
                        actionLabel: 'Try again',
                        onAction: () {
                          controller.reset();
                          controller.retryLast();
                        },
                      )
                    : _ConnectingView(
                        state: ref.watch(socketStateProvider).valueOrNull,
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left: code + card art ──────────────────
        SizedBox(
          width: 260,
          child: Column(
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
                        style: AppTextStyles.h1.copyWith(letterSpacing: 6),
                      ),
                      const SizedBox(width: AppDimens.sm),
                      const Icon(Icons.copy_rounded,
                          size: 14, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.lg),
              const PlayingCardView(
                card: GameCard(
                  cardId: 'preview',
                  color: CardColor.red,
                  value: CardValue.eight,
                ),
                width: 104,
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
          height: 200,
          margin: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
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
                constraints: const BoxConstraints(maxHeight: 220),
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
              const SizedBox(height: AppDimens.md),
              Center(
                child: Column(
                  children: [
                    ArtButton(
                      asset: Art.btnInvite,
                      fallbackLabel: 'INVITE',
                      width: 190,
                      onTap: () => InviteFriendsSheet.show(
                        context,
                        onInvite: controller.invite,
                        alreadyIn:
                            room.players.map((p) => p.userId).toSet(),
                      ),
                    ),
                    const SizedBox(height: AppDimens.xs),
                    ArtButton(
                      asset: isHost ? Art.btnStart : Art.btnReady,
                      fallbackLabel: isHost ? 'START' : 'READY',
                      width: 190,
                      onTap: () => controller.setReady(!isReady),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
final socketStateProvider = StreamProvider<SocketConnectionState>((ref) {
  final socket = ref.watch(socketServiceProvider);
  return socket.onStateChanged;
});

/// Spinner that names the current stage. A silent spinner is impossible to
/// diagnose from a screenshot, which is exactly how "stuck on Setting up the
/// room..." kept getting reported without a cause.
class _ConnectingView extends StatelessWidget {
  final SocketConnectionState? state;

  const _ConnectingView({this.state});

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
    return LoadingView(label: label);
  }
}
