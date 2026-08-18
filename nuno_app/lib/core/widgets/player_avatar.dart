import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/models/enums.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// Circular avatar with optional presence dot, level badge and active ring.
class PlayerAvatar extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final double size;
  final PlayerOnlineStatus? status;
  final int? level;
  final bool isActive;
  final Color? ringColor;
  final VoidCallback? onTap;

  const PlayerAvatar({
    super.key,
    required this.username,
    this.avatarUrl,
    this.size = AppDimens.avatarMd,
    this.status,
    this.level,
    this.isActive = false,
    this.ringColor,
    this.onTap,
  });

  Color get _seedColor {
    if (username.isEmpty) return AppColors.primary;
    const palette = [
      AppColors.primary,
      AppColors.accent,
      AppColors.cardRed,
      AppColors.cardBlue,
      AppColors.cardGreen,
      AppColors.cardYellow,
      AppColors.rarityEpic,
    ];
    return palette[username.codeUnitAt(0) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final ring = ringColor ?? (isActive ? AppColors.accent : null);
    final initials =
        username.isEmpty ? '?' : username.substring(0, 1).toUpperCase();

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _seedColor.withValues(alpha: 0.85),
            _seedColor.withValues(alpha: 0.45),
          ],
        ),
        border: ring == null
            ? Border.all(color: AppColors.surfaceStroke, width: 1.5)
            : Border.all(color: ring, width: 2.5),
        boxShadow: ring == null
            ? null
            : [
                BoxShadow(
                  color: ring.withValues(alpha: 0.45),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: switch (avatarUrl) {
        // A bundled portrait bought from the store.
        final a? when a.startsWith('assets/') => Image.asset(
            a,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initialsFallback(initials),
          ),
        // A remote picture, if the account ever gets uploads.
        final a? when a.startsWith('http') => CachedNetworkImage(
            imageUrl: a,
            fit: BoxFit.cover,
            placeholder: (_, __) => _initialsFallback(initials),
            errorWidget: (_, __, ___) => _initialsFallback(initials),
          ),
        // Default: the generated initials tile.
        _ => _initialsFallback(initials),
      },
    );

    if (status != null || level != null) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          if (status != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                decoration: BoxDecoration(
                  color: AppColors.forStatus(status!.wire),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
              ),
            ),
          if (level != null)
            Positioned(
              left: -2,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: AppDimens.brPill,
                  border: Border.all(color: AppColors.background, width: 1.5),
                ),
                child: Text(
                  '$level',
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFF3A2600),
                    fontWeight: FontWeight.w900,
                    fontSize: size * 0.19,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return onTap == null
        ? avatar
        : GestureDetector(onTap: onTap, child: avatar);
  }

  Widget _initialsFallback(String initials) => Center(
        child: Text(
          initials,
          style: AppTextStyles.h3.copyWith(
            fontSize: size * 0.42,
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}
