import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/game_assets.dart';
import '../../data/models/enums.dart';
import '../../data/models/user_models.dart';
import '../auth/auth_controller.dart';
import 'home_providers.dart';
import 'widgets/friends_panel.dart';
import 'widgets/player_badge.dart';

/// Home screen.
///
/// Laid out with Column/Row slots rather than a Stack of Positioned widgets.
/// Every element owns a real box, and each image is wrapped so it scales to
/// fit its box — so nothing can overflow into a neighbour regardless of the
/// device aspect ratio.
///
///   ┌──────────────────────────────────────────────┐
///   │ header: badge · coins · gems · settings      │  fixed height
///   ├───────────────────────────────┬──────────────┤
///   │ stage: podium │ chest         │ friends      │  flexible
///   │                               ├──────────────┤
///   │                               │ PLAY         │
///   ├───────────────────────────────┴──────────────┤
///   │ (space reserved for the floating nav bar)    │
///   └──────────────────────────────────────────────┘
/// Width of the friends pull-tab.
///
/// The collapsed offset is derived from this, so the tab lands exactly flush
/// with the right edge. Hard-coding the two separately is how a handle ends
/// up half off-screen, or with a sliver of the list still showing.
const double kFriendsTabWidth = 26;

class HomeScreen extends ConsumerWidget {
  final ValueChanged<int>? onNavigate;
  final int navIndex;

  const HomeScreen({super.key, this.onNavigate, this.navIndex = 0});

  /// Height reserved at the bottom for the shell's floating nav bar.
  static const double navReserve = 60;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        const _RotatingBackground(),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xB805030F), Color(0x1405030F), Color(0xB805030F)],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),

        SafeArea(
          // No bottom inset: PLAY is meant to sit flush on the screen edge.
          // No left inset either: in landscape that is the display cutout,
          // and honouring it indents the whole screen.
          left: false,
          bottom: false,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final h = box.maxHeight;

              // Right column: friends panel above, PLAY below.
              //
              // Collapsed, the column keeps only what PLAY needs plus the
              // toggle tab, and the stage grows into the rest.
              final friendsOpen = ref.watch(friendsPanelVisibleProvider);
              final totalUnread = ref
                      .watch(unreadCountsProvider)
                      .valueOrNull
                      ?.values
                      .fold<int>(0, (sum, n) => sum + n) ??
                  0;

              // The right column's width NEVER changes.
              //
              // Collapsing used to shrink it from ~29% of the screen to
              // 132px, and because the stage is an Expanded sibling it
              // absorbed the difference - so the podium, the chest and the
              // header all jumped sideways every time the list was toggled.
              // The column now keeps its width and only the LIST inside it
              // slides away, which is what "hide the friends list" should
              // mean: nothing else on the screen moves at all.
              final columnWidth = (w * 0.29).clamp(200.0, 320.0);
              // Sized to the strip's contents, not a share of the screen.
              //
              // 19% of the height gave a 72px bar to hold a 48px badge, so
              // roughly a third of it was empty and the stage lost the space
              // for nothing. The badge is the tallest thing in it, so the
              // bar is now just that plus a hairline, and the clamp only
              // guards very short canvases.
              // Floor is 50, not 48: with a title equipped the badge's three
              // stacked lines need 48.1px, and 48 left it 0.1px short on a
              // 300px-tall canvas - which is an overflow stripe, not a
              // rounding detail.
              final headerHeight = (h * 0.14).clamp(50.0, 56.0);
              // PLAY is pinned bottom-right; the panel takes the rest.
              //
              // Derived from the artwork's aspect ratio rather than a share
              // of the viewport height. The button is a 2:1 rectangle, and a
              // slot taller than that just adds empty space above and below
              // it - BoxFit.contain letterboxes the image inside whatever box
              // it is given, so an over-tall slot is what made the button
              // read as a square block.
              final playHeight =
                  (columnWidth / Art.buttonAspect).clamp(52.0, 96.0);

              return Padding(
                // Tight to the left edge; the right keeps a normal gutter.
                padding: const EdgeInsets.fromLTRB(
                  4,
                  // Was AppDimens.sm (8). The strip already has its own
                  // internal padding, so this was doubling up.
                  4,
                  AppDimens.md,
                  0,
                ),
                // Two full-height columns. The header lives inside the LEFT
                // column only, so the friends panel on the right can start at
                // the very top of the screen.
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Left column: header over the stage ──
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: headerHeight,
                            child: Row(
                              children: [
                                Flexible(
                                  child: PlayerBadge(
                                    username: profile?.username ?? 'Player',
                                    avatarUrl: profile?.avatarUrl,
                                    level: profile?.level ?? 1,
                                    levelProgress: profile?.levelProgress ?? 0,
                                    tier: profile?.leaderboard?.tier ??
                                        RankTier.bronze,
                                    onTap: () => onNavigate?.call(3),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _CurrencyCapsule(
                                  icon: Icons.monetization_on_rounded,
                                  iconColor: AppColors.gold,
                                  value: profile?.coins ?? 0,
                                  onAdd: () => onNavigate?.call(2),
                                ),
                                const SizedBox(width: 4),
                                const _CurrencyCapsule(
                                  icon: Icons.diamond_rounded,
                                  iconColor: AppColors.cyan,
                                  // No gem currency on the backend yet.
                                  value: 0,
                                ),
                                const SizedBox(width: 4),
                                _GlassCircleButton(
                                  icon: Icons.settings_rounded,
                                  onTap: () =>
                                      context.push(AppRoutes.settings),
                                ),
                              ],
                            ),
                          ),

                          // Stage: podium + chest.
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                right: AppDimens.sm,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    // Paint-time shift: keeps the art at its
                                    // current size and simply drops it lower.
                                    child: Transform.translate(
                                      offset: const Offset(0, -12),
                                      // Decorative only: the game starts from
                                      // the PLAY button, nowhere else.
                                      child: const _FloatingAsset(
                                        asset: Art.cardPodium,
                                        scale: 0.88,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 52,
                                      ),
                                      child: _FloatingAsset(
                                        asset: Art.treasureChest,
                                        amplitude: 5,
                                        onTap: () => context
                                            .push(AppRoutes.dailyRewards),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Partial clearance for the floating nav bar. The
                          // bar is only 380 wide and docked bottom-left, and
                          // the podium art tapers at its base, so the stage
                          // may reach into part of that band - which keeps the
                          // podium box tall, so it renders large and low.
                          const SizedBox(height: navReserve - 28),
                        ],
                      ),
                    ),

                    // ── Right column: friends from the very top,
                    //    PLAY pinned at the bottom ──
                    //
                    // The friends panel slides away, leaving a slim tab to
                    // bring it back. On a landscape phone it takes almost a
                    // third of the width, which is a lot to give up when you
                    // just want to look at the table.
                    //
                    // The tab stays in the column rather than floating over
                    // the stage, so nothing underneath it is ever covered.
                    SizedBox(
                      width: columnWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Only the friends list collapses. PLAY keeps its
                          // slot whatever happens - hiding the friends list
                          // must not take the main action with it.
                          // The tab and the list travel together.
                          //
                          // They used to be separate: the tab sat at the
                          // left of the column while only the list slid
                          // away, which left the handle stranded in the
                          // middle of the screen with empty space to the
                          // right of it. Sliding the pair as one group means
                          // the tab rides out with the list and comes to
                          // rest against the right edge, where it is still
                          // the thing you press to bring everything back.
                          //
                          // The shift is exactly the list's width, so the
                          // tab ends up flush with the edge: the group is
                          // columnWidth wide and the tab occupies the first
                          // kFriendsTabWidth of it.
                          Expanded(
                            child: ClipRect(
                              child: AnimatedSlide(
                                offset: friendsOpen
                                    ? Offset.zero
                                    : Offset(
                                        (columnWidth - kFriendsTabWidth) /
                                            columnWidth,
                                        0,
                                      ),
                                duration: const Duration(milliseconds: 240),
                                curve: Curves.easeOutCubic,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _FriendsTab(
                                      isOpen: friendsOpen,
                                      unread: totalUnread,
                                      onTap: () => ref
                                          .read(friendsPanelVisibleProvider
                                              .notifier)
                                          .state = !friendsOpen,
                                    ),
                                    Expanded(
                                      child: AnimatedOpacity(
                                        opacity: friendsOpen ? 1 : 0,
                                        duration:
                                            const Duration(milliseconds: 160),
                                        // Hidden means untappable, or the
                                        // invisible list would keep eating
                                        // taps meant for the stage behind it.
                                        child: IgnorePointer(
                                          ignoring: !friendsOpen,
                                          child: const FriendsPanel(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: playHeight,
                            child: _PlayButton(
                              onTap: () => context.push(AppRoutes.playMenu),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Slowly rotating galaxy backdrop ───────────────────────────

/// The galaxy image turning very slowly, with a gentle breathing zoom.
///
/// The image is oversized before rotating: a rotated rectangle needs a
/// diagonal-sized source or its corners sweep into view as empty space.
class _RotatingBackground extends StatefulWidget {
  const _RotatingBackground();

  @override
  State<_RotatingBackground> createState() => _RotatingBackgroundState();
}

class _RotatingBackgroundState extends State<_RotatingBackground>
    with TickerProviderStateMixin {
  // One full turn takes two minutes, so it reads as drift rather than spin.
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 120),
  )..repeat();

  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _spin.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // Cover the diagonal so no corner is ever empty mid-rotation.
        final side = math.sqrt(
              box.maxWidth * box.maxWidth + box.maxHeight * box.maxHeight,
            ) *
            1.04;

        return ClipRect(
          child: OverflowBox(
            maxWidth: side,
            maxHeight: side,
            child: AnimatedBuilder(
              animation: Listenable.merge([_spin, _breathe]),
              builder: (context, child) => Transform.rotate(
                angle: _spin.value * 2 * math.pi,
                child: Transform.scale(
                  scale: 1.0 + 0.05 * _breathe.value,
                  child: child,
                ),
              ),
              child: SizedBox(
                width: side,
                height: side,
                child: Image.asset(
                  Art.bgGalaxy,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.backgroundGradient,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Currency capsule ──────────────────────────────────────────

class _CurrencyCapsule extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final int value;
  final VoidCallback? onAdd;

  const _CurrencyCapsule({
    required this.icon,
    required this.iconColor,
    required this.value,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // 34 -> 30: the tallest thing inside is a 20px coin disc.
      height: 30,
      padding: const EdgeInsets.only(left: 3, right: 3),
      decoration: BoxDecoration(
        color: const Color(0xE61E1147),
        borderRadius: AppDimens.brPill,
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 13, color: iconColor),
          ),
          const SizedBox(width: 4),
          Text(
            Formatters.compact(value),
            style: AppTextStyles.h4.copyWith(fontSize: 13),
          ),
          if (onAdd != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded,
                    size: 12, color: Colors.white),
              ),
            ),
          ] else
            const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Matches the currency capsules so the row reads as one strip.
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xE61E1147),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.violet.withValues(alpha: 0.40)),
        ),
        child: Icon(icon, size: 18, color: Colors.white70),
      ),
    );
  }
}

// ── Bobbing asset that always fits its slot ───────────────────

class _FloatingAsset extends StatefulWidget {
  final String asset;
  final double amplitude;
  final VoidCallback? onTap;

  /// Fraction of the slot the art fills. Below 1 leaves breathing room
  /// without changing the surrounding layout.
  final double scale;

  const _FloatingAsset({
    required this.asset,
    this.amplitude = 7,
    this.onTap,
    this.scale = 1.0,
  });

  @override
  State<_FloatingAsset> createState() => _FloatingAssetState();
}

class _FloatingAssetState extends State<_FloatingAsset>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -widget.amplitude * _c.value),
        child: child,
      ),
      // BoxFit.contain guarantees the art never exceeds its slot.
      child: FractionallySizedBox(
        widthFactor: widget.scale,
        heightFactor: widget.scale,
        child: Image.asset(
          widget.asset,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );

    // Without a handler the widget stays inert, so taps fall through
    // instead of silently triggering navigation.
    if (widget.onTap == null) return art;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: art,
    );
  }
}

// ── Friends panel toggle ──────────────────────────────────────

/// The slim vertical tab that shows and hides the friends list.
///
/// Deliberately part of the layout rather than floating over it: a tab that
/// overlaps the stage would sit on top of the podium art, and the whole point
/// of collapsing the panel is to give that space back.
class _FriendsTab extends StatelessWidget {
  final bool isOpen;
  final int unread;
  final VoidCallback onTap;

  const _FriendsTab({
    required this.isOpen,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // A compact handle, not a full-height bar.
    //
    // The parent Row stretches its children, so this used to run the whole
    // height of the column and read as a wall down the middle of the screen.
    // Centring it keeps it to the size of its contents, like the pull-tabs
    // these are modelled on.
    return Center(
      child: GestureDetector(
        onTap: onTap,
        // Opaque so the whole strip is tappable, not just the glyphs.
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: kFriendsTabWidth,
          padding: const EdgeInsets.symmetric(vertical: AppDimens.md),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xE62A1A5E), Color(0xF21A0F3D)],
            ),
            // Rounded on the left only, so it reads as a tab attached to the
            // panel rather than a free-floating box.
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(AppDimens.radiusMd),
            ),
            border: Border.all(
              color: AppColors.violet.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(-2, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Points the way the panel will move.
              Icon(
                isOpen
                    ? Icons.keyboard_arrow_right_rounded
                    : Icons.keyboard_arrow_left_rounded,
                size: 18,
                color: Colors.white70,
              ),
              const SizedBox(height: AppDimens.sm),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.people_alt_rounded,
                      size: 16, color: AppColors.cyan),
                  // Unread only matters while the list is hidden; with the
                  // panel open the badge is already on the row itself.
                  if (!isOpen && unread > 0)
                    Positioned(
                      right: -5,
                      top: -4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppDimens.sm),
              // Rotated so the label reads bottom-to-top down the tab.
              RotatedBox(
                quarterTurns: 3,
                child: Text(
                  'FRIENDS',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w900,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Ornate gold PLAY button ───────────────────────────────────

class _PlayButton extends StatefulWidget {
  final VoidCallback onTap;

  const _PlayButton({required this.onTap});

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  bool _pressed = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Opaque, so the whole slot is tappable.
      //
      // The default (deferToChild) only counts a hit where the CHILD reports
      // one, and the child is an Image with BoxFit.contain. Any letterboxed
      // band left over when the slot is not exactly 2:1 is transparent and
      // registers no hit, so taps near the edge of the button quietly did
      // nothing.
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 110),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold
                      .withValues(alpha: 0.26 + 0.20 * _pulse.value),
                  blurRadius: 22 + 12 * _pulse.value,
                ),
              ],
            ),
            child: child,
          ),
          child: Image.asset(
            Art.btnPlay,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'PLAY',
                style: AppTextStyles.h2.copyWith(
                  color: const Color(0xFF3A2600),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
