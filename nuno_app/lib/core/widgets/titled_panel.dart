import 'dart:math' as math;

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
                  : LayoutBuilder(
                      builder: (context, box) {
                        final insets = padding.resolve(
                          Directionality.of(context),
                        );
                        // The scroll view still fills the panel: without the
                        // minimum height a short body sat in a strip at the
                        // top with the rest of the panel empty.
                        return SingleChildScrollView(
                          padding: padding,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: math.max(
                                0,
                                box.maxHeight - insets.vertical,
                              ),
                            ),
                            child: child,
                          ),
                        );
                      },
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

/// Full-screen landscape scaffold: dark gradient + a full-bleed titled panel.
class PanelScreen extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Optional cap on the panel width.
  ///
  /// Defaults to unbounded. Every screen used to pass a hand-tuned figure
  /// (420, 560, 620, 900...) which, on a landscape phone, left the panel
  /// occupying half the display with dead space to the right of it. A cap is
  /// only useful on a tablet, so it is applied *only* when the viewport is
  /// genuinely wider than the cap by a comfortable margin.
  final double? maxWidth;

  final EdgeInsetsGeometry padding;

  /// Hand the body the panel's height instead of wrapping it in a scroll
  /// view. Set this when the body is itself a list, a grid, or a row with a
  /// side nav — anything that needs a bounded height to lay out.
  ///
  /// The panel fills the viewport either way now. Panels that sized
  /// themselves to their content floated in the middle of the screen with
  /// the rest of the display empty, which is what "aadha screen hi dikh raha
  /// hai" describes.
  final bool fillHeight;

  const PanelScreen({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.trailing,
    this.maxWidth,
    this.padding = const EdgeInsets.all(AppDimens.lg),
    this.fillHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ArtBackground(
        asset: Art.bgPanel,
        vignette: false,
        // Full-bleed, hard against the left edge.
        //
        // SafeArea excludes the left inset for the same reason the bottom bar
        // does: in landscape it reports the display cutout there, and
        // honouring it reopens the gap down the side of every screen.
        child: SafeArea(
          left: false,
          child: LayoutBuilder(
            builder: (context, box) {
              // Only honour a width cap when there is real room to spare;
              // otherwise the panel takes the whole viewport.
              final cap = maxWidth;
              final width = (cap != null && box.maxWidth > cap + 120)
                  ? cap
                  : double.infinity;

              return Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                  child: SizedBox(
                    width: width == double.infinity ? null : width,
                    height: double.infinity,
                    child: TitledPanel(
                      title: title,
                      onBack: onBack,
                      trailing: trailing,
                      padding: padding,
                      // A body that lays out horizontally, or scrolls on its
                      // own, wants the panel's height directly. Everything
                      // else goes through the panel's own scroll view, which
                      // now also stretches to fill the height.
                      expandBody: fillHeight,
                      child: child,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
