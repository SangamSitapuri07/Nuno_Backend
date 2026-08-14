import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../models/json.dart';

/// POST /api/v1/auth/*
class AuthRepository {
  final ApiClient _api;
  final TokenStorage _tokens;

  AuthRepository(this._api, this._tokens);

  /// Backend returns only a message; the client then logs in.
  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    await _api.post(
      '/auth/register',
      body: {'username': username, 'email': email, 'password': password},
      skipAuth: true,
    );
  }

  /// Returns the access token and persists both tokens.
  Future<String> login({
    required String email,
    required String password,
  }) async {
    final data = J.map(await _api.post(
      '/auth/login',
      body: {'email': email, 'password': password},
      skipAuth: true,
    ));

    final access = J.str(data['accessToken']);
    final refresh = J.str(data['refreshToken']);
    await _tokens.saveTokens(accessToken: access, refreshToken: refresh);
    return access;
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
