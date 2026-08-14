import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/player_avatar.dart';
import '../../data/models/enums.dart';
import '../../data/models/social_models.dart';
import '../../services/socket_events.dart';
import '../auth/auth_controller.dart';
import '../lobby/lobby_providers.dart';
import 'home_providers.dart';
import 'widgets/join_room_sheet.dart';
import 'widgets/notifications_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final rank = ref.watch(myRankProvider).valueOrNull;
    final onlineFriends = ref.watch(onlineFriendsProvider);
    final unread = ref.watch(unreadBadgeProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          await ref.read(authControllerProvider.notifier).refreshProfile();
          await ref.read(friendsProvider.notifier).refresh();
          ref.invalidate(myRankProvider);
          ref.invalidate(statisticsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.xl,
            AppDimens.sm,
            AppDimens.xl,
            AppDimens.bottomNavHeight + AppDimens.xxl,
          ),
          children: [
            // ── Top bar: identity + coins + notifications ──
            _TopBar(unread: unread),

            const SizedBox(height: AppDimens.xl),

            // ── Level / rank card ──────────────────────────
            _PlayerBanner(
              level: profile?.level ?? 1,
              xpProgress: profile?.levelProgress ?? 0,
              xp: profile?.xp ?? 0,
              nextLevelXp: profile?.nextLevelXp ?? 100,
              rankLabel: rank?.label ?? profile?.leaderboard?.label ?? 'Unranked',
              rating: rank?.rating ?? profile?.leaderboard?.rating ?? 1000,
              globalRank: rank?.globalRank,
            ),

            const SizedBox(height: AppDimens.xxl),

            // ── Primary play actions ───────────────────────
            Text('PLAY NOW', style: AppTextStyles.label),
            const SizedBox(height: AppDimens.md),

            _PlayModeCard(
              title: 'Quick Match',
              subtitle: 'Jump into a casual game',
              icon: Icons.bolt_rounded,
              gradient: AppColors.primaryGradient,
              onTap: () => context.push(
                AppRoutes.matchmaking,
                extra: GameMode.casual,
              ),
            ),
            const SizedBox(height: AppDimens.md),

            _PlayModeCard(
              title: 'Ranked Match',
              subtitle: 'Climb the leaderboard',
              icon: Icons.emoji_events_rounded,
              gradient: AppColors.goldGradient,
              foreground: const Color(0xFF3A2600),
              onTap: () => context.push(
                AppRoutes.matchmaking,
                extra: GameMode.ranked,
              ),
            ),

            const SizedBox(height: AppDimens.md),

            // ── Private room row ───────────────────────────
            Row(
              children: [
                Expanded(
                  child: _SmallActionCard(
                    label: 'Create Room',
                    icon: Icons.add_circle_outline_rounded,
                    color: AppColors.accent,
                    onTap: () => _createRoom(context, ref),
                  ),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: _SmallActionCard(
                    label: 'Join Code',
                    icon: Icons.tag_rounded,
                    color: AppColors.info,
                    onTap: () => JoinRoomSheet.show(context),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppDimens.xxl),

            // ── Daily reward ───────────────────────────────
            const _DailyRewardCard(),

            const SizedBox(height: AppDimens.xxl),

            // ── Friends online ─────────────────────────────
            SectionHeader(
              title: 'Friends online',
              actionLabel: 'See all',
              onAction: () => context.push(AppRoutes.friends),
            ),
            _OnlineFriendsStrip(friends: onlineFriends),

            const SizedBox(height: AppDimens.xxl),

            // ── Stats snapshot ─────────────────────────────
            const SectionHeader(title: 'Your stats'),
            const _StatsGrid(),
          ],
        ),
      ),
    );
  }

  void _createRoom(BuildContext context, WidgetRef ref) {
    ref.read(lobbyControllerProvider.notifier).createRoom();
    context.push(AppRoutes.lobby);
  }
}

// ── Top bar ───────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  final int unread;

  const _TopBar({required this.unread});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return Row(
      children: [
        PlayerAvatar(
          username: profile?.username ?? 'P',
          avatarUrl: profile?.avatarUrl,
          size: AppDimens.avatarMd,
          level: profile?.level,
          onTap: () => context.push(AppRoutes.profile),
        ),
        const SizedBox(width: AppDimens.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Welcome back',
                style: AppTextStyles.caption,
              ),
              Text(
                profile?.username ?? 'Player',
                style: AppTextStyles.h3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        _CoinPill(coins: profile?.coins ?? 0),
        const SizedBox(width: AppDimens.sm),
        AppIconButton(
          icon: Icons.notifications_none_rounded,
          badgeCount: unread,
          tooltip: 'Notifications',
          onPressed: () => NotificationsSheet.show(context),
        ),
      ],
    );
  }
}

class _CoinPill extends StatelessWidget {
  final int coins;

  const _CoinPill({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: AppDimens.brPill,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_rounded,
              size: 16, color: AppColors.gold),
          const SizedBox(width: 5),
          Text(
            _format(coins),
            style: AppTextStyles.body.copyWith(
              color: AppColors.gold,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  static String _format(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 10000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}

// ── Player banner ─────────────────────────────────────────────

class _PlayerBanner extends StatelessWidget {
  final int level;
  final double xpProgress;
  final int xp;
  final int nextLevelXp;
  final String rankLabel;
  final int rating;
  final int? globalRank;

  const _PlayerBanner({
    required this.level,
    required this.xpProgress,
    required this.xp,
    required this.nextLevelXp,
    required this.rankLabel,
    required this.rating,
    this.globalRank,
  });

  @override
  Widget build(BuildContext context) {
    final tierColor = AppColors.forTier(rankLabel.split(' ').first);

    return AppPanel(
      padding: const EdgeInsets.all(AppDimens.lg),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.surfaceHigh,
          AppColors.surface,
        ],
      ),
      borderColor: tierColor.withValues(alpha: 0.35),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(color: tierColor.withValues(alpha: 0.6)),
                ),
                child: Icon(Icons.shield_rounded, color: tierColor, size: 24),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rankLabel,
                        style: AppTextStyles.h4.copyWith(color: tierColor)),
                    Text('$rating rating', style: AppTextStyles.bodySm),
                  ],
                ),
              ),
              if (globalRank != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('#$globalRank', style: AppTextStyles.numeric),
                    Text('GLOBAL', style: AppTextStyles.caption),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppDimens.lg),
          Row(
            children: [
              Text('LV $level', style: AppTextStyles.label),
              const Spacer(),
              Text('$xp / $nextLevelXp XP', style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          ClipRRect(
            borderRadius: AppDimens.brPill,
            child: LinearProgressIndicator(
              value: xpProgress,
              minHeight: 8,
              backgroundColor: AppColors.background,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Play mode cards ───────────────────────────────────────────

class _PlayModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final Color foreground;
  final VoidCallback onTap;

  const _PlayModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.foreground = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      onTap: onTap,
      gradient: gradient,
      borderColor: Colors.white.withValues(alpha: 0.16),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.lg,
      ),
      shadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: 0.18),
              borderRadius: AppDimens.brMd,
            ),
            child: Icon(icon, color: foreground, size: 24),
          ),
          const SizedBox(width: AppDimens.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.h3.copyWith(color: foreground)),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySm.copyWith(
                    color: foreground.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: foreground, size: 22),
        ],
      ),
    );
  }
}

class _SmallActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SmallActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.lg,
      ),
      borderColor: color.withValues(alpha: 0.3),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Daily reward ──────────────────────────────────────────────

class _DailyRewardCard extends ConsumerStatefulWidget {
  const _DailyRewardCard();

  @override
  ConsumerState<_DailyRewardCard> createState() => _DailyRewardCardState();
}

class _DailyRewardCardState extends ConsumerState<_DailyRewardCard> {
  bool _busy = false;
  bool _claimed = false;

  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      await ref.read(storeRepositoryProvider).claimDailyReward();
      await ref.read(authControllerProvider.notifier).refreshProfile();
      if (!mounted) return;
      setState(() => _claimed = true);
      AppSnack.show(context, 'Daily reward claimed!',
          icon: Icons.card_giftcard_rounded);
    } catch (e) {
      if (!mounted) return;
      AppSnack.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      borderColor: AppColors.gold.withValues(alpha: 0.35),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              borderRadius: AppDimens.brMd,
            ),
            child: const Icon(Icons.card_giftcard_rounded,
                color: AppColors.gold, size: 22),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily reward', style: AppTextStyles.h4),
                Text(
                  _claimed ? 'Come back tomorrow' : 'Free coins are waiting',
                  style: AppTextStyles.bodySm,
                ),
              ],
            ),
          ),
          AppButton(
            label: _claimed ? 'CLAIMED' : 'CLAIM',
            variant: AppButtonVariant.gold,
            size: AppButtonSize.small,
            expand: false,
            isLoading: _busy,
            onPressed: _claimed ? null : _claim,
          ),
        ],
      ),
    );
  }
}

// ── Online friends strip ──────────────────────────────────────

class _OnlineFriendsStrip extends ConsumerWidget {
  final List<Friend> friends;

  const _OnlineFriendsStrip({required this.friends});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (friends.isEmpty) {
      return AppPanel(
        child: Row(
          children: [
            const Icon(Icons.person_add_alt_rounded,
                color: AppColors.textMuted, size: 20),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Text(
                'No friends online right now',
                style: AppTextStyles.bodySm,
              ),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.friends),
              child: Text(
                'Add friends',
                style: AppTextStyles.body.copyWith(color: AppColors.accent),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: friends.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppDimens.lg),
        itemBuilder: (context, i) {
          final friend = friends[i];
          return SizedBox(
            width: 72,
            child: Column(
              children: [
                PlayerAvatar(
                  username: friend.username,
                  avatarUrl: friend.avatarUrl,
                  size: 54,
                  status: friend.status,
                  onTap: friend.isJoinable
                      ? () {
                          ref.read(socketServiceProvider).emit(
                            SocketEvents.inviteAccept,
                            {'roomCode': friend.roomCode},
                          );
                          context.push(AppRoutes.lobby);
                        }
                      : null,
                ),
                const SizedBox(height: AppDimens.sm),
                Text(
                  friend.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (friend.isJoinable)
                  Text(
                    'JOIN',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                    ),
                  )
                else
                  Text(
                    friend.status.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 9),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Stats grid ────────────────────────────────────────────────

class _StatsGrid extends ConsumerWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statisticsProvider);

    return stats.when(
      loading: () => Row(
        children: const [
          Expanded(child: SkeletonBox(height: 78, borderRadius: AppDimens.brLg)),
          SizedBox(width: AppDimens.md),
          Expanded(child: SkeletonBox(height: 78, borderRadius: AppDimens.brLg)),
          SizedBox(width: AppDimens.md),
          Expanded(child: SkeletonBox(height: 78, borderRadius: AppDimens.brLg)),
        ],
      ),
      error: (_, __) => AppPanel(
        child: Text('Stats unavailable', style: AppTextStyles.bodySm),
      ),
      data: (s) => Row(
        children: [
          Expanded(
            child: _StatTile(
              value: '${s.gamesPlayed}',
              label: 'Played',
              color: AppColors.info,
              icon: Icons.sports_esports_rounded,
            ),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: _StatTile(
              value: '${s.gamesWon}',
              label: 'Wins',
              color: AppColors.success,
              icon: Icons.emoji_events_rounded,
            ),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: _StatTile(
              value: s.winRateLabel,
              label: 'Win rate',
              color: AppColors.gold,
              icon: Icons.trending_up_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData icon;

  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.sm,
        vertical: AppDimens.md,
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: AppDimens.sm),
          FittedBox(
            child: Text(
              value,
              style: AppTextStyles.numeric.copyWith(color: color),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
