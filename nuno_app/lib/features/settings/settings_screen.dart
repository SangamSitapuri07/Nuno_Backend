import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_states.dart';
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

  /// Optimistically applies the change, then persists it (debounced so slider
  /// drags don't hammer PUT /api/v1/settings).
  void update(PlayerSettings next, Map<String, dynamic> patch) {
    state = AsyncData(next);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        await ref.read(userRepositoryProvider).updateSettings(patch);
      } catch (_) {
        // Reload the server truth if the write failed.
        state = await AsyncValue.guard(
          () => ref.read(userRepositoryProvider).getSettings(),
        );
      }
    });
  }
}

/// Audio, gameplay and account settings backed by PlayerSettings.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.lg,
                  AppDimens.sm,
                  AppDimens.lg,
                  AppDimens.md,
                ),
                child: Row(
                  children: [
                    AppIconButton(
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: AppDimens.md),
                    Text('Settings', style: AppTextStyles.h2),
                  ],
                ),
              ),
              Expanded(
                child: settings.when(
                  loading: () => const LoadingView(),
                  error: (e, _) => ErrorStateView(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(settingsProvider),
                  ),
                  data: (s) => ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.xl,
                      0,
                      AppDimens.xl,
                      AppDimens.xxxl,
                    ),
                    children: [
                      // ── Audio ─────────────────────────
                      const SectionHeader(
                        title: 'Audio',
                        icon: Icons.volume_up_rounded,
                      ),
                      AppPanel(
                        child: Column(
                          children: [
                            _VolumeSlider(
                              label: 'Music',
                              icon: Icons.music_note_rounded,
                              value: s.musicVolume,
                              onChanged: (v) => notifier.update(
                                s.copyWith(musicVolume: v),
                                {'musicVolume': v},
                              ),
                            ),
                            const Divider(height: AppDimens.xxl),
                            _VolumeSlider(
                              label: 'Sound effects',
                              icon: Icons.graphic_eq_rounded,
                              value: s.soundVolume,
                              onChanged: (v) => notifier.update(
                                s.copyWith(soundVolume: v),
                                {'soundVolume': v},
                              ),
                            ),
                            const Divider(height: AppDimens.xxl),
                            _VolumeSlider(
                              label: 'Voice chat',
                              icon: Icons.mic_rounded,
                              value: s.voiceVolume,
                              onChanged: (v) => notifier.update(
                                s.copyWith(voiceVolume: v),
                                {'voiceVolume': v},
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppDimens.xxl),

                      // ── Gameplay ──────────────────────
                      const SectionHeader(
                        title: 'Gameplay',
                        icon: Icons.sports_esports_rounded,
                      ),
                      AppPanel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.lg,
                          vertical: AppDimens.xs,
                        ),
                        child: Column(
                          children: [
                            _SettingSwitch(
                              label: 'Push to talk',
                              description:
                                  'Hold a button to speak instead of open mic',
                              icon: Icons.record_voice_over_rounded,
                              value: s.pushToTalk,
                              onChanged: (v) => notifier.update(
                                s.copyWith(pushToTalk: v),
                                {'pushToTalk': v},
                              ),
                            ),
                            const Divider(height: 1),
                            _SettingSwitch(
                              label: 'Notifications',
                              description:
                                  'Friend requests, invites and match alerts',
                              icon: Icons.notifications_rounded,
                              value: s.notifications,
                              onChanged: (v) => notifier.update(
                                s.copyWith(notifications: v),
                                {'notifications': v},
                              ),
                            ),
                            const Divider(height: 1),
                            _SettingSwitch(
                              label: 'Dark mode',
                              description: 'Use the dark table theme',
                              icon: Icons.dark_mode_rounded,
                              value: s.darkMode,
                              onChanged: (v) => notifier.update(
                                s.copyWith(darkMode: v),
                                {'darkMode': v},
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppDimens.xxl),

                      // ── Language ──────────────────────
                      const SectionHeader(
                        title: 'Language',
                        icon: Icons.language_rounded,
                      ),
                      AppPanel(
                        child: Wrap(
                          spacing: AppDimens.sm,
                          runSpacing: AppDimens.sm,
                          children: [
                            for (final entry in _languages.entries)
                              GestureDetector(
                                onTap: () => notifier.update(
                                  s.copyWith(language: entry.key),
                                  {'language': entry.key},
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppDimens.lg,
                                    vertical: AppDimens.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: s.language == entry.key
                                        ? AppColors.primaryGradient
                                        : null,
                                    color: s.language == entry.key
                                        ? null
                                        : AppColors.background,
                                    borderRadius: AppDimens.brPill,
                                    border: Border.all(
                                      color: s.language == entry.key
                                          ? Colors.transparent
                                          : AppColors.surfaceStroke,
                                    ),
                                  ),
                                  child: Text(
                                    entry.value,
                                    style: AppTextStyles.body.copyWith(
                                      color: s.language == entry.key
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppDimens.xxl),

                      // ── About ─────────────────────────
                      const SectionHeader(
                        title: 'About',
                        icon: Icons.info_outline_rounded,
                      ),
                      AppPanel(
                        child: Column(
                          children: [
                            _InfoRow(label: 'Version', value: '1.0.0'),
                            const SizedBox(height: AppDimens.md),
                            _InfoRow(label: 'Game', value: 'Nuno'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const Map<String, String> _languages = {
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'pt': 'Português',
    'hi': 'हिन्दी',
  };
}

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
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppDimens.sm),
            Expanded(child: Text(label, style: AppTextStyles.body)),
            Text(
              '$value',
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 100,
          divisions: 20,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingSwitch({
    required this.label,
    required this.description,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.md),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.body),
                Text(description, style: AppTextStyles.caption),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTextStyles.body)),
        Text(value, style: AppTextStyles.bodySm),
      ],
    );
  }
}
