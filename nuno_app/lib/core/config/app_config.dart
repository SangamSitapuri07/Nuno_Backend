/// Runtime configuration.
///
/// Override at build time:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
class AppConfig {
  AppConfig._();

  /// Base host of the Nuno backend (no trailing slash, no /api/v1).
  /// 10.0.2.2 is the Android emulator alias for the host machine's localhost.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// REST prefix used by src/server.ts
  static const String apiPrefix = '/api/v1';

  static String get apiBaseUrl => '$baseUrl$apiPrefix';

  /// Socket.IO connects to the bare host; the server mounts the default path.
  static String get socketUrl => baseUrl;

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Mirrors GAME_CONSTANTS in src/utils/constants.ts
  static const int minPlayers = 2;
  static const int maxPlayers = 10;
  static const int initialHandSize = 7;
  static const int turnTimerSeconds = 20;
  static const int maxChatLength = 200;
  static const int lobbyCountdownSeconds = 10;

  static const bool enableVoice = true;
}
