import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/auth_controller.dart';
import '../../lobby/widgets/lobby_chat.dart';
import '../game_providers.dart';

/// In-match chat, reusing the lobby chat widget.
class GameChatSheet extends ConsumerWidget {
  const GameChatSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const GameChatSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final myId = ref.watch(currentUserIdProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundAlt,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXxl)),
          border: Border(top: BorderSide(color: AppColors.surfaceStroke)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppDimens.xl,
          AppDimens.md,
          AppDimens.xl,
          AppDimens.xl,
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
            const SizedBox(height: AppDimens.lg),
            Text('Match chat', style: AppTextStyles.h3),
            const SizedBox(height: AppDimens.md),
            LobbyChat(
              messages: state.messages,
              myId: myId,
              onSend: ref.read(gameControllerProvider.notifier).sendChat,
            ),
          ],
        ),
      ),
    );
  }
}
