import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/social_models.dart';
import '../../../services/socket_events.dart';
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
      width: 300,
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: const Color(0xE60C0E28),
        borderRadius: AppDimens.brXl,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.lg,
              AppDimens.md,
              AppDimens.md,
              AppDimens.sm,
            ),
            child: Row(
              children: [
                const Icon(Icons.people_alt_rounded,
                    size: 18, color: AppColors.cyan),
                const SizedBox(width: AppDimens.sm),
                Text(
                  'FRIENDS',
                  style: AppTextStyles.h4.copyWith(
                    fontSize: 16,
                    letterSpacing: 0.8,
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
                AppDimens.md,
                0,
                AppDimens.md,
                AppDimens.md,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.sm,
        vertical: AppDimens.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0x8016193C),
        borderRadius: AppDimens.brMd,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          PlayerAvatar(
            username: friend.username,
            avatarUrl: friend.avatarUrl,
            size: 34,
            status: friend.status,
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
          // Green action: join their room, or invite them to play.
          GestureDetector(
            onTap: () {
              if (friend.isJoinable) {
                ref.read(socketServiceProvider).emit(
                  SocketEvents.inviteAccept,
                  {'roomCode': friend.roomCode},
                );
                context.push(AppRoutes.lobby);
              } else {
                context.push(AppRoutes.friends);
              }
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: online ? AppColors.green : AppColors.surfaceHigh,
                borderRadius: AppDimens.brSm,
              ),
              child: Icon(
                friend.isJoinable ? Icons.login_rounded : Icons.add_rounded,
                size: 18,
                color: online ? Colors.white : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
