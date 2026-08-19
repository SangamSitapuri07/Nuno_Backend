import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/titled_panel.dart';
import '../../data/models/enums.dart';

/// Screen 3 — Play Menu: a 2x2 grid of gradient action tiles.
class PlayMenuScreen extends ConsumerWidget {
  const PlayMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PanelScreen(
      title: 'Play Menu',
      onBack: () => context.pop(),
      maxWidth: 760,
      // Fills the screen instead of a small floating card, and the grid
      // scrolls on its own now that the panel bounds it.
      fillHeight: true,
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: AppDimens.md,
        crossAxisSpacing: AppDimens.md,
        childAspectRatio: 2.6,
        children: [
          _MenuTile(
            title: 'QUICK MATCH',
            subtitle: 'Find match with random players',
            icon: Icons.flash_on_rounded,
            gradient: AppColors.violetGradient,
            onTap: () => context.push(
              AppRoutes.matchmaking,
              extra: GameMode.casual,
            ),
          ),
          _MenuTile(
            title: 'CREATE ROOM',
            subtitle: 'Create a room and invite friends',
            icon: Icons.add_box_rounded,
            gradient: AppColors.blueGradient,
            onTap: () => context.push(AppRoutes.createRoom),
          ),
          _MenuTile(
            title: 'JOIN ROOM',
            subtitle: 'Join with room code',
            icon: Icons.login_rounded,
            gradient: AppColors.violetGradient,
            onTap: () => context.push(AppRoutes.joinRoom),
          ),
          _MenuTile(
            title: 'MATCH HISTORY',
            subtitle: 'View your recent matches',
            icon: Icons.history_rounded,
            gradient: AppColors.blueGradient,
            onTap: () => context.push(AppRoutes.matchHistory),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _MenuTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.md),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: AppDimens.brMd,
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: AppDimens.brSm,
                ),
                child: Icon(widget.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTextStyles.h3.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySm.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
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
