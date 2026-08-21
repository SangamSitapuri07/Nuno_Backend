import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../lobby/lobby_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/social_models.dart';
import '../../../services/socket_events.dart';
import '../../friends/widgets/direct_message_sheet.dart';
import '../home_providers.dart';

/// Friends panel docked to the right of the home screen, split into
/// ONLINE and OFFLINE groups, backed by GET /api/v1/friends.
class FriendsPanel extends ConsumerStatefulWidget {
  const FriendsPanel({super.key});

  @override
  ConsumerState<FriendsPanel> createState() => _FriendsPanelState();
}

class _FriendsPanelState extends ConsumerState<FriendsPanel> {
  bool _offlineExpanded = false;

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider).valueOrNull ?? const <Friend>[];
    final online = friends.where((f) => f.status.isOnline).toList();
    final offline = friends.where((f) => !f.status.isOnline).toList();
    final requests = ref.watch(friendRequestsProvider).valueOrNull ?? const [];

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xE62A1A5E), Color(0xF21A0F3D)],
        ),
        borderRadius: AppDimens.brXl,
        border: Border.all(
          color: AppColors.violet.withValues(alpha: 0.45),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.md,
              AppDimens.sm,
              AppDimens.sm,
              AppDimens.xs,
            ),
            child: Row(
              children: [
                const Icon(Icons.people_alt_rounded,
                    size: 18, color: AppColors.cyan),
                const SizedBox(width: AppDimens.sm),
                Text(
                  'FRIENDS',
                  style: AppTextStyles.h4.copyWith(
                    fontSize: 14,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                _HeaderIcon(
                  icon: Icons.person_add_alt_1_rounded,
                  badge: requests.length,
                  onTap: () => context.push(AppRoutes.friends),
                ),
                const SizedBox(width: AppDimens.sm),
                _HeaderIcon(
                  icon: Icons.search_rounded,
                  onTap: () => context.push(AppRoutes.friends),
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.sm,
                0,
                AppDimens.sm,
                AppDimens.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GroupLabel(
                    label: 'ONLINE (${online.length})',
                    dotColor: AppColors.green,
                  ),
                  if (online.isEmpty)
                    _EmptyHint(
                      text: friends.isEmpty
                          ? 'Add friends to play together'
                          : 'No friends online',
                    )
                  else
                    for (final f in online) _FriendRow(friend: f),

                  const SizedBox(height: AppDimens.sm),

                  GestureDetector(
                    onTap: () =>
                        setState(() => _offlineExpanded = !_offlineExpanded),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Expanded(
                          child: _GroupLabel(
                            label: 'OFFLINE (${offline.length})',
                            dotColor: AppColors.textMuted,
                          ),
                        ),
                        Icon(
                          _offlineExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                  if (_offlineExpanded)
                    for (final f in offline) _FriendRow(friend: f),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  const _HeaderIcon({required this.icon, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 19, color: Colors.white70),
          if (badge > 0)
            Positioned(
              right: -5,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 14),
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badge',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String label;
  final Color dotColor;

  const _GroupLabel({required this.label, required this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.xs,
        vertical: AppDimens.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppDimens.sm),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: dotColor == AppColors.green
                  ? AppColors.green
                  : AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.sm,
        vertical: AppDimens.sm,
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(fontSize: 11),
      ),
    );
  }
}

class _FriendRow extends ConsumerWidget {
  final Friend friend;

  const _FriendRow({required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = friend.status.isOnline;

    // Unread DMs from this friend.
    final unread =
        ref.watch(unreadCountsProvider).valueOrNull?[friend.userId] ?? 0;

    return GestureDetector(
      // Tapping the row opens the actions, chat included.
      //
      // Messaging used to be reachable only by leaving home, opening the
      // Friends tab, finding the person again and opening a sheet from
      // there. The panel already lists everyone; this makes it the place you
      // actually act on them.
      onTap: () => _showActions(context, ref),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.sm,
          vertical: AppDimens.sm,
        ),
        decoration: BoxDecoration(
          color: const Color(0x662A1A5E),
          borderRadius: AppDimens.brMd,
          border: Border.all(color: AppColors.violet.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                PlayerAvatar(
                  username: friend.username,
                  avatarUrl: friend.avatarUrl,
                  size: 34,
                  status: friend.status,
                ),
                if (unread > 0)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 15),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: AppDimens.brPill,
                        border: Border.all(
                          color: const Color(0xFF1A0F3D),
                          width: 1.4,
                        ),
                      ),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    friend.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    friend.status.label,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      color: AppColors.forStatus(friend.status.wire),
                    ),
                  ),
                ],
              ),
            ),
            // Green action: join their room, or open one and invite them.
            GestureDetector(
              onTap: () {
                if (friend.isJoinable) {
                  ref.read(socketServiceProvider).emit(
                    SocketEvents.inviteAccept,
                    {'roomCode': friend.roomCode},
                  );
                  context.push(AppRoutes.lobby);
                  return;
                }

                // An offline friend can never receive the invite, so say so
                // instead of opening a room they will never join.
                if (!friend.isInvitable) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${friend.username} is ${friend.status.label.toLowerCase()}',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  return;
                }

                ref
                    .read(lobbyControllerProvider.notifier)
                    .inviteToNewRoom(friend.userId);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Invite sent to ${friend.username}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
                context.push(AppRoutes.lobby);
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (friend.isJoinable || friend.isInvitable)
                      ? AppColors.green
                      : AppColors.surfaceHigh,
                  borderRadius: AppDimens.brSm,
                ),
                child: Icon(
                  friend.isJoinable ? Icons.login_rounded : Icons.add_rounded,
                  size: 18,
                  color: (friend.isJoinable || friend.isInvitable)
                      ? Colors.white
                      : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Actions for one friend, opened by tapping their row.
  ///
  /// The same choices the Friends tab offers, brought to where the player
  /// already is. Chat is first because it is the one that works whatever
  /// their status.
  void _showActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundAlt,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXxl)),
      ),
      builder: (sheetContext) => SafeArea(
        left: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.xl,
            AppDimens.lg,
            AppDimens.xl,
            AppDimens.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  PlayerAvatar(
                    username: friend.username,
                    avatarUrl: friend.avatarUrl,
                    status: friend.status,
                    size: 34,
                  ),
                  const SizedBox(width: AppDimens.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(friend.username, style: AppTextStyles.h4),
                        Text(
                          friend.status.label,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.forStatus(friend.status.wire),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.md),

              // Always available: a message keeps until they next open the
              // app, so an offline friend is still worth writing to.
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.chat_bubble_rounded,
                    color: AppColors.blue),
                title: Text('Send a message', style: AppTextStyles.body),
                subtitle: Text(
                  'Chats clear after a day',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  DirectMessageSheet.show(context, friend: friend);
                },
              ),

              if (friend.isJoinable)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.login_rounded,
                      color: AppColors.green),
                  title: Text('Join their room', style: AppTextStyles.body),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ref.read(socketServiceProvider).emit(
                      SocketEvents.inviteAccept,
                      {'roomCode': friend.roomCode},
                    );
                    context.push(AppRoutes.lobby);
                  },
                )
              else if (friend.isInvitable)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.videogame_asset_rounded,
                      color: AppColors.green),
                  title: Text('Invite to play', style: AppTextStyles.body),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ref
                        .read(lobbyControllerProvider.notifier)
                        .inviteToNewRoom(friend.userId);
                    if (context.mounted) context.push(AppRoutes.lobby);
                  },
                ),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_rounded,
                    color: AppColors.textSecondary),
                title: Text('All friends', style: AppTextStyles.body),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(AppRoutes.friends);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
