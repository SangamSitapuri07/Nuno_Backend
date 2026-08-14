import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/social_models.dart';

/// Scrollable chat log plus composer, backed by chat.send / chat.received.
class LobbyChat extends StatefulWidget {
  final List<ChatMessage> messages;
  final String? myId;
  final void Function(String message) onSend;

  const LobbyChat({
    super.key,
    required this.messages,
    required this.myId,
    required this.onSend,
  });

  @override
  State<LobbyChat> createState() => _LobbyChatState();
}

class _LobbyChatState extends State<LobbyChat> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant LobbyChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDimens.brLg,
        border: Border.all(color: AppColors.surfaceStroke),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: widget.messages.isEmpty
                ? Center(
                    child: Text(
                      'Say hello to your opponents',
                      style: AppTextStyles.caption,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppDimens.md),
                    itemCount: widget.messages.length,
                    itemBuilder: (context, i) {
                      final m = widget.messages[i];
                      return _ChatBubble(
                        message: m,
                        isMine: m.userId == widget.myId,
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppDimens.sm),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: AppConfig.maxChatLength,
                    style: AppTextStyles.body,
                    cursorColor: AppColors.accent,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.lg,
                        vertical: AppDimens.md,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppDimens.brPill,
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppDimens.brPill,
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: AppDimens.brPill,
                        borderSide:
                            BorderSide(color: AppColors.primary, width: 1.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.sm),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  const _ChatBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.md,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppDimens.brPill,
            ),
            child: Text(
              message.message,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.sm),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 2),
              child: Text(message.username, style: AppTextStyles.caption),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.6,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.md,
              vertical: AppDimens.sm,
            ),
            decoration: BoxDecoration(
              color: isMine ? AppColors.primary : AppColors.background,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppDimens.radiusMd),
                topRight: const Radius.circular(AppDimens.radiusMd),
                bottomLeft: Radius.circular(isMine ? AppDimens.radiusMd : 4),
                bottomRight: Radius.circular(isMine ? 4 : AppDimens.radiusMd),
              ),
            ),
            child: Text(
              message.message,
              style: AppTextStyles.body.copyWith(
                color: isMine ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
