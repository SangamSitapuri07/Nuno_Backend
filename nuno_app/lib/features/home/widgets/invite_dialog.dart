import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/player_avatar.dart';

/// Incoming game invite, shown as a card rather than a snack bar.
///
/// An invite is a decision with a deadline, and a snack bar reads as a passive
/// status message: it is easy to miss, easy to dismiss by accident, and gives
/// no sense that it will expire. This presents who is calling, the room code,
/// a visible countdown, and two deliberate choices.
class InviteDialog extends StatefulWidget {
  final String fromUsername;
  final String roomCode;
  final Duration timeout;

  const InviteDialog({
    super.key,
    required this.fromUsername,
    required this.roomCode,
    this.timeout = const Duration(seconds: 30),
  });

  /// Returns true when the invite is accepted.
  static Future<bool> show(
    BuildContext context, {
    required String fromUsername,
    required String roomCode,
  }) async {
    HapticFeedback.mediumImpact();
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.66),
      builder: (_) => InviteDialog(
        fromUsername: fromUsername,
        roomCode: roomCode,
      ),
    );
    return accepted ?? false;
  }

  @override
  State<InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<InviteDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  late int _remaining = widget.timeout.inSeconds;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      // Expire rather than lingering: the room may well have started.
      if (_remaining <= 0) Navigator.of(context).pop(false);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: CurvedAnimation(parent: _entry, curve: Curves.easeOutBack),
        child: FadeTransition(
          opacity: _entry,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(AppDimens.lg),
              decoration: BoxDecoration(
                color: AppColors.backgroundAlt,
                borderRadius: AppDimens.brLg,
                border: Border.all(color: AppColors.gold, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.22),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      PlayerAvatar(username: widget.fromUsername, size: 42),
                      const SizedBox(width: AppDimens.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'GAME INVITE',
                              style: AppTextStyles.label
                                  .copyWith(color: AppColors.gold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.fromUsername} wants to play',
                              style: AppTextStyles.h4,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Countdown, so the deadline is visible.
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: _remaining / widget.timeout.inSeconds,
                              strokeWidth: 2.5,
                              backgroundColor: AppColors.surfaceHigh,
                              valueColor: AlwaysStoppedAnimation(
                                _remaining <= 5
                                    ? AppColors.danger
                                    : AppColors.gold,
                              ),
                            ),
                            Text(
                              '$_remaining',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppDimens.md),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimens.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: AppDimens.brSm,
                      border: Border.all(color: AppColors.surfaceStroke),
                    ),
                    child: Column(
                      children: [
                        Text('ROOM CODE', style: AppTextStyles.label),
                        Text(
                          widget.roomCode,
                          style: AppTextStyles.h3.copyWith(letterSpacing: 5),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimens.lg),

                  Row(
                    children: [
                      Expanded(
                        child: _Action(
                          label: 'DECLINE',
                          color: AppColors.surfaceHigh,
                          onTap: () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const SizedBox(width: AppDimens.md),
                      Expanded(
                        flex: 2,
                        child: _Action(
                          label: 'JOIN',
                          color: AppColors.green,
                          icon: Icons.login_rounded,
                          onTap: () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ],
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

class _Action extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback onTap;

  const _Action({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: AppDimens.brSm,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTextStyles.label.copyWith(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
