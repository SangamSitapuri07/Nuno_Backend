import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../data/models/enums.dart';
import '../../home/home_providers.dart';

/// Screen 16 — Invite Friends. Shown as a dialog over the lobby.
class InviteFriendsSheet extends ConsumerWidget {
  final void Function(String userId) onInvite;
  final Set<String> alreadyIn;

  const InviteFriendsSheet({
    super.key,
    required this.onInvite,
    required this.alreadyIn,
  });

  static Future<void> show(
    BuildContext context, {
    required void Function(String userId) onInvite,
    required Set<String> alreadyIn,
  }) =>
      showDialog(
        context: context,
        builder: (_) => InviteFriendsSheet(
          onInvite: onInvite,
          alreadyIn: alreadyIn,
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider).valueOrNull ?? const [];
    final invitable =
        friends.where((f) => !alreadyIn.contains(f.userId)).toList();

    return Dialog(
      insetPadding: const EdgeInsets.all(AppDimens.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 320),
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
              child: Text('INVITE FRIENDS', style: AppTextStyles.panelTitle),
            ),
            Flexible(
              child: invitable.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(AppDimens.xxl),
                      child: EmptyState(
                        icon: Icons.person_add_alt_rounded,
                        title: 'No friends to invite',
                        message: 'Add friends to play together.',
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(AppDimens.md),
                      itemCount: invitable.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final f = invitable[i];
                        final inMatch =
                            f.status == PlayerOnlineStatus.inMatch;
                        return Row(
                          children: [
                            PlayerAvatar(
                              username: f.username,
                              avatarUrl: f.avatarUrl,
                              size: 28,
                              status: f.status,
                            ),
                            const SizedBox(width: AppDimens.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    f.username,
                                    style: AppTextStyles.body
                                        .copyWith(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    f.status.label,
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 9,
                                      color: AppColors.forStatus(
                                          f.status.wire),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _InviteButton(
                              label: inMatch ? 'IN GAME' : 'INVITE',
                              enabled: !inMatch,
                              onTap: () {
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
      ),
    );
  }
}

class _InviteButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _InviteButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: enabled ? AppColors.blue : AppColors.surfaceHigh,
          borderRadius: AppDimens.brSm,
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: enabled ? Colors.white : AppColors.textMuted,
            fontWeight: FontWeight.w800,
            fontSize: 9,
          ),
        ),
      ),
    );
  }
}
