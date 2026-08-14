import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../lobby/lobby_providers.dart';

/// Bottom sheet for joining a private room by its code.
class JoinRoomSheet extends ConsumerStatefulWidget {
  const JoinRoomSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const JoinRoomSheet(),
      );

  @override
  ConsumerState<JoinRoomSheet> createState() => _JoinRoomSheetState();
}

class _JoinRoomSheetState extends ConsumerState<JoinRoomSheet> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _join() {
    final code = _controller.text.trim().toUpperCase();
    if (code.length < 4) return;

    setState(() => _busy = true);
    ref.read(lobbyControllerProvider.notifier).joinRoom(code);
    Navigator.of(context).pop();
    context.push(AppRoutes.lobby);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundAlt,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusXxl),
          ),
          border: Border(
            top: BorderSide(color: AppColors.surfaceStroke),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppDimens.xxl,
          AppDimens.md,
          AppDimens.xxl,
          AppDimens.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceStroke,
                  borderRadius: AppDimens.brPill,
                ),
              ),
            ),
            const SizedBox(height: AppDimens.xl),
            Text('Join a room', style: AppTextStyles.h2),
            const SizedBox(height: AppDimens.xs),
            Text(
              'Enter the code your friend shared with you.',
              style: AppTextStyles.bodySm,
            ),
            const SizedBox(height: AppDimens.xxl),
            TextField(
              controller: _controller,
              autofocus: true,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              inputFormatters: [
                UpperCaseTextFormatter(),
                FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
              ],
              style: AppTextStyles.h1.copyWith(letterSpacing: 8),
              cursorColor: AppColors.accent,
              decoration: const InputDecoration(
                hintText: 'CODE',
                counterText: '',
              ),
              onSubmitted: (_) => _join(),
            ),
            const SizedBox(height: AppDimens.xl),
            AppButton(
              label: 'JOIN ROOM',
              icon: Icons.login_rounded,
              isLoading: _busy,
              onPressed: _join,
            ),
          ],
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      TextEditingValue(
        text: newValue.text.toUpperCase(),
        selection: newValue.selection,
      );
}
