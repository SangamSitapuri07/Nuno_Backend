import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/uno_logo.dart';
import 'auth_controller.dart';

/// Sign-in.
///
/// Google is the only way in. Email and password are gone: they meant a
/// player had to invent and remember a password for a card game, and every
/// account created that way needed its own reset and verification flow that
/// did not exist. One tap replaces all of it, and the server creates the
/// account on first use.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  Future<void> _google() async {
    final ok = await ref.read(authControllerProvider.notifier).signInWithGoogle();

    if (!mounted) return;
    if (ok) {
      // Where to go next is decided by the router: a brand-new account still
      // has to choose a username.
      final auth = ref.read(authControllerProvider);
      context.go(auth.needsUsername ? AppRoutes.chooseUsername : AppRoutes.home);
      return;
    }

    final error = ref.read(authControllerProvider).error;
    // A dismissed account picker leaves no error, and must stay silent.
    if (error != null) AppSnack.error(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.5, -0.3),
            radius: 1.1,
            colors: [Color(0xFF1B1440), Color(0xFF07081A)],
          ),
        ),
        child: SafeArea(
          // Left inset excluded: in landscape it is the display
          // cutout, and honouring it indents the whole screen.
          left: false,
          child: Row(
            children: [
              // ── Branding ─────────────────────────
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const UnoLogo(width: 210),
                      const SizedBox(height: AppDimens.xl),
                      Text(
                        'Welcome back, challenger',
                        style: AppTextStyles.bodySm,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Sign in ──────────────────────────
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.xxl,
                      vertical: AppDimens.lg,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('SIGN IN', style: AppTextStyles.h2),
                          const SizedBox(height: AppDimens.sm),
                          Text(
                            'Use your Google account. We never see your '
                            'password.',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: AppDimens.xl),

                          _GoogleButton(
                            isLoading: auth.isBusy,
                            onTap: auth.isBusy ? null : _google,
                          ),

                          const SizedBox(height: AppDimens.lg),
                          Text(
                            'By continuing you agree to play nicely.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
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

/// Google's button: white surface, their mark, their wording.
///
/// Drawn rather than shipped as an image so it stays crisp at any size and
/// needs no extra asset.
class _GoogleButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onTap;

  const _GoogleButton({required this.isLoading, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: AppDimens.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDimens.brMd,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF4285F4)),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _GoogleMark(size: 20),
                    const SizedBox(width: AppDimens.md),
                    Text(
                      'Continue with Google',
                      style: AppTextStyles.button.copyWith(
                        color: const Color(0xFF1F1F1F),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The four-colour Google 'G'.
class _GoogleMark extends StatelessWidget {
  final double size;

  const _GoogleMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.26;
    final inner = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Four arcs in Google's colours, starting from the right-hand gap.
    const segments = <(double, double, Color)>[
      (-0.30, 1.10, Color(0xFF4285F4)), // blue
      (0.80, 1.40, Color(0xFF34A853)), // green
      (2.20, 1.30, Color(0xFFFBBC05)), // yellow
      (3.50, 1.50, Color(0xFFEA4335)), // red
    ];

    for (final (start, sweep, colour) in segments) {
      paint.color = colour;
      canvas.drawArc(inner, start, sweep, false, paint);
    }

    // The horizontal bar of the 'G'.
    final bar = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.52,
        size.height * 0.40,
        size.width * 0.46,
        stroke * 0.86,
      ),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
