import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

class SideNavItem {
  final IconData icon;
  final String label;

  const SideNavItem(this.icon, this.label);
}

/// Vertical section switcher used by Profile (19) and Settings (25):
/// a narrow list of labelled rows with the active one highlighted.
class SideNav extends StatelessWidget {
  final List<SideNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  final double width;

  const SideNav({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
    this.width = 116,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (context, i) {
          final active = i == index;
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.sm,
                  vertical: AppDimens.sm,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.blue.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: AppDimens.brSm,
                  border: Border.all(
                    color: active
                        ? AppColors.blue.withValues(alpha: 0.6)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      items[i].icon,
                      size: 14,
                      color:
                          active ? AppColors.blue : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        items[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 11,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          color: active
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
