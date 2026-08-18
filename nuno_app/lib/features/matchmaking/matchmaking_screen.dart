import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/player_avatar.dart';
import '../../data/models/enums.dart';
import '../auth/auth_controller.dart';
import 'matchmaking_providers.dart';

/// Searching-for-opponents screen. Auto-navigates to the game once the server
/// emits game.started (matchmaking auto-starts the match after 3s).
class MatchmakingScreen extends ConsumerStatefulWidget {
  final GameMode mode;

  const MatchmakingScreen({super.key, this.mode = GameMode.casual});

  @override
  ConsumerState<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends ConsumerState<MatchmakingScreen> {
  /// Chosen table size. The queue is not joined until the player confirms:
  /// entering the screen used to drop them straight into a search, with no
  /// say in how many people they were about to play against.
  int _tableSize = 4;

  void _startSearch() {
    ref
        .read(matchmakingControllerProvider.notifier)
        .joinQueue(widget.mode, requiredPlayers: _tableSize);
  }

  void _cancel() {
    ref.read(matchmakingControllerProvider.notifier).leaveQueue();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  /// Back out of a search without leaving the screen.
  void _stopSearch() {
    ref.read(matchmakingControllerProvider.notifier).leaveQueue();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchmakingControllerProvider);

    // Navigate into the match when the server starts it.
    ref.listen<MatchmakingState>(matchmakingControllerProvider, (prev, next) {
      if (next.status == QueueStatus.inGame) {
        context.pushReplacement(AppRoutes.game);
      }
      if (next.error != null && next.error != prev?.error) {
        AppSnack.error(context, next.error!);
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.xxl),
              child: Column(
                children: [
                  // ── Header ─────────────────────────────
                  Row(
                    children: [
                      AppIconButton(
                        icon: Icons.close_rounded,
                        onPressed: _cancel,
                      ),
                      const Spacer(),
                      AppChip(
                        label: state.mode.label.toUpperCase(),
                        color: state.mode == GameMode.ranked
                            ? AppColors.gold
                            : AppColors.primary,
                        icon: state.mode == GameMode.ranked
                            ? Icons.emoji_events_rounded
                            : Icons.bolt_rounded,
                      ),
                      const Spacer(),
                      const SizedBox(width: 44),
                    ],
                  ),

                  const Spacer(),

                  // Before searching, the player picks how many people they
                  // want at the table; only then is the queue joined.
                  if (state.status == QueueStatus.idle) ...[
                    Text('TABLE SIZE', style: AppTextStyles.label),
                    const SizedBox(height: AppDimens.sm),
                    Text(
                      'You will only be matched with players\nwho chose the same size.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: AppDimens.xl),
                    Wrap(
                      spacing: AppDimens.md,
                      runSpacing: AppDimens.md,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final n in AppConfig.quickMatchSizes)
                          _SizeChip(
                            count: n,
                            selected: _tableSize == n,
                            onTap: () => setState(() => _tableSize = n),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.xxl),
                    SizedBox(
                      width: 260,
                      child: AppButton(
                        label: 'FIND MATCH',
                        icon: Icons.search_rounded,
                        variant: AppButtonVariant.gold,
                        onPressed: _startSearch,
                      ),
                    ),
                  ] else ...[
                    // ── Radar ──────────────────────────────
                    if (state.isMatchFound)
                      const _MatchFoundBadge()
                    else
                      const _SearchRadar(),

                    const SizedBox(height: AppDimens.xl),

                    Text(
                      state.isMatchFound
                          ? 'Match found!'
                          : 'Finding ${state.tableSize} players',
                      style: AppTextStyles.h2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimens.xs),
                    Text(
                      state.isMatchFound
                          ? 'Starting the game...'
                          : 'Waiting for a ${state.tableSize}-player table',
                      style: AppTextStyles.bodySm,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: AppDimens.lg),

                    // ── Timer ──────────────────────────────
                    if (!state.isMatchFound)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.xl,
                          vertical: AppDimens.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppDimens.brPill,
                          border: Border.all(color: AppColors.surfaceStroke),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined,
                                size: 16, color: AppColors.textMuted),
                            const SizedBox(width: AppDimens.sm),
                            Text(
                              state.elapsedLabel,
                              style:
                                  AppTextStyles.numeric.copyWith(fontSize: 18),
                            ),
                          ],
                        ),
                      ),

                    // ── Found players ──────────────────────
                    if (state.isMatchFound && state.match != null) ...[
                      const SizedBox(height: AppDimens.md),
                      Wrap(
                        spacing: AppDimens.md,
                        runSpacing: AppDimens.md,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final p in state.match!.players)
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PlayerAvatar(
                                  username: p.username,
                                  size: 44,
                                  isActive: true,
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 66,
                                  child: Text(
                                    p.username,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.caption,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ],

                  const Spacer(),

                  // ── Tip ────────────────────────────────
                  const _RotatingTip(),

                  const SizedBox(height: AppDimens.lg),

                  // Stopping the search returns to the size picker rather
                  // than leaving the screen entirely.
                  if (state.isSearching)
                    AppButton(
                      label: 'STOP SEARCHING',
                      variant: AppButtonVariant.ghost,
                      onPressed: _stopSearch,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulsing radar with the player's avatar at the centre.
class _SearchRadar extends ConsumerStatefulWidget {
  const _SearchRadar();

  @override
  ConsumerState<_SearchRadar> createState() => _SearchRadarState();
}

class _SearchRadarState extends ConsumerState<_SearchRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);

    return SizedBox(
      width: 220,
      height: 220,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Expanding rings.
              for (var i = 0; i < 3; i++)
                _ring((_controller.value + i / 3) % 1),

              // Rotating sweep.
              Transform.rotate(
                angle: _controller.value * 2 * math.pi,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.primary.withValues(alpha: 0.30),
                        Colors.transparent,
                      ],
                      stops: const [0.6, 0.9, 1.0],
                    ),
                  ),
                ),
              ),

              child!,
            ],
          );
        },
        child: PlayerAvatar(
          username: profile?.username ?? 'P',
          avatarUrl: profile?.avatarUrl,
          size: 88,
          isActive: true,
        ),
      ),
    );
  }

  Widget _ring(double t) {
    return Opacity(
      opacity: (1 - t).clamp(0.0, 1.0) * 0.5,
      child: Container(
        width: 90 + 130 * t,
        height: 90 + 130 * t,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _MatchFoundBadge extends StatelessWidget {
  const _MatchFoundBadge();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.accentGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.5),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 84,
          color: Color(0xFF00201C),
        ),
      ),
    );
  }
}

/// Cycles gameplay tips while queueing.
class _RotatingTip extends StatefulWidget {
  const _RotatingTip();

  @override
  State<_RotatingTip> createState() => _RotatingTipState();
}

class _RotatingTipState extends State<_RotatingTip> {
  static const _tips = [
    'Call UNO the moment you are down to one card.',
    'Save Wild Draw Four for when you really need it.',
    'Watch the colour your opponents keep avoiding.',
    'Reverse cards can hand you back-to-back turns in a 2-player game.',
    'You have 20 seconds per turn before the server auto-draws.',
  ];

  int _index = 0;
  late final Stream<int> _ticker = Stream.periodic(
    const Duration(seconds: 5),
    (i) => i,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _ticker,
      builder: (context, snapshot) {
        _index = (snapshot.data ?? 0) % _tips.length;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: AppPanel(
            key: ValueKey(_index),
            padding: const EdgeInsets.all(AppDimens.lg),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 18, color: AppColors.gold),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: Text(_tips[_index], style: AppTextStyles.bodySm),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


/// One table-size option in the quick-match picker.
class _SizeChip extends StatelessWidget {
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _SizeChip({
    required this.count,
    required this.selected,
    required this.onTap,
  });

  /// Familiar names for the small sizes, as in other games.
  String get _label => switch (count) {
        2 => 'DUO',
        3 => 'TRIO',
        4 => 'SQUAD',
        _ => '$count PLAYERS',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceHigh,
          borderRadius: AppDimens.brMd,
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.surfaceStroke,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: AppTextStyles.h2.copyWith(
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            Text(
              _label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white70 : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
