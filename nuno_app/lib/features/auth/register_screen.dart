import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/titled_panel.dart';
import 'auth_controller.dart';

/// Landscape registration: two form columns inside a titled panel.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String _passwordValue = '';

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await ref.read(authControllerProvider.notifier).register(
          username: _username.text,
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

    return PanelScreen(
      title: 'Create Account',
      onBack: () => context.pop(),
      maxWidth: 640,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        AppTextField(
                          controller: _username,
                          label: 'Username',
                          hint: '3-20 characters',
                          icon: Icons.person_outline_rounded,
                          maxLength: 20,
                          validator: Validators.username,
                          enabled: !auth.isBusy,
                        ),
                        const SizedBox(height: AppDimens.md),
                        AppTextField(
                          controller: _email,
                          label: 'Email',
                          hint: 'you@example.com',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email,
                          enabled: !auth.isBusy,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimens.lg),
                  Expanded(
                    child: Column(
                      children: [
                        AppTextField(
                          controller: _password,
                          label: 'Password',
                          hint: 'Strong password',
                          icon: Icons.lock_outline_rounded,
                          obscure: true,
                          validator: Validators.password,
                          onChanged: (v) =>
                              setState(() => _passwordValue = v),
                          enabled: !auth.isBusy,
                        ),
                        const SizedBox(height: AppDimens.md),
                        AppTextField(
                          controller: _confirm,
                          label: 'Confirm password',
                          hint: 'Repeat password',
                          icon: Icons.lock_reset_rounded,
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          validator: (v) => v != _password.text
                              ? 'Passwords do not match'
                              : null,
                          onSubmitted: (_) => _submit(),
                          enabled: !auth.isBusy,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              PasswordStrengthHints(password: _passwordValue),
              const SizedBox(height: AppDimens.lg),
              SizedBox(
                width: 260,
                child: AppButton(
                  label: 'CREATE ACCOUNT',
                  icon: Icons.rocket_launch_rounded,
                  variant: AppButtonVariant.gold,
                  isLoading: auth.isBusy,
                  onPressed: auth.isBusy ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
