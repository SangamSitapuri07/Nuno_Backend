import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import 'game_assets.dart';

/// The reference sheet's signature container: a dark rounded panel with a
/// centered uppercase title strip on top, optionally with a back arrow.
class TitledPanel extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Color? accent;
  final EdgeInsetsGeometry padding;

  const TitledPanel({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.trailing,
    this.accent,
    this.padding = const EdgeInsets.all(AppDimens.lg),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDimens.brLg,
        border: Border.all(color: AppColors.surfaceStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header strip ────────────────────────────
          Container(
            height: AppDimens.panelHeaderHeight,
            decoration: const BoxDecoration(
              color: AppColors.panelHeader,
              border: Border(
                bottom: BorderSide(color: AppColors.surfaceStroke),
              ),
            ),
            child: Row(
              children: [
                if (onBack != null)
                  _HeaderIcon(icon: Icons.arrow_back_rounded, onTap: onBack!)
                else
                  const SizedBox(width: AppDimens.huge),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.panelTitle.copyWith(
                      color: accent ?? AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  width: AppDimens.huge,
                  child: trailing == null
                      ? null
                      : Center(child: trailing),
                ),
              ],
            ),
          ),

          // Scrollable and clipped.
          //
          // Every panel in the app funnels through here, and a landscape
          // phone leaves very little height once the system insets and the
          // header strip are taken out. Any content that did not fit painted
          // the debug overflow stripes across the bottom of the screen,
          // hiding whatever sat there. Making the body scroll means content
          // that does not fit can still be reached, and the clip guarantees
          // nothing is ever drawn outside the panel.
          Flexible(
            child: ClipRRect(
              borderRadius: AppDimens.brLg,
              child: SingleChildScrollView(
                padding: padding,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppDimens.huge,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// Full-screen landscape scaffold: dark gradient + a centered titled panel.
class PanelScreen extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? trailing;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const PanelScreen({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.trailing,
    this.maxWidth = 560,
    this.padding = const EdgeInsets.all(AppDimens.lg),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ArtBackground(
        asset: Art.bgPanel,
        vignette: false,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.xl,
                  vertical: AppDimens.md,
                ),
                child: TitledPanel(
                  title: title,
                  onBack: onBack,
                  trailing: trailing,
                  padding: padding,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
