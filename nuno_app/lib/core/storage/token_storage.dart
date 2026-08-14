import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Securely persists the JWT pair issued by POST /api/v1/auth/login.
class TokenStorage {
  static const _accessKey = 'nuno_access_token';
  static const _refreshKey = 'nuno_refresh_token';
  static const _userIdKey = 'nuno_user_id';

  final FlutterSecureStorage _storage;

  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  String? _cachedAccessToken;
  String? get cachedAccessToken => _cachedAccessToken;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _cachedAccessToken = accessToken;
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<String?> readAccessToken() async {
    _cachedAccessToken ??= await _storage.read(key: _accessKey);
    return _cachedAccessToken;
  }

  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> saveUserId(String id) =>
      _storage.write(key: _userIdKey, value: id);

  Future<String?> readUserId() => _storage.read(key: _userIdKey);

  Future<bool> hasSession() async =>
      (await readAccessToken())?.isNotEmpty ?? false;

  Future<void> clear() async {
    _cachedAccessToken = null;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userIdKey);
  }
}
