import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/titled_panel.dart';
import '../../data/models/enums.dart';
import '../auth/auth_controller.dart';
import 'lobby_providers.dart';

/// Screen 4 — Create Room: name, max-players selector (2–7) and rules.
class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _name = TextEditingController();
  int _maxPlayers = 4;
  bool _voiceEnabled = true;
  bool _stacking = true;

  @override
  void initState() {
    super.initState();
    final username = ref.read(currentProfileProvider)?.username;
    _name.text = username == null ? 'New Room' : "$username's Room";
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    ref.read(lobbyControllerProvider.notifier).createRoom(
          mode: GameMode.private,
          maxPlayers: _maxPlayers,
          voiceEnabled: _voiceEnabled,
        );
    context.pushReplacement(AppRoutes.lobby);
  }

  @override
  Widget build(BuildContext context) {
    return PanelScreen(
      title: 'Create Room',
      onBack: () => context.pop(),
      maxWidth: 520,
      // PanelScreen's body already scrolls.
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ROOM NAME', style: AppTextStyles.label),
            const SizedBox(height: AppDimens.sm),
            TextField(
              controller: _name,
              maxLength: 30,
              style: AppTextStyles.body,
              cursorColor: AppColors.gold,
              decoration: const InputDecoration(
                counterText: '',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppDimens.md,
                  vertical: AppDimens.md,
                ),
              ),
            ),

            const SizedBox(height: AppDimens.lg),

            Text('MAX PLAYERS', style: AppTextStyles.label),
            const SizedBox(height: AppDimens.sm),
            Row(
              children: [
                for (final n in [2, 3, 4, 5, 6, 7, 8]) ...[
                  Expanded(
                    child: _PlayerCountChip(
                      count: n,
                      selected: _maxPlayers == n,
                      onTap: () => setState(() => _maxPlayers = n),
                    ),
                  ),
                  if (n != 8) const SizedBox(width: AppDimens.sm),
                ],
              ],
            ),

            const SizedBox(height: AppDimens.lg),

            Row(
              children: [
                const Icon(Icons.tune_rounded,
                    size: 14, color: AppColors.gold),
                const SizedBox(width: 6),
                Text(
                  'GAME RULES',
                  style: AppTextStyles.label.copyWith(color: AppColors.gold),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.sm),
            _RuleToggle(
              label: 'Voice chat',
              value: _voiceEnabled,
              onChanged: (v) => setState(() => _voiceEnabled = v),
            ),
            _RuleToggle(
              label: 'Stacking (+2 / +4)',
              value: _stacking,
              onChanged: (v) => setState(() => _stacking = v),
            ),

            const SizedBox(height: AppDimens.xl),

            AppButton(
              label: 'CREATE ROOM',
              variant: AppButtonVariant.gold,
              onPressed: _create,
            ),
          ],
        ),
    );
  }
}

class _PlayerCountChip extends StatelessWidget {
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _PlayerCountChip({
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : AppColors.surfaceHigh,
          borderRadius: AppDimens.brSm,
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.surfaceStroke,
          ),
        ),
        child: Text(
          '$count',
          style: AppTextStyles.h4.copyWith(
            color: selected ? const Color(0xFF3A2600) : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _RuleToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RuleToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTextStyles.body.copyWith(fontSize: 13)),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}
