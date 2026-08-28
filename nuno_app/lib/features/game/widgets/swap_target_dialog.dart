import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../data/models/game_state.dart';

/// Asks who to swap hands with when a 7 is played under the seven-zero
/// house rule.
///
/// Card counts are shown, because that is the entire basis of the decision -
/// you are swapping to get rid of a big hand or to steal a small one.
class SwapTargetDialog extends StatelessWidget {
  final GameState game;
  final String myId;

  const SwapTargetDialog({super.key, required this.game, required this.myId});

  /// Returns the chosen player's id, or null if dismissed.
  static Future<String?> show(
    BuildContext context, {
    required GameState game,
    required String myId,
  }) =>
      showDialog<String>(
        context: context,
        builder: (_) => SwapTargetDialog(game: game, myId: myId),
      );

  @override
  Widget build(BuildContext context) {
    final others = game.players.where((id) => id != myId).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(AppDimens.md),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppDimens.brLg,
          border: Border.all(color: AppColors.surfaceStroke),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SWAP HANDS WITH', style: AppTextStyles.label),
            const SizedBox(height: AppDimens.sm),
            Wrap(
              spacing: AppDimens.md,
              runSpacing: AppDimens.md,
              alignment: WrapAlignment.center,
              children: [
                for (final id in others)
                  _Target(
                    name: game.playerNames[id]?.username ?? 'Player',
                    cards: game.playerCardCounts[id] ?? 0,
                    onTap: () => Navigator.pop(context, id),
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.sm),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Play it without swapping',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Target extends StatelessWidget {
  final String name;
  final int cards;
  final VoidCallback onTap;

  const _Target({
    required this.name,
    required this.cards,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 82,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerAvatar(username: name, size: 44),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
            Text(
              '$cards cards',
              style: AppTextStyles.caption.copyWith(color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}
