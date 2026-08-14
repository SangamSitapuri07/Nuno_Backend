import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

enum AppButtonVariant { primary, accent, gold, danger, outline, ghost }

enum AppButtonSize { small, medium, large }

/// The app's primary CTA: gradient fill, chunky radius, press-depress feel.
class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  double get _height => switch (widget.size) {
        AppButtonSize.small => 40,
        AppButtonSize.medium => 48,
        AppButtonSize.large => AppDimens.buttonHeight,
      };

  double get _fontSize => switch (widget.size) {
        AppButtonSize.small => 14,
        AppButtonSize.medium => 15,
        AppButtonSize.large => 17,
      };

  Gradient? get _gradient {
    if (!_enabled) return null;
    return switch (widget.variant) {
      AppButtonVariant.primary => AppColors.primaryGradient,
      AppButtonVariant.accent => AppColors.accentGradient,
      AppButtonVariant.gold => AppColors.goldGradient,
      AppButtonVariant.danger => AppColors.dangerGradient,
      _ => null,
    };
  }

  Color get _flatColor {
    if (!_enabled) return AppColors.surfaceHigh;
    return switch (widget.variant) {
      AppButtonVariant.outline => Colors.transparent,
      AppButtonVariant.ghost => AppColors.surface,
      _ => AppColors.primary,
    };
  }

  Color get _foreground {
    if (!_enabled) return AppColors.textMuted;
    return switch (widget.variant) {
      AppButtonVariant.gold => const Color(0xFF3A2600),
      AppButtonVariant.accent => const Color(0xFF00201C),
      AppButtonVariant.outline => AppColors.textPrimary,
      AppButtonVariant.ghost => AppColors.textPrimary,
      _ => Colors.white,
    };
  }

  Color? get _glow {
    if (!_enabled || _pressed) return null;
    return switch (widget.variant) {
      AppButtonVariant.primary => AppColors.primary,
      AppButtonVariant.accent => AppColors.accent,
      AppButtonVariant.gold => AppColors.gold,
      AppButtonVariant.danger => AppColors.danger,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final glow = _glow;

    final content = widget.isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation(_foreground),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: _fontSize + 4, color: _foreground),
                const SizedBox(width: AppDimens.sm),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button.copyWith(
                    fontSize: _fontSize,
                    color: _foreground,
                  ),
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTap: _enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 110),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: _height,
            width: widget.expand ? double.infinity : null,
            padding: EdgeInsets.symmetric(
              horizontal: widget.expand ? AppDimens.lg : AppDimens.xxl,
            ),
            decoration: BoxDecoration(
              gradient: _gradient,
              color: _gradient == null ? _flatColor : null,
              borderRadius: AppDimens.brMd,
              border: widget.variant == AppButtonVariant.outline
                  ? Border.all(
                      color: _enabled
                          ? AppColors.primary
                          : AppColors.surfaceStroke,
                      width: 1.6,
                    )
                  : widget.variant == AppButtonVariant.ghost
                      ? Border.all(color: AppColors.surfaceStroke)
                      : null,
              boxShadow: glow == null
                  ? null
                  : [
                      BoxShadow(
                        color: glow.withValues(alpha: 0.38),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Compact circular icon button used in app bars and the game HUD.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? background;
  final Color? foreground;
  final String? tooltip;
  final int badgeCount;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.background,
    this.foreground,
    this.tooltip,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = Material(
      color: background ?? AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size / 3),
        side: const BorderSide(color: AppColors.surfaceStroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed!();
              },
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.46,
            color: foreground ?? AppColors.textPrimary,
          ),
        ),
      ),
    );

    if (badgeCount > 0) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: AppDimens.brPill,
                border: Border.all(color: AppColors.background, width: 2),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
