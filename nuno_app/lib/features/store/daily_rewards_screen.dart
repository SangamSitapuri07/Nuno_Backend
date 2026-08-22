import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/account_sync.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/game_assets.dart';
import '../../core/widgets/titled_panel.dart';
import '../../data/models/store_models.dart';
import '../auth/auth_controller.dart';

/// The seven-day login track, driven entirely by the server.
///
/// Everything here used to be fabricated in the app: a hard-coded reward
/// table, a constant "today is day 2", and a claim button that reported
/// success whatever the server did with it. `GET /rewards/daily` now returns
/// the real track, the real streak, and whether today has already been
/// claimed, so what is drawn is what will actually be paid.
final dailyStatusProvider =
    syncedWithAccount(FutureProvider<DailyStatus>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(storeRepositoryProvider).getDailyStatus();
}));

class DailyRewardsScreen extends ConsumerStatefulWidget {
  const DailyRewardsScreen({super.key});

  @override
  ConsumerState<DailyRewardsScreen> createState() => _DailyRewardsScreenState();
}

class _DailyRewardsScreenState extends ConsumerState<DailyRewardsScreen> {
  bool _busy = false;

  Future<void> _claim(DailyStatus status) async {
    setState(() => _busy = true);
    try {
      final updated =
          await ref.read(storeRepositoryProvider).claimDailyReward();
      // Overwrite the cached status with what the server just returned rather
      // than guessing, and pull the new balance in.
      ref.invalidate(dailyStatusProvider);
      await ref.read(authControllerProvider.notifier).refreshProfile();
      if (!mounted) return;

      final claimed = updated.rewards.length >= updated.currentDay
          ? updated.rewards[updated.currentDay - 1]
          : null;
      AppSnack.show(
        context,
        claimed == null
            ? 'Daily reward claimed!'
            : 'Day ${updated.currentDay}: +${claimed.coins} coins, '
                '+${claimed.xp} XP',
        icon: Icons.card_giftcard_rounded,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnack.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(dailyStatusProvider);

    return PanelScreen(
      title: 'Daily Rewards',
      onBack: () => context.pop(),
      fillHeight: true,
      child: status.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorStateView(
          message: e.toString(),
          onRetry: () => ref.invalidate(dailyStatusProvider),
        ),
        data: (s) => _Track(
          status: s,
          busy: _busy,
          onClaim: () => _claim(s),
        ),
      ),
    );
  }
}

class _Track extends StatelessWidget {
  final DailyStatus status;
  final bool busy;
  final VoidCallback onClaim;

  const _Track({
    required this.status,
    required this.busy,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final claimed = status.claimedToday;

    // The tiles take whatever height is left after the header, so the track
    // fills the panel instead of sitting in a strip with the bottom half of
    // the screen empty.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ArtImage(Art.treasureChest, width: 64),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    claimed
                        ? 'COME BACK TOMORROW'
                        : 'DAY ${status.currentDay} IS READY',
                    style:
                        AppTextStyles.label.copyWith(color: AppColors.gold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status.streak > 0
                        ? '${status.streak} day streak - miss a day and '
                            'the track restarts at day 1.'
                        : 'Claim seven days in a row for the biggest '
                            'payout.',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 150,
              child: AppButton(
                label: claimed ? 'CLAIMED' : 'CLAIM',
                variant: AppButtonVariant.gold,
                size: AppButtonSize.small,
                isLoading: busy,
                onPressed: status.canClaim ? onClaim : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.md),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < status.rewards.length; i++) ...[
                Expanded(
                  child: _DayTile(
                    reward: status.rewards[i],
                    state: _stateFor(status, status.rewards[i].day),
                  ),
                ),
                if (i != status.rewards.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static _DayState _stateFor(DailyStatus s, int day) {
    // Days before the current one in this cycle have been collected; the
    // current one is either today's claim or already taken.
    if (day < s.currentDay) return _DayState.claimed;
    if (day == s.currentDay) {
      return s.claimedToday ? _DayState.claimed : _DayState.today;
    }
    return _DayState.locked;
  }
}

enum _DayState { claimed, today, locked }

class _DayTile extends StatelessWidget {
  final DailyReward reward;
  final _DayState state;

  const _DayTile({required this.reward, required this.state});

  @override
  Widget build(BuildContext context) {
    final isToday = state == _DayState.today;
    final isClaimed = state == _DayState.claimed;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.gold.withValues(alpha: 0.14)
            : AppColors.surfaceHigh,
        borderRadius: AppDimens.brSm,
        border: Border.all(
          color: isToday ? AppColors.gold : AppColors.surfaceStroke,
          width: isToday ? 1.6 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Day ${reward.day}',
            style: AppTextStyles.caption.copyWith(
              fontSize: 9,
              color: isToday ? AppColors.gold : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: isClaimed
                ? const Icon(Icons.check_circle_rounded,
                    size: 26, color: AppColors.green)
                : ArtImage(
                    Art.coinStack,
                    width: 34,
                    fallback: const Icon(
                      Icons.monetization_on_rounded,
                      size: 20,
                      color: AppColors.coin,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            '${reward.coins}',
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isClaimed ? AppColors.textMuted : AppColors.textPrimary,
            ),
          ),
          Text(
            '+${reward.xp} XP',
            style: AppTextStyles.caption.copyWith(
              fontSize: 8,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
