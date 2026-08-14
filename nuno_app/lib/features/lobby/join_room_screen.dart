import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/game_assets.dart';
import '../../core/widgets/titled_panel.dart';
import 'lobby_providers.dart';

/// Screen 6 — Join Room: code display plus an on-screen numeric keypad.
class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  static const _maxLength = 6;
  String _code = '';

  void _tap(String key) {
    HapticFeedback.selectionClick();
    if (_code.length >= _maxLength) return;
    setState(() => _code += key);
  }

  void _backspace() {
    HapticFeedback.selectionClick();
    if (_code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  void _submit() {
    if (_code.length < _maxLength) return;
    ref.read(lobbyControllerProvider.notifier).joinRoom(_code);
    context.pushReplacement(AppRoutes.lobby);
  }

  @override
  Widget build(BuildContext context) {
    final complete = _code.length == _maxLength;

    return PanelScreen(
      title: 'Join Room',
      onBack: () => context.pop(),
      maxWidth: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ENTER ROOM CODE', style: AppTextStyles.label),
          const SizedBox(height: AppDimens.sm),

          // Code display.
          Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: AppDimens.brSm,
              border: Border.all(
                color: complete ? AppColors.gold : AppColors.surfaceStroke,
              ),
            ),
            child: Text(
              _code.isEmpty ? 'Enter 6 character code' : _code,
              style: _code.isEmpty
                  ? AppTextStyles.body.copyWith(color: AppColors.textMuted)
                  : AppTextStyles.h3.copyWith(letterSpacing: 8),
            ),
          ),

          const SizedBox(height: AppDimens.md),

          // Keypad: 1-9, then backspace / 0 / confirm.
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.sm),
              child: Row(
                children: [
                  for (final key in row) ...[
                    Expanded(child: _Key(label: key, onTap: () => _tap(key))),
                    if (key != row.last) const SizedBox(width: AppDimens.sm),
                  ],
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _Key(
                  icon: Icons.backspace_outlined,
                  onTap: _backspace,
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(child: _Key(label: '0', onTap: () => _tap('0'))),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: complete
                    ? ArtButton(
                        asset: Art.btnJoin,
                        fallbackLabel: 'JOIN',
                        width: 110,
                        onTap: _submit,
                      )
                    : const _Key(icon: Icons.check_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool highlight;

  const _Key({this.label, this.icon, this.onTap, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Material(
      color: highlight ? AppColors.gold : AppColors.surfaceHigh,
      borderRadius: AppDimens.brSm,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppDimens.brSm,
            border: Border.all(
              color: highlight ? AppColors.gold : AppColors.surfaceStroke,
            ),
          ),
          child: label != null
              ? Text(
                  label!,
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textPrimary,
                  ),
                )
              : Icon(
                  icon,
                  size: 18,
                  color: highlight
                      ? const Color(0xFF3A2600)
                      : (enabled
                          ? AppColors.textSecondary
                          : AppColors.textMuted),
                ),
        ),
      ),
    );
  }
}
