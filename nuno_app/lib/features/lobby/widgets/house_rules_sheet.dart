import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/models/house_rules.dart';

/// The house-rule picker.
///
/// Opened from the lobby only. Quick Match has no equivalent and is not meant
/// to: players matched by rating have agreed to nothing, so the queue is
/// always the official game.
///
/// Guests see the same list, read-only. They are about to play under these
/// rules, so hiding them would be worse than showing something they cannot
/// change.
class HouseRulesSheet extends StatefulWidget {
  final HouseRules rules;

  /// False for everybody except the host.
  final bool editable;

  const HouseRulesSheet({
    super.key,
    required this.rules,
    required this.editable,
  });

  /// Returns the chosen rules, or null if dismissed without applying.
  static Future<HouseRules?> show(
    BuildContext context, {
    required HouseRules rules,
    required bool editable,
  }) =>
      showDialog<HouseRules>(
        context: context,
        builder: (_) => HouseRulesSheet(rules: rules, editable: editable),
      );

  @override
  State<HouseRulesSheet> createState() => _HouseRulesSheetState();
}

class _HouseRulesSheetState extends State<HouseRulesSheet> {
  late HouseRules _draft = widget.rules;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.md,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppDimens.brLg,
          border: Border.all(color: AppColors.surfaceStroke),
        ),
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('GAME RULES', style: AppTextStyles.label),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textMuted,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            // ── Official, as a real choice rather than "all off" ──
            _OfficialTile(
              selected: _draft.isOfficial,
              editable: widget.editable,
              onTap: () => setState(() => _draft = HouseRules.official),
            ),

            const SizedBox(height: AppDimens.sm),
            Text(
              'HOUSE RULES',
              style: AppTextStyles.label.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppDimens.xs),
            Text(
              widget.editable
                  ? 'Tick any combination. None of these are official UNO.'
                  : 'Set by the host.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppDimens.sm),

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final spec in houseRuleSpecs)
                      _RuleTile(
                        spec: spec,
                        value: spec.get(_draft),
                        editable: widget.editable,
                        onChanged: (v) =>
                            setState(() => _draft = spec.set(_draft, v)),
                      ),
                  ],
                ),
              ),
            ),

            if (widget.editable) ...[
              const SizedBox(height: AppDimens.md),
              AppButton(
                label: 'APPLY',
                variant: AppButtonVariant.gold,
                size: AppButtonSize.small,
                onPressed: () => Navigator.pop(context, _draft),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OfficialTile extends StatelessWidget {
  final bool selected;
  final bool editable;
  final VoidCallback onTap;

  const _OfficialTile({
    required this.selected,
    required this.editable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: editable ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.sm),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.success.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: AppDimens.brSm,
          border: Border.all(
            color: selected ? AppColors.success : AppColors.surfaceStroke,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? AppColors.success : AppColors.textMuted,
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Official rules',
                    style: AppTextStyles.h4.copyWith(fontSize: 14),
                  ),
                  Text(
                    'The game as Mattel prints it. No stacking.',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  final HouseRuleSpec spec;
  final bool value;
  final bool editable;
  final ValueChanged<bool> onChanged;

  const _RuleTile({
    required this.spec,
    required this.value,
    required this.editable,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: editable ? 1 : 0.7,
      child: GestureDetector(
        onTap: editable ? () => onChanged(!value) : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              // A real checkbox, since the whole point is that any
              // combination is allowed.
              SizedBox(
                width: 26,
                height: 26,
                child: Checkbox(
                  value: value,
                  onChanged: editable ? (v) => onChanged(v ?? false) : null,
                  activeColor: AppColors.accent,
                  checkColor: Colors.black,
                  side: const BorderSide(
                    color: AppColors.surfaceStroke,
                    width: 1.4,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      spec.title,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      spec.description,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
