import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/uno_logo.dart';

/// Top-left cluster: NUNO badge, room code / mode card, and a ping chip.
class GameTopLeft extends StatelessWidget {
  final String roomCode;
  final String mode;
  final int pingMs;

  const GameTopLeft({
    super.key,
    required this.roomCode,
    required this.mode,
    this.pingMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const UnoLogo(width: 56),
            const SizedBox(width: AppDimens.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.30),
                borderRadius: AppDimens.brSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Room Code: ',
                        style: AppTextStyles.bodySm.copyWith(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        roomCode,
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Text(
                        'Mode: ',
                        style: AppTextStyles.bodySm.copyWith(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        mode,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: AppDimens.sm),

        // Ping chip
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.sm,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.30),
            borderRadius: AppDimens.brPill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_rounded,
                size: 11,
                color: pingMs < 100 ? AppColors.green : AppColors.warning,
              ),
              const SizedBox(width: 5),
              Text(
                '$pingMs' 'ms',
                style: AppTextStyles.body.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: pingMs < 100 ? AppColors.green : AppColors.warning,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Top-right cluster: circular action buttons over a LEAVE ROOM pill.
class GameTopRight extends StatelessWidget {
  final VoidCallback onChat;
  final VoidCallback onMic;
  final VoidCallback onSound;
  final VoidCallback onMenu;
  final VoidCallback onLeave;
  final bool micEnabled;
  final bool soundEnabled;

  const GameTopRight({
    super.key,
    required this.onChat,
    required this.onMic,
    required this.onSound,
    required this.onMenu,
    required this.onLeave,
    this.micEnabled = true,
    this.soundEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoundButton(icon: Icons.chat_bubble_rounded, onTap: onChat),
            const SizedBox(width: AppDimens.sm),
            _RoundButton(
              icon: micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
              onTap: onMic,
            ),
            const SizedBox(width: AppDimens.sm),
            _RoundButton(
              icon: soundEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              onTap: onSound,
            ),
            const SizedBox(width: AppDimens.sm),
            _RoundButton(icon: Icons.menu_rounded, onTap: onMenu),
          ],
        ),
        const SizedBox(height: AppDimens.sm),
        GestureDetector(
          onTap: onLeave,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.xl,
              vertical: AppDimens.sm,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF5A4E), Color(0xFFE8332B)],
              ),
              borderRadius: AppDimens.brPill,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              'LEAVE ROOM',
              style: AppTextStyles.button.copyWith(
                fontSize: 11,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          // A translucent tint instead of a near-opaque black disc: the
          // dark circles read as heavy blobs against the table art and
          // took more room than the icons needed.
          color: Colors.white.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}

/// Circular countdown in the lower-right of the table.
class TurnTimerDial extends StatelessWidget {
  final int seconds;
  final int totalSeconds;

  const TurnTimerDial({
    super.key,
    required this.seconds,
    this.totalSeconds = 20,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (seconds / totalSeconds).clamp(0.0, 1.0);
    final urgent = seconds <= 5;

    return SizedBox(
      width: 66,
      height: 66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(
            width: 62,
            height: 62,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(
                urgent ? AppColors.danger : AppColors.green,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$seconds',
                style: AppTextStyles.h2.copyWith(
                  color: Colors.white,
                  fontSize: 22,
                  height: 1,
                ),
              ),
              Text(
                'sec',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Current Card" readout: coloured dot plus the colour name.
class CurrentCardChip extends StatelessWidget {
  final String value;
  final Color color;
  final String colorName;

  const CurrentCardChip({
    super.key,
    required this.value,
    required this.color,
    required this.colorName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: AppDimens.brMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Card',
            style: AppTextStyles.bodySm.copyWith(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  value,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Text(
                colorName,
                style: AppTextStyles.body.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
