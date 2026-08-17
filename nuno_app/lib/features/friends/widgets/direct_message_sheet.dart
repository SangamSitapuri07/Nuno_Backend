import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/player_avatar.dart';
// PlayerOnlineStatus's `label` and `wire` come from an extension, and a Dart
// extension is only in scope through a direct import of its own library -
// reaching the enum via social_models.dart is not enough.
import '../../../data/models/enums.dart';
import '../../../data/models/social_models.dart';
import '../../../services/socket_events.dart';

/// One-to-one chat with a friend, over the existing `dm.send` relay.
///
/// History is per-session: the backend forwards messages but does not store
/// them, so this shows the conversation for as long as the app is open.
class DirectMessageSheet extends ConsumerStatefulWidget {
  final Friend friend;

  const DirectMessageSheet({super.key, required this.friend});

  static Future<void> show(BuildContext context, {required Friend friend}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DirectMessageSheet(friend: friend),
    );
  }

  @override
  ConsumerState<DirectMessageSheet> createState() => _DirectMessageSheetState();
}

class _DirectMessageSheetState extends ConsumerState<DirectMessageSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<DmMessage> _messages = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();

    final socket = ref.read(socketServiceProvider);

    // Seed with anything already exchanged this session.
    _messages.addAll(
      ref.read(dmHistoryProvider)[widget.friend.userId] ?? const [],
    );

    _sub = socket.on(SocketEvents.dmReceived).listen((payload) {
      if (payload['fromUserId']?.toString() != widget.friend.userId) return;
      _append(
        DmMessage(
          text: payload['message']?.toString() ?? '',
          mine: false,
        ),
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _append(DmMessage message) {
    if (!mounted) return;
    setState(() => _messages.add(message));

    // Keep the shared history in step, so reopening the sheet is continuous.
    final history = ref.read(dmHistoryProvider);
    history[widget.friend.userId] = List.of(_messages);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || text.length > 500) return;

    ref.read(socketServiceProvider).emit(SocketEvents.dmSend, {
      'targetUserId': widget.friend.userId,
      'message': text,
    });

    _controller.clear();
    _append(DmMessage(text: text, mine: true));
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.72,
        decoration: const BoxDecoration(
          color: AppColors.backgroundAlt,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXxl)),
          border: Border(top: BorderSide(color: AppColors.surfaceStroke)),
        ),
        child: Column(
          children: [
            // ── Header ────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppDimens.md),
              child: Row(
                children: [
                  PlayerAvatar(
                    username: widget.friend.username,
                    avatarUrl: widget.friend.avatarUrl,
                    status: widget.friend.status,
                    size: 34,
                  ),
                  const SizedBox(width: AppDimens.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.friend.username,
                            style: AppTextStyles.h4),
                        Text(
                          widget.friend.status.label,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.forStatus(
                                widget.friend.status.wire),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.textMuted,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.surfaceStroke),

            // ── Messages ──────────────────────────────
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        'Say hello to ${widget.friend.username}',
                        style: AppTextStyles.bodySm
                            .copyWith(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(AppDimens.md),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _Bubble(message: _messages[i]),
                    ),
            ),

            // ── Composer ──────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimens.md,
                AppDimens.sm,
                AppDimens.md,
                MediaQuery.paddingOf(context).bottom + AppDimens.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: 500,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: AppTextStyles.body,
                      cursorColor: AppColors.gold,
                      decoration: const InputDecoration(
                        counterText: '',
                        isDense: true,
                        hintText: 'Message',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppDimens.md,
                          vertical: AppDimens.md,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.sm),
                  Material(
                    color: AppColors.primary,
                    borderRadius: AppDimens.brSm,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _send,
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.send_rounded,
                            size: 18, color: Colors.white),
                      ),
                    ),
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

class _Bubble extends StatelessWidget {
  final DmMessage message;

  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          message.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimens.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: AppDimens.sm,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.6,
        ),
        decoration: BoxDecoration(
          color: message.mine ? AppColors.primary : AppColors.surfaceHigh,
          borderRadius: AppDimens.brMd,
        ),
        child: Text(
          message.text,
          style: AppTextStyles.body.copyWith(fontSize: 13),
        ),
      ),
    );
  }
}

/// Public because [dmHistoryProvider] names it in its type argument.
class DmMessage {
  final String text;
  final bool mine;

  const DmMessage({required this.text, required this.mine});
}

/// Session-scoped conversation history, keyed by friend id.
final dmHistoryProvider = Provider<Map<String, List<DmMessage>>>(
  (ref) => <String, List<DmMessage>>{},
);
