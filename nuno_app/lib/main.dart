import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// True only on Android/iOS, where the mobile-only SystemChrome APIs apply.
bool get _isMobile =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (_isMobile) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0A0B1E),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    // The reference design is landscape-only. On desktop the user simply
    // resizes the window, so this is not applied there.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Full-bleed game canvas.
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  runApp(const ProviderScope(child: NunoApp()));
}

class NunoApp extends ConsumerWidget {
  const NunoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Nuno',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      builder: (context, child) {
        // Lock text scaling so the game HUD never overflows.
        final scale = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.15,
        );

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: _LandscapeGate(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

/// The UI is designed for a landscape canvas. On desktop the window can be any
/// shape, so if it is currently portrait we ask the user to widen it rather
/// than rendering a broken layout.
class _LandscapeGate extends StatelessWidget {
  final Widget child;

  const _LandscapeGate({required this.child});

  @override
  Widget build(BuildContext context) {
    // Only desktop/web windows can be arbitrarily shaped.
    if (_isMobile) return child;

    final size = MediaQuery.sizeOf(context);
    if (size.width >= size.height || size.width >= 700) return child;

    return ColoredBox(
      color: const Color(0xFF0A0B1E),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.screen_rotation_alt_rounded,
                size: 48,
                color: Color(0xFFFFC107),
              ),
              const SizedBox(height: 16),
              const Text(
                'Widen the window',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFF2F4FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Nuno is designed for a landscape screen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9BA3D0), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
