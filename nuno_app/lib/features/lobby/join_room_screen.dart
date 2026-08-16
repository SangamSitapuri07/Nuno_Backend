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

/// Length of a room code, matching generateRoomCode() in
/// src/utils/generateId.ts — five characters drawn from A-Z and 0-9.
const int kRoomCodeLength = 5;

/// Screen 6 — Join Room.
///
/// Codes mix letters and digits, so this takes text input rather than the
/// numeric keypad it used to show: that keypad could only ever produce digits,
/// and it required six characters when a code is five, so the confirm button
/// never became enabled.
class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  String get _code => _controller.text;
  bool get _complete => _code.length == kRoomCodeLength;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    // Open the keyboard straight away; the only thing to do here is type.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_complete) return;
    HapticFeedback.mediumImpact();
    ref.read(lobbyControllerProvider.notifier).joinRoom(_code);
    context.pushReplacement(AppRoutes.lobby);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null) return;

    // Accept a pasted code with stray spaces or punctuation around it.
    final cleaned = text
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .padRight(0);
    if (cleaned.isEmpty) return;

    _controller.text = cleaned.length > kRoomCodeLength
        ? cleaned.substring(0, kRoomCodeLength)
        : cleaned;
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
  }

  @override
  Widget build(BuildContext context) {
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

          // The real (invisible) field sits behind the boxes below, so the
          // system keyboard — letters included — does the input while the
          // display stays styled.
          Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: kRoomCodeLength,
                  textCapitalization: TextCapitalization.characters,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _submit(),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                    _UpperCaseFormatter(),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _focus.requestFocus,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < kRoomCodeLength; i++) ...[
                      _CodeBox(
                        character: i < _code.length ? _code[i] : null,
                        focused: i == _code.length && _focus.hasFocus,
                      ),
                      if (i != kRoomCodeLength - 1)
                        const SizedBox(width: AppDimens.sm),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.md),

          Text(
            'Codes are $kRoomCodeLength characters — letters and numbers.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),

          const SizedBox(height: AppDimens.xl),

          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste_rounded, size: 16),
                  label: const Text('Paste'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: Opacity(
                  opacity: _complete ? 1 : 0.4,
                  child: ArtButton(
                    asset: Art.btnJoin,
                    fallbackLabel: 'JOIN',
                    width: 130,
                    onTap: _complete ? _submit : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Room codes are stored upper-case, so normalise as the user types rather
/// than relying on the keyboard's shift state.
class _UpperCaseFormatter extends TextInputFormatter {
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

/// One character cell of the code display.
class _CodeBox extends StatelessWidget {
  final String? character;
  final bool focused;

  const _CodeBox({this.character, this.focused = false});

  @override
  Widget build(BuildContext context) {
    final filled = character != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 46,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppDimens.brSm,
        border: Border.all(
          color: focused
              ? AppColors.gold
              : (filled ? AppColors.primary : AppColors.surfaceStroke),
          width: focused ? 2 : 1,
        ),
      ),
      child: Text(
        character ?? '',
        style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}
