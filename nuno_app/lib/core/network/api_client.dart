import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Thin Dio wrapper around the Nuno REST API.
///
/// Handles:
///  * Bearer auth header injection
///  * transparent refresh via POST /auth/refresh on 401 (access token TTL 900s)
///  * unwrapping the `{ success, data }` envelope
///  * mapping `{ success:false, error }` into [ApiException]
class ApiClient {
  final Dio _dio;
  final TokenStorage _tokenStorage;

  /// Invoked after a refresh mints a new access token. The socket holds its
  /// own copy from the handshake, so without this it keeps presenting the
  /// expired one and every reconnect is rejected.
  ///
  /// Assigned after construction (see sessionLinkProvider) because the socket
  /// and this client each need a reference to the other.
  Future<void> Function()? onTokenRefreshed;

  /// Invoked when refreshing fails and the user must log in again.
  final Future<void> Function()? onSessionExpired;

  Completer<String?>? _refreshCompleter;

  ApiClient({
    required TokenStorage tokenStorage,
    Dio? dio,
    this.onSessionExpired,
  })  : _tokenStorage = tokenStorage,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: AppConfig.connectTimeout,
                receiveTimeout: AppConfig.receiveTimeout,
                contentType: 'application/json',
                // We inspect non-2xx bodies ourselves.
                validateStatus: (_) => true,
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] != true) {
            final token = await _tokenStorage.readAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
      ),
    );
  }

  Dio get raw => _dio;

  // ── Verbs ───────────────────────────────────────────────────

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool skipAuth = false,
  }) =>
      _send(() => _dio.get(
            path,
            queryParameters: query,
            options: Options(extra: {'skipAuth': skipAuth}),
          ));

  Future<dynamic> post(
    String path, {
    Object? body,
    bool skipAuth = false,
  }) =>
      _send(() => _dio.post(
            path,
            data: body,
            options: Options(extra: {'skipAuth': skipAuth}),
          ));

  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => _dio.put(path, data: body));

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() => _dio.patch(path, data: body));

  Future<dynamic> delete(String path, {Object? body}) =>
      _send(() => _dio.delete(path, data: body));

  // ── Core ────────────────────────────────────────────────────

  Future<dynamic> _send(
    Future<Response> Function() request, {
    bool isRetry = false,
  }) async {
    late Response response;
    try {
      response = await request();
    } on DioException catch (e) {
      throw _mapDioError(e);
    }

    final status = response.statusCode ?? 500;
    final body = response.data;

    if (status >= 200 && status < 300) {
      if (body is Map && body.containsKey('data')) return body['data'];
      return body;
    }

    // Try one transparent refresh on auth failure.
    if (status == 401 && !isRetry) {
      final newToken = await _refreshToken();
      if (newToken != null) {
        return _send(request, isRetry: true);
      }
      await onSessionExpired?.call();
    }

    throw ApiException.fromResponse(body, status);
  }

  /// Renews the session on demand, for callers outside a request — the socket
  /// uses this when the server rejects its handshake token. Returns whether a
  /// usable access token is now stored.
  Future<bool> refreshSession() async {
    final token = await _refreshToken();
    if (token == null) {
      await onSessionExpired?.call();
      return false;
    }
    return true;
  }

  /// Refreshes the access token. Concurrent callers share one in-flight call.
  Future<String?> _refreshToken() {
    if (_refreshCompleter != null) return _refreshCompleter!.future;

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    () async {
      try {
        final refreshToken = await _tokenStorage.readRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          completer.complete(null);
          return;
        }

        final res = await _dio.post(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
          options: Options(extra: {'skipAuth': true}),
        );

        final status = res.statusCode ?? 500;
        final data = res.data;

        if (status >= 200 && status < 300 && data is Map && data['data'] is Map) {
          final tokens = data['data'] as Map;
          final access = tokens['accessToken']?.toString();
          final refresh = tokens['refreshToken']?.toString();
          if (access != null && refresh != null) {
            await _tokenStorage.saveTokens(
              accessToken: access,
              refreshToken: refresh,
            );
            await onTokenRefreshed?.call();
            completer.complete(access);
            return;
          }
        }

        await _tokenStorage.clear();
        completer.complete(null);
      } catch (_) {
        completer.complete(null);
      } finally {
        _refreshCompleter = null;
      }
    }();

    return completer.future;
  }

  ApiException _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException.timeout;
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return ApiException.network;
      default:
        return ApiException.fromResponse(
          e.response?.data,
          e.response?.statusCode,
        );
    }
  }
}
