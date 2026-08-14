import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/uno_logo.dart';
import 'auth_controller.dart';

/// Landscape sign-in: branding on the left, form on the right.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await ref.read(authControllerProvider.notifier).login(
          email: _email.text,
          password: _password.text,
        );

    if (!mounted) return;
    if (ok) {
      context.go(AppRoutes.home);
    } else {
      final error = ref.read(authControllerProvider).error;
      if (error != null) AppSnack.error(context, error);
    }
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

              // ── Form ─────────────────────────────
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.xxl,
                      vertical: AppDimens.lg,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('SIGN IN', style: AppTextStyles.h2),
                            const SizedBox(height: AppDimens.lg),
                            AppTextField(
                              controller: _email,
                              label: 'Email',
                              hint: 'you@example.com',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email,
                              enabled: !auth.isBusy,
                            ),
                            const SizedBox(height: AppDimens.md),
                            AppTextField(
                              controller: _password,
                              label: 'Password',
                              hint: 'Enter your password',
                              icon: Icons.lock_outline_rounded,
                              obscure: true,
                              textInputAction: TextInputAction.done,
                              validator: (v) =>
                                  Validators.required(v, 'Password'),
                              onSubmitted: (_) => _submit(),
                              enabled: !auth.isBusy,
                            ),
                            const SizedBox(height: AppDimens.lg),
                            AppButton(
                              label: 'SIGN IN',
                              icon: Icons.sports_esports_rounded,
                              isLoading: auth.isBusy,
                              onPressed: auth.isBusy ? null : _submit,
                            ),
                            const SizedBox(height: AppDimens.sm),
                            TextButton(
                              onPressed: auth.isBusy
                                  ? null
                                  : () => context.push(AppRoutes.register),
                              child: Text(
                                'Create an account',
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.gold,
                                ),
                              ),
                            ),
                          ],
                        ),
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
