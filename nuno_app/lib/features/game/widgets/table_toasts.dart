import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../game_providers.dart';

/// Floating stack of transient events (emotes, UNO calls, quick chat) shown
/// over the table.
class TableToasts extends StatelessWidget {
  final List<TableToast> toasts;

  const TableToasts({super.key, required this.toasts});

  @override
  Widget build(BuildContext context) {
    if (toasts.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 96,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Column(
          children: [
            for (final toast in toasts.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.sm),
                child: _ToastBubble(key: ValueKey(toast.id), toast: toast),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToastBubble extends StatefulWidget {
  final TableToast toast;

  const _ToastBubble({super.key, required this.toast});

  @override
  State<_ToastBubble> createState() => _ToastBubbleState();
}

class _ToastBubbleState extends State<_ToastBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);

    return FadeTransition(
      opacity: _controller,
      child: ScaleTransition(
        scale: Tween(begin: 0.7, end: 1.0).animate(curved),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.toast.isEmote ? AppDimens.md : AppDimens.lg,
            vertical: AppDimens.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: AppDimens.brPill,
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.toast.username,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Text(
                widget.toast.text,
                style: widget.toast.isEmote
                    ? const TextStyle(fontSize: 22)
                    : AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
