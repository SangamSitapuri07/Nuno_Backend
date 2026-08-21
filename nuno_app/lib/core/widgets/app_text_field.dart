import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// Labelled text field matching the app's form styling.
class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final int? maxLength;
  final bool autofocus;
  final bool enabled;

  /// Restricts what can be typed, e.g. a username's allowed characters.
  final List<TextInputFormatter>? inputFormatters;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLength,
    this.autofocus = false,
    this.enabled = true,
    this.inputFormatters,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: AppDimens.sm),
          child: Text(widget.label.toUpperCase(), style: AppTextStyles.label),
        ),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          maxLength: widget.maxLength,
          inputFormatters: widget.inputFormatters,
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          style: AppTextStyles.bodyLg,
          cursorColor: AppColors.accent,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: widget.hint,
            counterText: '',
            prefixIcon: widget.icon == null
                ? null
                : Icon(widget.icon, size: 20, color: AppColors.textMuted),
            suffixIcon: widget.obscure
                ? IconButton(
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Validators aligned with src/auth/auth.validation.ts (zod schemas).
class Validators {
  Validators._();

  static String? email(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Email is required';
    final re = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!re.hasMatch(value)) return 'Enter a valid email address';
    if (value.length > 255) return 'Email is too long';
    return null;
  }

  static String? username(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Username is required';
    if (value.length < 3) return 'At least 3 characters';
    if (value.length > 20) return 'At most 20 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Letters, numbers and underscores only';
    }
    return null;
  }

  /// Matches the backend's strong-password rules exactly.
  static String? password(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'At least 8 characters';
    if (value.length > 128) return 'At most 128 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Add an uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Add a lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Add a number';
    if (!RegExp(r'[^a-zA-Z0-9]').hasMatch(value)) {
      return 'Add a special character';
    }
    return null;
  }

  static String? required(String? v, [String field = 'This field']) =>
      (v?.trim().isEmpty ?? true) ? '$field is required' : null;
}

/// Live checklist of the backend password rules.
class PasswordStrengthHints extends StatelessWidget {
  final String password;

  const PasswordStrengthHints({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final rules = <String, bool>{
      '8+ characters': password.length >= 8,
      'Uppercase': RegExp(r'[A-Z]').hasMatch(password),
      'Lowercase': RegExp(r'[a-z]').hasMatch(password),
      'Number': RegExp(r'[0-9]').hasMatch(password),
      'Symbol': RegExp(r'[^a-zA-Z0-9]').hasMatch(password),
    };

    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.sm),
      child: Wrap(
        spacing: AppDimens.sm,
        runSpacing: AppDimens.sm,
        children: rules.entries.map((e) {
          final ok = e.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ok
                  ? AppColors.success.withValues(alpha: 0.14)
                  : AppColors.surface,
              borderRadius: AppDimens.brPill,
              border: Border.all(
                color: ok
                    ? AppColors.success.withValues(alpha: 0.5)
                    : AppColors.surfaceStroke,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ok
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 12,
                  color: ok ? AppColors.success : AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  e.key,
                  style: AppTextStyles.caption.copyWith(
                    color: ok ? AppColors.success : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
