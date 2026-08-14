import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/player_avatar.dart';
import '../../data/models/room_models.dart';
import '../auth/auth_controller.dart';
import '../home/home_providers.dart';
import 'lobby_providers.dart';
import 'widgets/lobby_chat.dart';

/// Pre-game room: seats, ready-up, countdown, chat and invites.
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
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: room == null
                ? _ConnectingView(
                    isConnecting: state.isConnecting,
                    error: state.error,
                    onBack: () => context.go(AppRoutes.home),
                  )
                : _LobbyContent(
                    room: room,
                    state: state,
                    myId: myId,
                    controller: controller,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ConnectingView extends StatelessWidget {
  final bool isConnecting;
  final String? error;
  final VoidCallback onBack;

  const _ConnectingView({
    required this.isConnecting,
    this.error,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    if (error != null && !isConnecting) {
      return EmptyState(
        icon: Icons.meeting_room_outlined,
        title: 'Could not join',
        message: error,
        actionLabel: 'Back to home',
        onAction: onBack,
      );
    }
    return const LoadingView(label: 'Setting up the room...');
  }
}

class _LobbyContent extends ConsumerWidget {
  final GameRoom room;
  final LobbyState state;
  final String? myId;
  final LobbyController controller;

  const _LobbyContent({
    required this.room,
    required this.state,
    required this.myId,
    required this.controller,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHost = myId != null && room.isHost(myId!);
    final me = myId == null ? null : room.playerById(myId!);
    final isReady = me?.isReady ?? false;

    return Column(
      children: [
        // ── Header ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.lg,
            AppDimens.sm,
            AppDimens.lg,
            AppDimens.md,
          ),
          child: Row(
            children: [
              AppIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: () {
                  controller.leave();
                  context.go(AppRoutes.home);
                },
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Game lobby', style: AppTextStyles.h3),
                    Text(
                      '${room.players.length}/${room.maxPlayers} players · ${room.gameMode.label}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              AppIconButton(
                icon: Icons.person_add_alt_rounded,
                tooltip: 'Invite friends',
                onPressed: () => _showInviteSheet(context, ref),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.xl,
              0,
              AppDimens.xl,
              AppDimens.xl,
            ),
            children: [
              // ── Room code ─────────────────────────────
              _RoomCodeCard(code: room.roomCode),

              const SizedBox(height: AppDimens.xl),

              // ── Countdown ─────────────────────────────
              if (state.isCountingDown) ...[
                _CountdownBanner(count: state.countdown!),
                const SizedBox(height: AppDimens.xl),
              ],

              // ── Seats ─────────────────────────────────
              SectionHeader(
                title: 'Players',
                actionLabel: '${room.players.length}/${room.maxPlayers}',
              ),
              ...List.generate(room.maxPlayers, (i) {
                final player =
                    i < room.players.length ? room.players[i] : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppDimens.md),
                  child: _PlayerSeat(
                    player: player,
                    isMe: player?.userId == myId,
                    canKick: isHost && player != null && player.userId != myId,
                    onKick: player == null
                        ? null
                        : () => controller.kick(player.userId),
                  ),
                );
              }),

              const SizedBox(height: AppDimens.lg),

              // ── Chat ──────────────────────────────────
              const SectionHeader(title: 'Room chat'),
              LobbyChat(
                messages: state.messages,
                myId: myId,
                onSend: controller.sendChat,
              ),
            ],
          ),
        ),

        // ── Ready bar ───────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(
            AppDimens.xl,
            AppDimens.lg,
            AppDimens.xl,
            MediaQuery.paddingOf(context).bottom + AppDimens.lg,
          ),
          decoration: BoxDecoration(
            color: AppColors.backgroundAlt,
            border: const Border(
              top: BorderSide(color: AppColors.surfaceStroke),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (room.players.length < 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimens.md),
                  child: Text(
                    'Waiting for at least 2 players to start',
                    style: AppTextStyles.caption,
                  ),
                ),
              AppButton(
                label: isReady ? 'NOT READY' : 'READY UP',
                icon: isReady
                    ? Icons.close_rounded
                    : Icons.check_circle_outline_rounded,
                variant: isReady
                    ? AppButtonVariant.ghost
                    : AppButtonVariant.accent,
                onPressed: () => controller.setReady(!isReady),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showInviteSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _InviteFriendsSheet(
        onInvite: controller.invite,
        alreadyIn: room.players.map((p) => p.userId).toSet(),
      ),
    );
  }
}

// ── Room code card ────────────────────────────────────────────

class _RoomCodeCard extends StatelessWidget {
  final String code;

  const _RoomCodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primary.withValues(alpha: 0.22),
          AppColors.surface,
        ],
      ),
      borderColor: AppColors.primary.withValues(alpha: 0.4),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ROOM CODE', style: AppTextStyles.label),
              const SizedBox(height: AppDimens.xs),
              Text(
                code,
                style: AppTextStyles.h1.copyWith(letterSpacing: 6),
              ),
            ],
          ),
          const Spacer(),
          AppIconButton(
            icon: Icons.copy_rounded,
            tooltip: 'Copy code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              AppSnack.show(context, 'Room code copied');
            },
          ),
        ],
      ),
    );
  }
}

// ── Countdown ─────────────────────────────────────────────────

class _CountdownBanner extends StatelessWidget {
  final int count;

  const _CountdownBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      gradient: AppColors.accentGradient,
      borderColor: Colors.white.withValues(alpha: 0.2),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey(count),
            tween: Tween(begin: 1.4, end: 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xFF00201C),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$count',
                style: AppTextStyles.numeric.copyWith(
                  color: AppColors.accent,
                  fontSize: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.lg),
          Expanded(
            child: Text(
              'Game starting...',
              style: AppTextStyles.h3.copyWith(color: const Color(0xFF00201C)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Player seat ───────────────────────────────────────────────

class _PlayerSeat extends StatelessWidget {
  final RoomPlayer? player;
  final bool isMe;
  final bool canKick;
  final VoidCallback? onKick;

  const _PlayerSeat({
    this.player,
    this.isMe = false,
    this.canKick = false,
    this.onKick,
  });

  @override
  Widget build(BuildContext context) {
    if (player == null) {
      return DottedEmptySeat();
    }

    final p = player!;
    return AppPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.md,
      ),
      borderColor: p.isReady
          ? AppColors.success.withValues(alpha: 0.5)
          : AppColors.surfaceStroke,
      color: p.isReady
          ? AppColors.success.withValues(alpha: 0.07)
          : AppColors.surface,
      child: Row(
        children: [
          PlayerAvatar(
            username: p.username,
            avatarUrl: p.avatarUrl,
            size: AppDimens.avatarMd,
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.username,
                        style: AppTextStyles.h4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: AppDimens.sm),
                      const AppChip(label: 'YOU', color: AppColors.info),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (p.isHost) ...[
                      const Icon(Icons.star_rounded,
                          size: 13, color: AppColors.gold),
                      const SizedBox(width: 3),
                      Text('Host', style: AppTextStyles.caption),
                      const SizedBox(width: AppDimens.sm),
                    ],
                    if (p.isVoiceConnected) ...[
                      const Icon(Icons.mic_rounded,
                          size: 13, color: AppColors.accent),
                      const SizedBox(width: AppDimens.sm),
                    ],
                    if (p.ping > 0)
                      Text('${p.ping} ms', style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
          ),
          if (canKick)
            AppIconButton(
              icon: Icons.person_remove_alt_1_rounded,
              size: 36,
              foreground: AppColors.danger,
              tooltip: 'Kick player',
              onPressed: onKick,
            )
          else
            AppChip(
              label: p.isReady ? 'READY' : 'WAITING',
              color: p.isReady ? AppColors.success : AppColors.textMuted,
              filled: p.isReady,
            ),
        ],
      ),
    );
  }
}

class DottedEmptySeat extends StatelessWidget {
  const DottedEmptySeat({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.35),
        borderRadius: AppDimens.brLg,
        border: Border.all(
          color: AppColors.surfaceStroke,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppDimens.md),
          Container(
            width: AppDimens.avatarMd,
            height: AppDimens.avatarMd,
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surfaceStroke),
            ),
            child: const Icon(Icons.person_outline_rounded,
                size: 20, color: AppColors.textMuted),
          ),
          const SizedBox(width: AppDimens.md),
          Text(
            'Waiting for player...',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Invite sheet ──────────────────────────────────────────────

class _InviteFriendsSheet extends ConsumerWidget {
  final void Function(String userId) onInvite;
  final Set<String> alreadyIn;

  const _InviteFriendsSheet({required this.onInvite, required this.alreadyIn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(onlineFriendsProvider)
        .where((f) => !alreadyIn.contains(f.userId))
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundAlt,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXxl)),
        border: Border(top: BorderSide(color: AppColors.surfaceStroke)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppDimens.xxl,
        AppDimens.lg,
        AppDimens.xxl,
        AppDimens.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceStroke,
                borderRadius: AppDimens.brPill,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.xl),
          Text('Invite friends', style: AppTextStyles.h2),
          const SizedBox(height: AppDimens.lg),
          if (friends.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.xxl),
              child: Text(
                'No friends are online right now.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: friends.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppDimens.md),
                itemBuilder: (context, i) {
                  final f = friends[i];
                  return Row(
                    children: [
                      PlayerAvatar(
                        username: f.username,
                        avatarUrl: f.avatarUrl,
                        status: f.status,
                      ),
                      const SizedBox(width: AppDimens.md),
                      Expanded(
                        child: Text(f.username, style: AppTextStyles.h4),
                      ),
                      AppButton(
                        label: 'INVITE',
                        size: AppButtonSize.small,
                        expand: false,
                        onPressed: () {
                          onInvite(f.userId);
                          AppSnack.show(
                            context,
                            'Invite sent to ${f.username}',
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
