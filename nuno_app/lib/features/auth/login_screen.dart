import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/app_text_field.dart';
import 'auth_controller.dart';
import 'splash_screen.dart';

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
      resizeToAvoidBottomInset: true,
      body: AppBackground(
        child: Stack(
          children: [
            const ScatteredCardsDecoration(),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.xxl,
                  vertical: AppDimens.xl,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.sizeOf(context).height -
                        MediaQuery.paddingOf(context).vertical -
                        AppDimens.huge,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppDimens.xxl),

                        // ── Brand ──────────────────────────────
                        const Center(child: NunoLogo(size: 72)),
                        const SizedBox(height: AppDimens.xl),
                        Center(
                          child: Text(
                            'NUNO',
                            style: AppTextStyles.logo.copyWith(fontSize: 40),
                          ),
                        ),
                        const SizedBox(height: AppDimens.xs),
                        Center(
                          child: Text(
                            'Welcome back, challenger',
                            style: AppTextStyles.bodySm,
                          ),
                        ),

                        const SizedBox(height: AppDimens.huge),

                        // ── Form ───────────────────────────────
                        AppTextField(
                          controller: _email,
                          label: 'Email',
                          hint: 'you@example.com',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email,
                          enabled: !auth.isBusy,
                        ),
                        const SizedBox(height: AppDimens.xl),
                        AppTextField(
                          controller: _password,
                          label: 'Password',
                          hint: 'Enter your password',
                          icon: Icons.lock_outline_rounded,
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          validator: (v) => Validators.required(v, 'Password'),
                          onSubmitted: (_) => _submit(),
                          enabled: !auth.isBusy,
                        ),

                        const SizedBox(height: AppDimens.xxl),

                        AppButton(
                          label: 'SIGN IN',
                          icon: Icons.sports_esports_rounded,
                          isLoading: auth.isBusy,
                          onPressed: auth.isBusy ? null : _submit,
                        ),

                        const SizedBox(height: AppDimens.xl),

                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimens.md,
                              ),
                              child: Text('NEW HERE?',
                                  style: AppTextStyles.label),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),

                        const SizedBox(height: AppDimens.xl),

                        AppButton(
                          label: 'CREATE ACCOUNT',
                          variant: AppButtonVariant.outline,
                          onPressed: auth.isBusy
                              ? null
                              : () => context.push(AppRoutes.register),
                        ),

                        const SizedBox(height: AppDimens.xxl),

                        Center(
                          child: Text(
                            'By continuing you agree to our Terms & Privacy Policy.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimens.lg),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
