import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../models/json.dart';

/// POST /api/v1/auth/*
class AuthRepository {
  final ApiClient _api;
  final TokenStorage _tokens;

  AuthRepository(this._api, this._tokens);

  /// Exchanges a Google ID token for an app session.
  ///
  /// Covers both sign-up and sign-in: the server creates the account on first
  /// use. `needsUsername` says whether to send the player to the setup screen
  /// before the home screen.
  Future<GoogleSignInResult> googleSignIn(String idToken) async {
    final data = J.map(await _api.post(
      '/auth/google',
      body: {'idToken': idToken},
      skipAuth: true,
    ));

    final access = J.str(data['accessToken']);
    final refresh = J.str(data['refreshToken']);
    await _tokens.saveTokens(accessToken: access, refreshToken: refresh);

    return GoogleSignInResult(
      accessToken: access,
      isNewAccount: J.bool_(data['isNewAccount']),
      needsUsername: J.bool_(data['needsUsername']),
    );
  }

  /// Claims a username. Only valid once, straight after a Google sign-up.
  Future<void> setUsername(String username) async {
    await _api.post('/auth/username', body: {'username': username});
  }

  /// Live availability check for the setup screen.
  Future<UsernameCheck> checkUsername(String username) async {
    final data = J.map(
      await _api.get('/auth/username/available', query: {'username': username}),
    );
    return UsernameCheck(
      available: J.bool_(data['available']),
      reason: J.strOrNull(data['reason']),
    );
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // Always clear locally even if the call fails.
    }
    await _tokens.clear();
  }

  Future<bool> hasSession() => _tokens.hasSession();
}

/// Outcome of POST /auth/google.
class GoogleSignInResult {
  final String accessToken;
  final bool isNewAccount;

  /// True while the account still has its auto-generated placeholder name.
  final bool needsUsername;

  const GoogleSignInResult({
    required this.accessToken,
    required this.isNewAccount,
    required this.needsUsername,
  });
}

/// Outcome of GET /auth/username/available.
class UsernameCheck {
  final bool available;

  /// Why it is unavailable - too short, bad characters, or already taken.
  final String? reason;

  const UsernameCheck({required this.available, this.reason});
}
