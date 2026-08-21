import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Wraps the interactive Google sign-in.
///
/// This only ever obtains an ID token; it never decides who the user is. The
/// token goes to `POST /auth/google`, and the server verifies its signature
/// against Google's public keys before trusting a single field in it.
class GoogleAuthService {
  GoogleSignIn? _client;

  /// The web/server OAuth client id.
  ///
  /// On Android the plugin identifies the app by its signing certificate, but
  /// the token it mints is only useful to us if it is addressed to our
  /// server. Passing `serverClientId` is what makes Google put that client id
  /// in the token's `aud`, which is exactly what the backend checks.
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  GoogleSignIn get _google => _client ??= GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
      );

  /// True when the app was built with a server client id.
  static bool get isConfigured => _serverClientId.isNotEmpty;

  /// Runs the Google account picker and returns an ID token.
  ///
  /// Returns null when the player backs out of the picker, which is a normal
  /// outcome and not an error.
  Future<String?> signIn() async {
    // A stale cached account makes the picker skip straight to the previous
    // choice, which is wrong on a shared device and confusing after a logout.
    await _google.signOut();

    final account = await _google.signIn();
    if (account == null) return null;

    final auth = await account.authentication;
    final token = auth.idToken;

    if (token == null || token.isEmpty) {
      // Nearly always a configuration problem: no serverClientId, or the
      // SHA-1 of the signing key is not registered in the Firebase console.
      debugPrint(
        'Google sign-in returned no ID token. Check that '
        'GOOGLE_SERVER_CLIENT_ID is set at build time and that this build\'s '
        'SHA-1 is registered for the Android OAuth client.',
      );
      throw const GoogleSignInFailure(
        'Google sign-in is not configured correctly for this build.',
      );
    }

    return token;
  }

  /// Clears the cached Google account so the next sign-in shows the picker.
  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {
      // Signing out of Google is best effort; the app session is what matters.
    }
  }
}

class GoogleSignInFailure implements Exception {
  final String message;
  const GoogleSignInFailure(this.message);

  @override
  String toString() => message;
}
