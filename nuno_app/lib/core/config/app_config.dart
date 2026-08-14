/// Runtime configuration.
///
/// Defaults to the hosted Render backend, so the app runs with no flags:
///     flutter run
///
/// Override for a local backend:
///     flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
class AppConfig {
  AppConfig._();

  /// Base host of the Nuno backend (no trailing slash, no /api/v1).
  ///
  /// Local development alternatives:
  ///   Android emulator        http://10.0.2.2:3000
  ///   iOS simulator/desktop   http://localhost:3000
  ///   Physical device         http://<your-LAN-IP>:3000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://nuno-backend-by35.onrender.com',
  );

  /// REST prefix used by src/server.ts
  static const String apiPrefix = '/api/v1';

  static String get apiBaseUrl => '$baseUrl$apiPrefix';

  /// Socket.IO connects to the bare host; the server mounts the default path.
  static String get socketUrl => baseUrl;

  static bool get isHttps => baseUrl.startsWith('https');

  /// True when pointing at a free-tier Render host, which sleeps after ~15
  /// minutes of inactivity and needs a slow cold start on the next request.
  static bool get isRenderFreeTier => baseUrl.contains('onrender.com');

  // ── Timeouts ────────────────────────────────────────────────
  //
  // A sleeping Render instance can take 50-60s to wake, so the first request
  // needs a much longer budget than a warm one.

  static Duration get connectTimeout =>
      isRenderFreeTier ? const Duration(seconds: 90) : const Duration(seconds: 20);

  static Duration get receiveTimeout =>
      isRenderFreeTier ? const Duration(seconds: 90) : const Duration(seconds: 20);

  /// Show a "waking the server" hint if a request outlives this.
  static const Duration coldStartHintAfter = Duration(seconds: 6);

  /// Mirrors GAME_CONSTANTS in src/utils/constants.ts
  static const int minPlayers = 2;
  static const int maxPlayers = 10;
  static const int initialHandSize = 7;
  static const int turnTimerSeconds = 20;
  static const int maxChatLength = 200;
  static const int lobbyCountdownSeconds = 10;

  static const bool enableVoice = true;
}
