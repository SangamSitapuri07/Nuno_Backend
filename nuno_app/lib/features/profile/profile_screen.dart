import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../store/cosmetics_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/currency_pill.dart';
import '../../core/widgets/game_assets.dart';
import '../../core/widgets/player_avatar.dart';
import '../../core/widgets/side_nav.dart';
import '../../core/widgets/titled_panel.dart';
import '../../data/models/enums.dart';
import '../../data/models/user_models.dart';
import '../auth/auth_controller.dart';
import '../home/home_providers.dart';

/// Screens 19–21 — Profile with a left sidebar: Profile · Stats ·
/// Achievements · History · Titles.
class ProfileScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const ProfileScreen({super.key, this.embedded = false});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _section = 0;

  static const _items = [
    SideNavItem(Icons.person_rounded, 'Profile'),
    SideNavItem(Icons.bar_chart_rounded, 'Stats'),
    SideNavItem(Icons.military_tech_rounded, 'Achievements'),
    SideNavItem(Icons.history_rounded, 'History'),
  ];

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SideNav(
            items: _items,
            index: _section,
            onChanged: (i) => setState(() => _section = i),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: switch (_section) {
              1 => const _StatsSection(),
              2 => const _AchievementsShortcut(),
              3 => const _HistorySection(),
              _ => const _IdentitySection(),
            },
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.xl,
            AppDimens.sm,
            AppDimens.xl,
            AppDimens.sm,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppDimens.brLg,
              border: Border.all(color: AppColors.surfaceStroke),
            ),
            child: body,
          ),
        ),
      );
    }

    return PanelScreen(
      title: 'Profile',
      onBack: () => context.pop(),
      maxWidth: 640,
      padding: EdgeInsets.zero,
      child: SizedBox(height: 260, child: body),
    );
  }
}

// ── Identity ──────────────────────────────────────────────────

class _IdentitySection extends ConsumerWidget {
  const _IdentitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(currentProfileProvider);
    final rank = ref.watch(myRankProvider).valueOrNull;

    if (p == null) {
      return const SkeletonBox(height: 200, borderRadius: AppDimens.brLg);
    }

    final tierColor = AppColors.forTier(
      rank?.tier.wire ?? p.leaderboard?.tier.wire ?? 'BRONZE',
    );
    final cosmetics = ref.watch(equippedCosmeticsProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlayerAvatar(
                username: p.username,
                avatarUrl: p.avatarUrl,
                size: 56,
                level: p.level,
                ringColor: tierColor,
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(p.username, style: AppTextStyles.h3),
                        ),
                        if (cosmetics.badge != null) ...[
                          const SizedBox(width: 6),
                          ArtImage(cosmetics.badge!, width: 20),
                        ],
                      ],
                    ),
                    if (cosmetics.title != null)
                      Text(
                        cosmetics.title!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    Text('Lv. ${p.level}', style: AppTextStyles.caption),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: AppDimens.brPill,
                      child: LinearProgressIndicator(
                        value: p.levelProgress,
                        minHeight: 5,
                        backgroundColor: AppColors.background,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.green),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.xp} / ${p.nextLevelXp} XP',
                      style: AppTextStyles.caption.copyWith(fontSize: 9),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded,
                    size: 15, color: AppColors.textSecondary),
                onPressed: () => _showEdit(context, ref, p),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.md),

          // Current season / rank
          Container(
            padding: const EdgeInsets.all(AppDimens.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: AppDimens.brSm,
              border: Border.all(color: tierColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                ArtImage(
                  Art.tierShield(
                    rank?.tier.wire ?? p.leaderboard?.tier.wire ?? 'BRONZE',
                  ),
                  height: 44,
                ),
                const SizedBox(width: AppDimens.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CURRENT SEASON', style: AppTextStyles.label),
                      Text(
                        rank?.label ?? p.leaderboard?.label ?? 'Unranked',
                        style: AppTextStyles.h4.copyWith(color: tierColor),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${rank?.rating ?? p.leaderboard?.rating ?? 1000}',
                  style: AppTextStyles.numeric.copyWith(
                    fontSize: 17,
                    color: tierColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimens.md),

          Row(
            children: [
              CurrencyPill(coins: p.coins),
              const Spacer(),
              SizedBox(
                width: 110,
                child: AppButton(
                  label: 'SIGN OUT',
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.ghost,
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) context.go(AppRoutes.login);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEdit(BuildContext context, WidgetRef ref, PlayerProfile p) {
    final controller = TextEditingController(text: p.username);

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(AppDimens.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Edit profile', style: AppTextStyles.h3),
                const SizedBox(height: AppDimens.md),
                AppTextField(
                  controller: controller,
                  label: 'Username',
                  icon: Icons.person_outline_rounded,
                  maxLength: 20,
                  validator: Validators.username,
                ),
                const SizedBox(height: AppDimens.md),
                AppButton(
                  label: 'SAVE',
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.gold,
                  onPressed: () async {
                    final err = Validators.username(controller.text);
                    if (err != null) {
                      AppSnack.error(dialogContext, err);
                      return;
                    }
                    Navigator.pop(dialogContext);
                    try {
                      await ref
                          .read(userRepositoryProvider)
                          .updateProfile(username: controller.text.trim());
                      await ref
                          .read(authControllerProvider.notifier)
                          .refreshProfile();
                      if (context.mounted) {
                        AppSnack.show(context, 'Profile updated');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AppSnack.error(context, e.toString());
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stats (screen 20) ─────────────────────────────────────────

class _StatsSection extends ConsumerWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statisticsProvider);

    return stats.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorStateView(
        message: e.toString(),
        onRetry: () => ref.invalidate(statisticsProvider),
      ),
      data: (s) {
        final rows = <(String, String)>[
          ('Matches Played', '${s.gamesPlayed}'),
          ('Matches Won', '${s.gamesWon}'),
          ('Matches Lost', '${s.gamesLost}'),
          ('Win Rate', s.winRateLabel),
          ('Best Streak', '${s.longestWinStreak}'),
          ('Win Streak', '${s.currentWinStreak}'),
          ('Cards Played', '${s.cardsPlayed}'),
          ('Cards Drawn', '${s.cardsDrawn}'),
        ];

        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    rows[i].$1,
                    style: AppTextStyles.body.copyWith(fontSize: 12),
                  ),
                ),
                Text(
                  rows[i].$2,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AchievementsShortcut extends StatelessWidget {
  const _AchievementsShortcut();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.military_tech_rounded,
              size: 40, color: AppColors.gold),
          const SizedBox(height: AppDimens.sm),
          Text('Achievements', style: AppTextStyles.h4),
          const SizedBox(height: AppDimens.md),
          SizedBox(
            width: 160,
            child: AppButton(
              label: 'VIEW ALL',
              size: AppButtonSize.small,
              variant: AppButtonVariant.blue,
              onPressed: () => context.push(AppRoutes.achievements),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends ConsumerWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(matchHistoryProvider);

    return history.when(
      loading: () => const LoadingView(),
      error: (_, __) =>
          Center(child: Text('Unavailable', style: AppTextStyles.bodySm)),
      data: (matches) {
        if (matches.isEmpty) {
          return const EmptyState(
            icon: Icons.history_rounded,
            title: 'No matches yet',
          );
        }
        return ListView.separated(
          itemCount: matches.length,
          separatorBuilder: (_, __) => const SizedBox(height: 5),
          itemBuilder: (context, i) {
            final m = matches[i];
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.sm,
                vertical: 6,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: AppDimens.brSm,
              ),
              child: Row(
                children: [
                  Icon(
                    m.isWinner
                        ? Icons.emoji_events_rounded
                        : Icons.close_rounded,
                    size: 14,
                    color: m.isWinner ? AppColors.green : AppColors.danger,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${m.isWinner ? 'Win' : 'Loss'} · ${m.gameMode.label}',
                      style: AppTextStyles.body.copyWith(fontSize: 11),
                    ),
                  ),
                  Text(
                    Formatters.relativeTime(m.startedAt),
                    style: AppTextStyles.caption.copyWith(fontSize: 9),
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
