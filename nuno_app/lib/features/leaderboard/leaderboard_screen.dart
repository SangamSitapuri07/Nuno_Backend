import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/player_avatar.dart';
import '../../data/models/social_models.dart';
import '../../data/models/user_models.dart';
import '../auth/auth_controller.dart';
import '../home/home_providers.dart';

final globalLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>(
    (ref) => ref.watch(leaderboardRepositoryProvider).getGlobal());

final friendsLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>(
    (ref) => ref.watch(leaderboardRepositoryProvider).getFriends());

/// Global / friends rankings with a podium for the top three.
class LeaderboardScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const LeaderboardScreen({super.key, this.embedded = false});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myRank = ref.watch(myRankProvider).valueOrNull;

    final content = SafeArea(
      bottom: false,
      child: Column(
        children: [
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
                Expanded(child: Text('Leaderboard', style: AppTextStyles.h2)),
              ],
            ),
          ),

          // ── My rank summary ─────────────────────────
          if (myRank != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
              child: _MyRankCard(rank: myRank),
            ),

          const SizedBox(height: AppDimens.lg),

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
                indicator: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: AppDimens.brSm,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Global', height: 38),
                  Tab(text: 'Friends', height: 38),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppDimens.lg),

          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _LeaderboardList(provider: globalLeaderboardProvider),
                _LeaderboardList(
                  provider: friendsLeaderboardProvider,
                  emptyTitle: 'No ranked friends',
                  emptyMessage: 'Add friends to compare your ratings.',
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return content;
    return Scaffold(body: AppBackground(child: content));
  }
}

class _MyRankCard extends ConsumerWidget {
  final PlayerRank rank;

  const _MyRankCard({required this.rank});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final tierColor = AppColors.forTier(rank.tier.wire);

    return AppPanel(
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          tierColor.withValues(alpha: 0.20),
          AppColors.surface,
        ],
      ),
      borderColor: tierColor.withValues(alpha: 0.45),
      child: Row(
        children: [
          Column(
            children: [
              Text('#${rank.globalRank ?? '-'}',
                  style: AppTextStyles.h2.copyWith(color: tierColor)),
              Text('RANK', style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(width: AppDimens.lg),
          Container(width: 1, height: 38, color: AppColors.surfaceStroke),
          const SizedBox(width: AppDimens.lg),
          PlayerAvatar(
            username: profile?.username ?? 'P',
            avatarUrl: profile?.avatarUrl,
            size: 40,
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.username ?? 'You',
                  style: AppTextStyles.h4,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${rank.tier.label} ${rank.division} · ${rank.rating}',
                  style: AppTextStyles.caption.copyWith(color: tierColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardList extends ConsumerWidget {
  final FutureProvider<List<LeaderboardEntry>> provider;
  final String emptyTitle;
  final String emptyMessage;

  const _LeaderboardList({
    required this.provider,
    this.emptyTitle = 'No rankings yet',
    this.emptyMessage = 'Play ranked matches to appear here.',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    final myId = ref.watch(currentUserIdProvider);

    return async.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
        itemCount: 8,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: AppDimens.md),
          child: SkeletonListTile(),
        ),
      ),
      error: (e, _) => ErrorStateView(
        message: e.toString(),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return EmptyState(
            icon: Icons.leaderboard_outlined,
            title: emptyTitle,
            message: emptyMessage,
          );
        }

        final podium = entries.take(3).toList();
        final rest = entries.length > 3 ? entries.sublist(3) : <LeaderboardEntry>[];

        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async => ref.invalidate(provider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.xl,
              0,
              AppDimens.xl,
              AppDimens.bottomNavHeight + AppDimens.xl,
            ),
            children: [
              if (podium.length >= 3) ...[
                _Podium(entries: podium),
                const SizedBox(height: AppDimens.xl),
              ],
              for (final entry in (podium.length >= 3 ? rest : entries))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimens.md),
                  child: _LeaderboardRow(
                    entry: entry,
                    isMe: entry.userId == myId,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Top-three podium: 2nd, 1st (taller, centre), 3rd.
class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> entries;

  const _Podium({required this.entries});

  @override
  Widget build(BuildContext context) {
    final first = entries[0];
    final second = entries[1];
    final third = entries[2];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _PodiumPillar(entry: second, place: 2, height: 78)),
        const SizedBox(width: AppDimens.sm),
        Expanded(child: _PodiumPillar(entry: first, place: 1, height: 104)),
        const SizedBox(width: AppDimens.sm),
        Expanded(child: _PodiumPillar(entry: third, place: 3, height: 62)),
      ],
    );
  }
}

class _PodiumPillar extends StatelessWidget {
  final LeaderboardEntry entry;
  final int place;
  final double height;

  const _PodiumPillar({
    required this.entry,
    required this.place,
    required this.height,
  });

  Color get _color => switch (place) {
        1 => AppColors.gold,
        2 => AppColors.tierSilver,
        _ => AppColors.tierBronze,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (place == 1)
          const Icon(Icons.workspace_premium_rounded,
              color: AppColors.gold, size: 22),
        PlayerAvatar(
          username: entry.username,
          avatarUrl: entry.avatarUrl,
          size: place == 1 ? 60 : 48,
          ringColor: _color,
        ),
        const SizedBox(height: AppDimens.sm),
        Text(
          entry.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          '${entry.rating}',
          style: AppTextStyles.caption.copyWith(color: _color),
        ),
        const SizedBox(height: AppDimens.sm),
        Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _color.withValues(alpha: 0.35),
                _color.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimens.radiusMd),
            ),
            border: Border.all(color: _color.withValues(alpha: 0.4)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: AppDimens.sm),
          child: Text(
            '$place',
            style: AppTextStyles.h2.copyWith(color: _color),
          ),
        ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;

  const _LeaderboardRow({required this.entry, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    final tierColor = AppColors.forTier(entry.tier.wire);

    return AppPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.md,
      ),
      color: isMe ? AppColors.primary.withValues(alpha: 0.12) : null,
      borderColor: isMe ? AppColors.primary.withValues(alpha: 0.5) : null,
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${entry.rank}',
              textAlign: TextAlign.center,
              style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppDimens.sm),
          PlayerAvatar(
            username: entry.username,
            avatarUrl: entry.avatarUrl,
            size: 38,
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
                        entry.username,
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
                Text(
                  '${entry.tier.label} ${entry.division} · ${entry.wins} wins',
                  style: AppTextStyles.caption.copyWith(color: tierColor),
                ),
              ],
            ),
          ),
          Text(
            '${entry.rating}',
            style: AppTextStyles.numeric.copyWith(
              fontSize: 16,
              color: tierColor,
            ),
          ),
        ],
      ),
    );
  }
}
