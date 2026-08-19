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

  /// Give the body the panel's remaining height instead of scrolling it.
  ///
  /// A body that lays out horizontally - a side nav beside a list, say -
  /// needs a bounded height. Wrapping that in a vertical scroll view hands it
  /// infinite height instead, which is a different bug from the overflow the
  /// scroll view was added to prevent.
  final bool expandBody;

  const TitledPanel({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.trailing,
    this.accent,
    this.padding = const EdgeInsets.all(AppDimens.lg),
    this.expandBody = false,
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
              child: expandBody
                  ? Padding(padding: padding, child: child)
                  : SingleChildScrollView(padding: padding, child: child),
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

  /// Stretch the panel to the full height of the viewport.
  ///
  /// Screens with a list or a side nav look stranded when the panel shrinks
  /// to its content and floats in the middle of a landscape display.
  final bool fillHeight;

  const PanelScreen({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.trailing,
    this.maxWidth = 560,
    this.padding = const EdgeInsets.all(AppDimens.lg),
    this.fillHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ArtBackground(
        asset: Art.bgPanel,
        vignette: false,
        // Left-aligned and tight to the edge.
        //
        // Centring inside a maxWidth left a wide gap down the left of a
        // landscape phone, which read as the screen being half empty. The
        // panel now starts at the edge and simply stops at maxWidth.
        //
        // SafeArea excludes the left inset for the same reason the bottom bar
        // does: in landscape it reports the cutout there and would reopen the
        // gap. Vertical insets are still respected.
        child: SafeArea(
          left: false,
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  4,
                  AppDimens.sm,
                  AppDimens.sm,
                  AppDimens.sm,
                ),
                child: SizedBox(
                  height: fillHeight ? double.infinity : null,
                  child: TitledPanel(
                    title: title,
                    onBack: onBack,
                    trailing: trailing,
                    padding: padding,
                    // A full-height panel bounds its body, so it lays out
                    // directly rather than being handed infinite height.
                    expandBody: fillHeight,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
