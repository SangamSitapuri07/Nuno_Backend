import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/titled_panel.dart';
import '../auth/auth_controller.dart';

/// Screen 24 — Daily Rewards. A 7-day track with a CLAIM action.
///
/// The backend exposes only `POST /rewards/daily` with no streak state, so the
/// current day is not persisted server-side; the track is presentational.
class DailyRewardsScreen extends ConsumerStatefulWidget {
  const DailyRewardsScreen({super.key});

  @override
  ConsumerState<DailyRewardsScreen> createState() =>
      _DailyRewardsScreenState();
}

class _DailyRewardsScreenState extends ConsumerState<DailyRewardsScreen> {
  static const _rewards = [100, 150, 200, 250, 300, 400, 500];
  static const _currentDay = 2; // 1-based; no server streak to read.

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
    return PanelScreen(
      title: 'Daily Rewards',
      onBack: () => context.pop(),
      maxWidth: 620,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _claimed ? 'COME BACK TOMORROW' : 'CLAIM YOUR DAILY REWARD',
            style: AppTextStyles.label.copyWith(color: AppColors.gold),
          ),
          const SizedBox(height: AppDimens.md),
          Row(
            children: [
              for (var day = 1; day <= 7; day++) ...[
                Expanded(
                  child: _DayTile(
                    day: day,
                    amount: _rewards[day - 1],
                    isGem: day == 7,
                    state: day < _currentDay
                        ? _DayState.claimed
                        : day == _currentDay
                            ? (_claimed ? _DayState.claimed : _DayState.today)
                            : _DayState.locked,
                  ),
                ),
                if (day != 7) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: AppDimens.lg),
          SizedBox(
            width: 220,
            child: AppButton(
              label: _claimed ? 'CLAIMED' : 'CLAIM',
              variant: AppButtonVariant.gold,
              size: AppButtonSize.small,
              isLoading: _busy,
              onPressed: _claimed ? null : _claim,
            ),
          ),
        ],
      ),
    );
  }
}

enum _DayState { claimed, today, locked }

class _DayTile extends StatelessWidget {
  final int day;
  final int amount;
  final bool isGem;
  final _DayState state;

  const _DayTile({
    required this.day,
    required this.amount,
    required this.state,
    this.isGem = false,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = state == _DayState.today;
    final isClaimed = state == _DayState.claimed;
    final accent = isGem ? AppColors.gem : AppColors.coin;

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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Day $day',
            style: AppTextStyles.caption.copyWith(
              fontSize: 9,
              color: isToday ? AppColors.gold : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Icon(
            isClaimed
                ? Icons.check_circle_rounded
                : (isGem
                    ? Icons.diamond_rounded
                    : Icons.monetization_on_rounded),
            size: 20,
            color: isClaimed ? AppColors.green : accent,
          ),
          const SizedBox(height: 4),
          Text(
            '$amount',
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isClaimed ? AppColors.textMuted : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
