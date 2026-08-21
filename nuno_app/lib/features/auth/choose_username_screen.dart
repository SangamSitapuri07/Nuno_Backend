import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/titled_panel.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_controller.dart';

/// Shown once, straight after a first Google sign-in.
///
/// A Google account arrives with a placeholder name, so this is where the
/// player claims the one other people will see. It also introduces their
/// player ID, since that is the number friends will ask them for.
class ChooseUsernameScreen extends ConsumerStatefulWidget {
  const ChooseUsernameScreen({super.key});

  @override
  ConsumerState<ChooseUsernameScreen> createState() =>
      _ChooseUsernameScreenState();
}

class _ChooseUsernameScreenState extends ConsumerState<ChooseUsernameScreen> {
  final _controller = TextEditingController();

  Timer? _debounce;
  UsernameCheck? _check;
  bool _checking = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Availability is checked as the player types, but debounced: firing a
  /// request per keystroke would put a dozen calls in flight for one name and
  /// let an earlier reply overwrite a later one.
  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _check = null;
      _checking = value.trim().length >= 3;
    });

    if (value.trim().length < 3) return;

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final query = value.trim();
      try {
        final result =
            await ref.read(authControllerProvider.notifier).checkUsername(query);
        // Ignore a reply that arrived after the field moved on.
        if (!mounted || _controller.text.trim() != query) return;
        setState(() {
          _check = result;
          _checking = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _checking = false);
      }
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final name = _controller.text.trim();
    if (name.length < 3) return;

    final ok = await ref.read(authControllerProvider.notifier).setUsername(name);

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
    final uid = auth.profile?.uid ?? '';
    final name = _controller.text.trim();

    final canSubmit =
        name.length >= 3 && (_check?.available ?? false) && !auth.isBusy;

    return PanelScreen(
      title: 'Choose your name',
      fillHeight: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── The name ────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'This is how other players will see you.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppDimens.md),
                AppTextField(
                  controller: _controller,
                  label: 'Username',
                  hint: '3-20 letters, numbers or _',
                  onChanged: _onChanged,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_]')),
                    LengthLimitingTextInputFormatter(20),
                  ],
                ),
                const SizedBox(height: AppDimens.sm),
                _Availability(
                  name: name,
                  checking: _checking,
                  check: _check,
                ),
                const Spacer(),
                AppButton(
                  label: 'CONTINUE',
                  variant: AppButtonVariant.gold,
                  size: AppButtonSize.small,
                  isLoading: auth.isBusy,
                  onPressed: canSubmit ? _submit : null,
                ),
              ],
            ),
          ),

          const SizedBox(width: AppDimens.lg),

          // ── The player ID ───────────────────────
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppDimens.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: AppDimens.brMd,
                border: Border.all(color: AppColors.surfaceStroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('YOUR PLAYER ID',
                      style: AppTextStyles.label
                          .copyWith(color: AppColors.gold)),
                  const SizedBox(height: AppDimens.sm),
                  SelectableText(
                    uid.isEmpty ? '----------' : uid,
                    style: AppTextStyles.h2.copyWith(
                      letterSpacing: 2.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: AppDimens.sm),
                  Text(
                    'Friends add you with this number. It never changes, '
                    'even if you rename yourself later.',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The line under the field: too short, checking, taken, or free.
class _Availability extends StatelessWidget {
  final String name;
  final bool checking;
  final UsernameCheck? check;

  const _Availability({
    required this.name,
    required this.checking,
    this.check,
  });

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty) return const SizedBox(height: 18);

    if (name.length < 3) {
      return _line(
        Icons.info_outline_rounded,
        AppColors.textMuted,
        'At least 3 characters.',
      );
    }

    if (checking) {
      return Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 6),
          Text('Checking...', style: AppTextStyles.caption),
        ],
      );
    }

    final result = check;
    if (result == null) return const SizedBox(height: 18);

    return result.available
        ? _line(Icons.check_circle_rounded, AppColors.green, 'Available')
        : _line(
            Icons.cancel_rounded,
            AppColors.danger,
            result.reason ?? 'Not available',
          );
  }

  Widget _line(IconData icon, Color colour, String text) => Row(
        children: [
          Icon(icon, size: 13, color: colour),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(color: colour),
            ),
          ),
        ],
      );
}
