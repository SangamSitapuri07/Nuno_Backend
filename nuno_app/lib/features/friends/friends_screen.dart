import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/titled_panel.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/player_avatar.dart';
import '../../data/models/enums.dart';
import '../../data/models/social_models.dart';
import '../../services/socket_events.dart';
import '../home/home_providers.dart';

/// Friends list, pending requests and player search.
class FriendsScreen extends ConsumerStatefulWidget {
  /// When embedded in the home shell there is no app bar / back button.
  final bool embedded;

  const FriendsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requestCount =
        ref.watch(friendRequestsProvider).valueOrNull?.length ?? 0;

    final content = SafeArea(
      bottom: false,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.lg,
              AppDimens.sm,
              AppDimens.lg,
              AppDimens.md,
            ),
            child: Row(
              children: [
                if (!widget.embedded) ...[
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: AppDimens.md),
                ],
                Expanded(child: Text('Friends', style: AppTextStyles.h2)),
              ],
            ),
          ),

          // ── Tabs ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppDimens.brMd,
                border: Border.all(color: AppColors.surfaceStroke),
              ),
              padding: const EdgeInsets.all(4),
              child: TabBar(
                controller: _tabs,
                indicator: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: AppDimens.brSm,
                ),
                dividerColor: Colors.transparent,
                labelPadding: EdgeInsets.zero,
                tabs: [
                  const Tab(text: 'Friends', height: 38),
                  Tab(
                    height: 38,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Requests'),
                        if (requestCount > 0) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: AppDimens.brPill,
                            ),
                            child: Text(
                              '$requestCount',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'Search', height: 38),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppDimens.lg),

          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _FriendsTab(),
                _RequestsTab(),
                _SearchTab(),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return content;

    return PanelScreen(
      title: 'Friends',
      onBack: () => context.pop(),
      maxWidth: 640,
      padding: EdgeInsets.zero,
      child: SizedBox(height: 262, child: content),
    );
  }
}

// ── Friends tab ───────────────────────────────────────────────

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider);

    return friends.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
        itemCount: 6,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: AppDimens.md),
          child: SkeletonListTile(),
        ),
      ),
      error: (e, _) => ErrorStateView(
        message: e.toString(),
        onRetry: () => ref.read(friendsProvider.notifier).refresh(),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.group_outlined,
            title: 'No friends yet',
            message: 'Search for players and send them a request.',
          );
        }

        // Online first.
        final sorted = [...list]..sort((a, b) {
            if (a.status.isOnline != b.status.isOnline) {
              return a.status.isOnline ? -1 : 1;
            }
            return a.username.compareTo(b.username);
          });

        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () => ref.read(friendsProvider.notifier).refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.xl,
              0,
              AppDimens.xl,
              AppDimens.bottomNavHeight,
            ),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppDimens.md),
            itemBuilder: (context, i) => _FriendTile(friend: sorted[i]),
          ),
        );
      },
    );
  }
}

class _FriendTile extends ConsumerWidget {
  final Friend friend;

  const _FriendTile({required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPanel(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Row(
        children: [
          PlayerAvatar(
            username: friend.username,
            avatarUrl: friend.avatarUrl,
            status: friend.status,
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.username,
                  style: AppTextStyles.h4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  friend.status.isOnline
                      ? friend.status.label
                      : Formatters.lastSeen(friend.lastOnline),
                  style: AppTextStyles.caption.copyWith(
                    color: friend.status.isOnline
                        ? AppColors.forStatus(friend.status.wire)
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (friend.isJoinable)
            AppButton(
              label: 'JOIN',
              size: AppButtonSize.small,
              variant: AppButtonVariant.accent,
              expand: false,
              onPressed: () {
                ref.read(socketServiceProvider).emit(
                  SocketEvents.inviteAccept,
                  {'roomCode': friend.roomCode},
                );
                context.push(AppRoutes.lobby);
              },
            )
          else
            AppIconButton(
              icon: Icons.more_horiz_rounded,
              size: 38,
              onPressed: () => _showActions(context, ref),
            ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
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
          MediaQuery.paddingOf(sheetContext).bottom + AppDimens.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(friend.username, style: AppTextStyles.h3),
            const SizedBox(height: AppDimens.xl),
            ListTile(
              leading: const Icon(Icons.person_remove_rounded,
                  color: AppColors.danger),
              title: Text(
                'Remove friend',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.danger),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                await ref
                    .read(friendsProvider.notifier)
                    .remove(friend.userId);
                if (context.mounted) {
                  AppSnack.show(context, 'Removed ${friend.username}');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded,
                  color: AppColors.warning),
              title: Text('Block player', style: AppTextStyles.body),
              onTap: () async {
                Navigator.pop(sheetContext);
                await ref
                    .read(socialRepositoryProvider)
                    .blockPlayer(friend.userId);
                if (context.mounted) {
                  AppSnack.show(context, 'Blocked ${friend.username}');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Requests tab ──────────────────────────────────────────────

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(friendRequestsProvider);

    return requests.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
        itemCount: 3,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: AppDimens.md),
          child: SkeletonListTile(),
        ),
      ),
      error: (e, _) => ErrorStateView(
        message: e.toString(),
        onRetry: () => ref.read(friendRequestsProvider.notifier).refresh(),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.mark_email_read_outlined,
            title: 'No pending requests',
            message: 'Friend requests will appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.xl,
            0,
            AppDimens.xl,
            AppDimens.bottomNavHeight,
          ),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppDimens.md),
          itemBuilder: (context, i) {
            final r = list[i];
            return AppPanel(
              padding: const EdgeInsets.all(AppDimens.md),
              child: Row(
                children: [
                  PlayerAvatar(
                    username: r.senderUsername,
                    avatarUrl: r.senderAvatarUrl,
                  ),
                  const SizedBox(width: AppDimens.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.senderUsername,
                            style: AppTextStyles.h4,
                            overflow: TextOverflow.ellipsis),
                        Text(
                          Formatters.relativeTime(r.createdAt),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.check_rounded,
                    size: 38,
                    background: AppColors.success.withValues(alpha: 0.16),
                    foreground: AppColors.success,
                    tooltip: 'Accept',
                    onPressed: () async {
                      await ref
                          .read(friendRequestsProvider.notifier)
                          .accept(r.id);
                      if (context.mounted) {
                        AppSnack.show(context, 'You are now friends!');
                      }
                    },
                  ),
                  const SizedBox(width: AppDimens.sm),
                  AppIconButton(
                    icon: Icons.close_rounded,
                    size: 38,
                    background: AppColors.danger.withValues(alpha: 0.14),
                    foreground: AppColors.danger,
                    tooltip: 'Decline',
                    onPressed: () => ref
                        .read(friendRequestsProvider.notifier)
                        .reject(r.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Search tab ────────────────────────────────────────────────

class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab();

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  final _controller = TextEditingController();
  Timer? _debounce;

  List<PlayerSearchResult> _results = [];
  bool _loading = false;
  final Set<String> _sent = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String query) async {
    try {
      final results =
          await ref.read(socialRepositoryProvider).searchPlayers(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _sendRequest(PlayerSearchResult player) async {
    try {
      await ref.read(socialRepositoryProvider).sendRequest(player.id);
      if (!mounted) return;
      setState(() => _sent.add(player.id));
      AppSnack.show(context, 'Request sent to ${player.username}');
    } catch (e) {
      if (!mounted) return;
      AppSnack.error(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            style: AppTextStyles.body,
            cursorColor: AppColors.accent,
            decoration: InputDecoration(
              hintText: 'Search players by username',
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 20, color: AppColors.textMuted),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(height: AppDimens.lg),
        Expanded(
          child: _loading
              ? const LoadingView()
              : _results.isEmpty
                  ? EmptyState(
                      icon: Icons.person_search_rounded,
                      title: _controller.text.trim().length < 2
                          ? 'Find new opponents'
                          : 'No players found',
                      message: _controller.text.trim().length < 2
                          ? 'Type at least 2 characters to search.'
                          : 'Try a different username.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.xl,
                        0,
                        AppDimens.xl,
                        AppDimens.bottomNavHeight,
                      ),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppDimens.md),
                      itemBuilder: (context, i) {
                        final p = _results[i];
                        final sent = _sent.contains(p.id);
                        return AppPanel(
                          padding: const EdgeInsets.all(AppDimens.md),
                          child: Row(
                            children: [
                              PlayerAvatar(
                                username: p.username,
                                avatarUrl: p.avatarUrl,
                              ),
                              const SizedBox(width: AppDimens.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(p.username,
                                        style: AppTextStyles.h4,
                                        overflow: TextOverflow.ellipsis),
                                    Text('${p.rankPoints} RP',
                                        style: AppTextStyles.caption),
                                  ],
                                ),
                              ),
                              AppButton(
                                label: sent ? 'SENT' : 'ADD',
                                size: AppButtonSize.small,
                                expand: false,
                                variant: sent
                                    ? AppButtonVariant.ghost
                                    : AppButtonVariant.primary,
                                onPressed:
                                    sent ? null : () => _sendRequest(p),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
