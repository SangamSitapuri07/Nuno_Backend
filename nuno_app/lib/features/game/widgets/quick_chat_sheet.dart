import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/socket_events.dart';

/// Screen 14 — Quick Chat / Emotes. Preset phrases on top, emoji row beneath.
class QuickChatSheet extends StatelessWidget {
  final void Function(String) onEmote;
  final void Function(String) onQuickChat;

  const QuickChatSheet({
    super.key,
    required this.onEmote,
    required this.onQuickChat,
  });

  static Future<void> show(
    BuildContext context, {
    required void Function(String) onEmote,
    required void Function(String) onQuickChat,
  }) =>
      showDialog(
        context: context,
        builder: (_) => QuickChatSheet(
          onEmote: onEmote,
          onQuickChat: onQuickChat,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final phrases = QuickChat.presets.entries.toList();
    final emotes = Emotes.glyphs.entries.toList();

    return Dialog(
      insetPadding: const EdgeInsets.all(AppDimens.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: AppDimens.panelHeaderHeight,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.panelHeader,
                border: Border(
                  bottom: BorderSide(color: AppColors.surfaceStroke),
                ),
              ),
              child: Text('QUICK CHAT / EMOTES',
                  style: AppTextStyles.panelTitle),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimens.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Phrase grid (3 per row).
                  Wrap(
                    spacing: AppDimens.sm,
                    runSpacing: AppDimens.sm,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final p in phrases)
                        _PhraseChip(
                          label: p.value,
                          onTap: () {
                            onQuickChat(p.key);
                            Navigator.of(context).pop();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.md),
                  const Divider(height: 1),
                  const SizedBox(height: AppDimens.md),
                  // Emote row.
                  Wrap(
                    spacing: AppDimens.sm,
                    runSpacing: AppDimens.sm,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final e in emotes)
                        GestureDetector(
                          onTap: () {
                            onEmote(e.key);
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHigh,
                              borderRadius: AppDimens.brSm,
                              border:
                                  Border.all(color: AppColors.surfaceStroke),
                            ),
                            alignment: Alignment.center,
                            child: Text(e.value,
                                style: const TextStyle(fontSize: 20)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhraseChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PhraseChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: AppDimens.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: AppDimens.brSm,
          border: Border.all(color: AppColors.surfaceStroke),
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(fontSize: 12),
        ),
      ),
    );
  }
}
