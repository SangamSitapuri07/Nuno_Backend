import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/game_assets.dart';
import '../../../services/socket_events.dart';
import '../../store/cosmetics_provider.dart';

/// Screen 14 — Quick Chat / Emotes. Preset phrases on top, emoji row beneath.
class QuickChatSheet extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final phrases = QuickChat.presets.entries.toList();
    final emotes = Emotes.glyphs.entries.toList();

    // Emotes the player has unlocked in the store. Locked ones stay visible
    // but dimmed, so the shop's stock is discoverable from the table.
    final unlocked = ref.watch(equippedCosmeticsProvider).emotes;

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
                        _EmoteTile(
                          emoteKey: e.key,
                          glyph: e.value,
                          locked: !unlocked.contains(e.key),
                          onTap: () {
                            onEmote(e.key);
                            Navigator.of(context).pop();
                          },
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


/// One emote in the picker. Locked emotes are dimmed and carry a padlock
/// rather than being hidden, so the player can see what the store sells.
class _EmoteTile extends StatelessWidget {
  final String emoteKey;
  final String glyph;
  final bool locked;
  final VoidCallback onTap;

  const _EmoteTile({
    required this.emoteKey,
    required this.glyph,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = SizedBox(
      width: 46,
      height: 46,
      child: ArtImage(
        Art.emote(emoteKey) ?? '',
        width: 46,
        // Emotes without bespoke art fall back to the unicode glyph.
        fallback: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: AppDimens.brSm,
            border: Border.all(color: AppColors.surfaceStroke),
          ),
          alignment: Alignment.center,
          child: Text(glyph, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );

    if (!locked) return GestureDetector(onTap: onTap, child: tile);

    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0.30, child: tile),
        const Icon(Icons.lock_rounded, size: 16, color: Colors.white70),
      ],
    );
  }
}
