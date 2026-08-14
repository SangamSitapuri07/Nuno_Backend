import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/player_avatar.dart';
import '../../data/models/user_models.dart';
import '../auth/auth_controller.dart';
import '../home/home_providers.dart';

/// Player profile: identity, level, stats and match history.
class ProfileScreen extends ConsumerWidget {
  final bool embedded;

  const ProfileScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final stats = ref.watch(statisticsProvider).valueOrNull;
    final rank = ref.watch(myRankProvider).valueOrNull;

    final content = SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          await ref.read(authControllerProvider.notifier).refreshProfile();
          ref.invalidate(statisticsProvider);
          ref.invalidate(matchHistoryProvider);
          ref.invalidate(myRankProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.xl,
            AppDimens.sm,
            AppDimens.xl,
            AppDimens.bottomNavHeight + AppDimens.xxl,
          ),
          children: [
            // ── Header ──────────────────────────────
            Row(
              children: [
                if (!embedded) ...[
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: AppDimens.md),
                ],
                Expanded(child: Text('Profile', style: AppTextStyles.h2)),
                AppIconButton(
                  icon: Icons.settings_outlined,
                  tooltip: 'Settings',
                  onPressed: () => context.push(AppRoutes.settings),
                ),
              ],
            ),

            const SizedBox(height: AppDimens.xl),

            // ── Identity card ───────────────────────
            _IdentityCard(profile: profile, rank: rank),

            const SizedBox(height: AppDimens.xxl),

            // ── Stats ───────────────────────────────
            const SectionHeader(title: 'Career stats'),
            _StatsPanel(stats: stats),

            const SizedBox(height: AppDimens.xxl),

            // ── History ─────────────────────────────
            const SectionHeader(title: 'Recent matches'),
            const _MatchHistoryList(),

            const SizedBox(height: AppDimens.xxl),

            AppButton(
              label: 'SIGN OUT',
              variant: AppButtonVariant.ghost,
              icon: Icons.logout_rounded,
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text(
                      'You will need to sign in again to play.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancel', style: AppTextStyles.body),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          'Sign out',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await ref.read(authControllerProvider.notifier).logout();
                  if (context.mounted) context.go(AppRoutes.login);
                }
              },
            ),
          ],
        ),
      ),
    );

    if (embedded) return content;
    return Scaffold(body: AppBackground(child: content));
  }
}

class _IdentityCard extends ConsumerWidget {
  final PlayerProfile? profile;
  final PlayerRank? rank;

  const _IdentityCard({this.profile, this.rank});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (profile == null) {
      return const SkeletonBox(height: 210, borderRadius: AppDimens.brLg);
    }

    final p = profile!;
    final tierColor =
        AppColors.forTier(rank?.tier.wire ?? p.leaderboard?.tier.wire ?? 'BRONZE');

    return AppPanel(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          tierColor.withValues(alpha: 0.18),
          AppColors.surface,
        ],
      ),
      borderColor: tierColor.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(AppDimens.xl),
      child: Column(
        children: [
          Stack(
            children: [
              PlayerAvatar(
                username: p.username,
                avatarUrl: p.avatarUrl,
                size: AppDimens.avatarXl,
                level: p.level,
                ringColor: tierColor,
              ),
              Positioned(
                right: -2,
                top: -2,
                child: GestureDetector(
                  onTap: () => _showEditSheet(context, ref, p),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surfaceStroke),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        size: 13, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.lg),

          Text(p.username, style: AppTextStyles.h2),
          const SizedBox(height: 2),
          Text(p.email, style: AppTextStyles.caption),

          const SizedBox(height: AppDimens.lg),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppChip(
                label: rank?.label ?? p.leaderboard?.label ?? 'Unranked',
                color: tierColor,
                icon: Icons.shield_rounded,
              ),
              const SizedBox(width: AppDimens.sm),
              AppChip(
                label: '${Formatters.number(p.coins)} coins',
                color: AppColors.gold,
                icon: Icons.monetization_on_rounded,
              ),
            ],
          ),

          const SizedBox(height: AppDimens.xl),

          // XP bar.
          Row(
            children: [
              Text('LEVEL ${p.level}', style: AppTextStyles.label),
              const Spacer(),
              Text('${p.xp} / ${p.nextLevelXp} XP',
                  style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          ClipRRect(
            borderRadius: AppDimens.brPill,
            child: LinearProgressIndicator(
              value: p.levelProgress,
              minHeight: 8,
              backgroundColor: AppColors.background,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),

          const SizedBox(height: AppDimens.lg),
          Text(
            'Playing since ${Formatters.date(p.createdAt)}',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, PlayerProfile p) {
    final controller = TextEditingController(text: p.username);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.backgroundAlt,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimens.radiusXxl),
            ),
            border: Border(top: BorderSide(color: AppColors.surfaceStroke)),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppDimens.xxl,
            AppDimens.xl,
            AppDimens.xxl,
            AppDimens.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Edit profile', style: AppTextStyles.h2),
              const SizedBox(height: AppDimens.xl),
              AppTextField(
                controller: controller,
                label: 'Username',
                icon: Icons.person_outline_rounded,
                maxLength: 20,
                validator: Validators.username,
              ),
              const SizedBox(height: AppDimens.xl),
              AppButton(
                label: 'SAVE',
                onPressed: () async {
                  final error = Validators.username(controller.text);
                  if (error != null) {
                    AppSnack.error(sheetContext, error);
                    return;
                  }
                  Navigator.pop(sheetContext);
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
    );
  }
}

class _StatsPanel extends StatelessWidget {
  final PlayerStats? stats;

  const _StatsPanel({this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats == null) {
      return const SkeletonBox(height: 150, borderRadius: AppDimens.brLg);
    }

    final s = stats!;
    final entries = <(String, String, IconData, Color)>[
      ('Played', '${s.gamesPlayed}', Icons.sports_esports_rounded, AppColors.info),
      ('Wins', '${s.gamesWon}', Icons.emoji_events_rounded, AppColors.success),
      ('Losses', '${s.gamesLost}', Icons.close_rounded, AppColors.danger),
      ('Win rate', s.winRateLabel, Icons.percent_rounded, AppColors.gold),
      ('Best streak', '${s.longestWinStreak}', Icons.local_fire_department_rounded, AppColors.warning),
      ('Current streak', '${s.currentWinStreak}', Icons.bolt_rounded, AppColors.accent),
      ('Cards played', '${s.cardsPlayed}', Icons.style_rounded, AppColors.rarityEpic),
      ('Cards drawn', '${s.cardsDrawn}', Icons.download_rounded, AppColors.textSecondary),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppDimens.md,
        crossAxisSpacing: AppDimens.md,
        childAspectRatio: 2.5,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final (label, value, icon, color) = entries[i];
        return AppPanel(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md,
            vertical: AppDimens.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value,
                      style: AppTextStyles.h4.copyWith(color: color),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(label, style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MatchHistoryList extends ConsumerWidget {
  const _MatchHistoryList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(matchHistoryProvider);

    return history.when(
      loading: () => Column(
        children: List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: AppDimens.md),
            child: SkeletonListTile(),
          ),
        ),
      ),
      error: (_, __) => AppPanel(
        child: Text('History unavailable', style: AppTextStyles.bodySm),
      ),
      data: (matches) {
        if (matches.isEmpty) {
          return AppPanel(
            child: Row(
              children: [
                const Icon(Icons.history_rounded,
                    size: 20, color: AppColors.textMuted),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: Text(
                    'No matches played yet',
                    style: AppTextStyles.bodySm,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            for (final m in matches.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.md),
                child: AppPanel(
                  padding: const EdgeInsets.all(AppDimens.md),
                  borderColor: m.isWinner
                      ? AppColors.success.withValues(alpha: 0.35)
                      : null,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: (m.isWinner
                                  ? AppColors.success
                                  : AppColors.danger)
                              .withValues(alpha: 0.14),
                          borderRadius: AppDimens.brSm,
                        ),
                        child: Icon(
                          m.isWinner
                              ? Icons.emoji_events_rounded
                              : Icons.close_rounded,
                          size: 20,
                          color: m.isWinner
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                      const SizedBox(width: AppDimens.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.isWinner ? 'Victory' : 'Defeat',
                              style: AppTextStyles.h4.copyWith(
                                color: m.isWinner
                                    ? AppColors.success
                                    : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${m.gameMode.label} · ${m.durationLabel} · ${Formatters.relativeTime(m.startedAt)}',
                              style: AppTextStyles.caption,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${m.ratingChange >= 0 ? '+' : ''}${m.ratingChange}',
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w800,
                              color: m.ratingChange >= 0
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          ),
                          Text('+${m.xpEarned} XP',
                              style: AppTextStyles.caption),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
