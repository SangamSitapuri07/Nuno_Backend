import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';

/// Coin / gem readout used in the home header and store, matching the
/// reference's pill with a coloured disc icon.
class CurrencyPill extends StatelessWidget {
  final int coins;
  final int gems;
  final VoidCallback? onTap;

  const CurrencyPill({
    super.key,
    required this.coins,
    this.gems = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.lg,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: AppColors.backgroundAlt,
          borderRadius: AppDimens.brPill,
          border: Border.all(color: AppColors.surfaceStroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Amount(
              color: AppColors.coin,
              icon: Icons.monetization_on_rounded,
              value: coins,
            ),
            Container(
              width: 1,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: AppDimens.md),
              color: AppColors.surfaceStroke,
            ),
            _Amount(
              color: AppColors.gem,
              icon: Icons.diamond_rounded,
              value: gems,
            ),
          ],
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  final Color color;
  final IconData icon;
  final int value;

  const _Amount({
    required this.color,
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 5),
        Text(
          Formatters.compact(value),
          style: AppTextStyles.body.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Single-currency variant (store item prices, reward tiles).
class CoinTag extends StatelessWidget {
  final int amount;
  final bool isGem;
  final double fontSize;

  const CoinTag({
    super.key,
    required this.amount,
    this.isGem = false,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isGem ? Icons.diamond_rounded : Icons.monetization_on_rounded,
          size: fontSize + 2,
          color: isGem ? AppColors.gem : AppColors.coin,
        ),
        const SizedBox(width: 4),
        Text(
          Formatters.number(amount),
          style: AppTextStyles.body.copyWith(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
