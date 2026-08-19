import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/side_nav.dart';
import '../../core/widgets/titled_panel.dart';
import '../../data/models/user_models.dart';

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, PlayerSettings>(
        SettingsNotifier.new);

class SettingsNotifier extends AsyncNotifier<PlayerSettings> {
  Timer? _debounce;

  @override
  Future<PlayerSettings> build() {
    ref.onDispose(() => _debounce?.cancel());
    return ref.read(userRepositoryProvider).getSettings();
  }

  /// Applies optimistically, then persists (debounced so slider drags don't
  /// hammer PUT /api/v1/settings).
  ///
  /// Named `save` rather than `update` because AsyncNotifier already declares
  /// an `update` method with a different signature.
  void save(PlayerSettings next, Map<String, dynamic> patch) {
    state = AsyncData(next);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        await ref.read(userRepositoryProvider).updateSettings(patch);
      } catch (_) {
        state = await AsyncValue.guard(
          () => ref.read(userRepositoryProvider).getSettings(),
        );
      }
    });
  }
}

/// Screen 25 — Settings, with the reference's left sidebar:
/// General · Audio · Controls · Notifications · Privacy.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _section = 0;

  static const _items = [
    SideNavItem(Icons.tune_rounded, 'General'),
    SideNavItem(Icons.volume_up_rounded, 'Audio'),
    SideNavItem(Icons.gamepad_rounded, 'Controls'),
    SideNavItem(Icons.notifications_rounded, 'Notifications'),
    SideNavItem(Icons.shield_rounded, 'Privacy'),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return PanelScreen(
      title: 'Settings',
      onBack: () => context.pop(),
      padding: EdgeInsets.zero,
      fillHeight: true,
      child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: settings.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorStateView(
              message: e.toString(),
              onRetry: () => ref.invalidate(settingsProvider),
            ),
            data: (s) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SideNav(
                  items: _items,
                  index: _section,
                  onChanged: (i) => setState(() => _section = i),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: SingleChildScrollView(
                    child: switch (_section) {
                      1 => _AudioSection(settings: s, notifier: notifier),
                      2 => _ControlsSection(settings: s, notifier: notifier),
                      3 => _NotificationsSection(
                          settings: s, notifier: notifier),
                      4 => const _PrivacySection(),
                      _ => _GeneralSection(settings: s, notifier: notifier),
                    },
                  ),
                ),
              ],
          ),
        ),
      ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────

class _GeneralSection extends StatelessWidget {
  final PlayerSettings settings;
  final SettingsNotifier notifier;

  const _GeneralSection({required this.settings, required this.notifier});

  static const _languages = {
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'pt': 'Português',
    'hi': 'हिन्दी',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LANGUAGE', style: AppTextStyles.label),
        const SizedBox(height: AppDimens.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in _languages.entries)
              GestureDetector(
                onTap: () => notifier.save(
                  settings.copyWith(language: e.key),
                  {'language': e.key},
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.md,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: settings.language == e.key
                        ? AppColors.blue
                        : AppColors.surfaceHigh,
                    borderRadius: AppDimens.brPill,
                    border: Border.all(
                      color: settings.language == e.key
                          ? AppColors.blue
                          : AppColors.surfaceStroke,
                    ),
                  ),
                  child: Text(
                    e.value,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 11,
                      color: settings.language == e.key
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppDimens.lg),
        _SettingRow(
          label: 'Dark mode',
          value: settings.darkMode,
          onChanged: (v) => notifier.save(
            settings.copyWith(darkMode: v),
            {'darkMode': v},
          ),
        ),
        const SizedBox(height: AppDimens.lg),
        Row(
          children: [
            Expanded(
              child: Text('Tutorial',
                  style: AppTextStyles.body.copyWith(fontSize: 12)),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.tutorial),
              child: Text(
                'How to play',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.blue),
              ),
            ),
          ],
        ),
        const Divider(height: AppDimens.xl),
        Row(
          children: [
            Expanded(
              child:
                  Text('Version', style: AppTextStyles.body.copyWith(fontSize: 12)),
            ),
            Text('1.0.0', style: AppTextStyles.bodySm),
          ],
        ),
      ],
    );
  }
}

class _AudioSection extends StatelessWidget {
  final PlayerSettings settings;
  final SettingsNotifier notifier;

  const _AudioSection({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _VolumeSlider(
          label: 'Music',
          icon: Icons.music_note_rounded,
          value: settings.musicVolume,
          onChanged: (v) => notifier.save(
            settings.copyWith(musicVolume: v),
            {'musicVolume': v},
          ),
        ),
        _VolumeSlider(
          label: 'SFX',
          icon: Icons.graphic_eq_rounded,
          value: settings.soundVolume,
          onChanged: (v) => notifier.save(
            settings.copyWith(soundVolume: v),
            {'soundVolume': v},
          ),
        ),
        _VolumeSlider(
          label: 'Voice chat',
          icon: Icons.mic_rounded,
          value: settings.voiceVolume,
          onChanged: (v) => notifier.save(
            settings.copyWith(voiceVolume: v),
            {'voiceVolume': v},
          ),
        ),
      ],
    );
  }
}

class _ControlsSection extends StatelessWidget {
  final PlayerSettings settings;
  final SettingsNotifier notifier;

  const _ControlsSection({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SettingRow(
          label: 'Push to talk',
          description: 'Hold a button to speak',
          value: settings.pushToTalk,
          onChanged: (v) => notifier.save(
            settings.copyWith(pushToTalk: v),
            {'pushToTalk': v},
          ),
        ),
      ],
    );
  }
}

class _NotificationsSection extends StatelessWidget {
  final PlayerSettings settings;
  final SettingsNotifier notifier;

  const _NotificationsSection({
    required this.settings,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SettingRow(
          label: 'Push notifications',
          description: 'Invites, requests and match alerts',
          value: settings.notifications,
          onChanged: (v) => notifier.save(
            settings.copyWith(notifications: v),
            {'notifications': v},
          ),
        ),
        const SizedBox(height: AppDimens.md),
        Row(
          children: [
            Expanded(
              child: Text('Inbox',
                  style: AppTextStyles.body.copyWith(fontSize: 12)),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.notifications),
              child: Text(
                'View all',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.blue),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PrivacySection extends ConsumerWidget {
  const _PrivacySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BLOCKED PLAYERS', style: AppTextStyles.label),
        const SizedBox(height: AppDimens.sm),
        FutureBuilder<List<String>>(
          future: ref.read(socialRepositoryProvider).getBlockedPlayers(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SkeletonBox(height: 40);
            }
            final blocked = snap.data ?? const [];
            if (blocked.isEmpty) {
              return Text(
                'You have not blocked anyone.',
                style: AppTextStyles.bodySm,
              );
            }
            return Column(
              children: [
                for (final id in blocked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            id,
                            overflow: TextOverflow.ellipsis,
                            style:
                                AppTextStyles.body.copyWith(fontSize: 11),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await ref
                                .read(socialRepositoryProvider)
                                .unblockPlayer(id);
                            if (context.mounted) {
                              AppSnack.show(context, 'Unblocked');
                            }
                          },
                          child: Text(
                            'Unblock',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── Shared controls ───────────────────────────────────────────

class _VolumeSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final int value;
  final ValueChanged<int> onChanged;

  const _VolumeSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: AppDimens.sm),
        SizedBox(
          width: 74,
          child: Text(label, style: AppTextStyles.body.copyWith(fontSize: 12)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 4),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingRow({
    required this.label,
    this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.body.copyWith(fontSize: 12)),
              if (description != null)
                Text(description!,
                    style: AppTextStyles.caption.copyWith(fontSize: 9)),
            ],
          ),
        ),
        Transform.scale(
          scale: 0.8,
          child: Switch(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}
