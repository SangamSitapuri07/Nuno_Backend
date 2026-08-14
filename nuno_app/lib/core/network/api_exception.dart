/// Mirrors the backend error envelope:
/// { success: false, error: { code, message } }
class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  factory ApiException.fromResponse(dynamic body, int? statusCode) {
    if (body is Map && body['error'] is Map) {
      final err = body['error'] as Map;
      return ApiException(
        code: (err['code'] ?? 'SERVER_ERROR').toString(),
        message: (err['message'] ?? 'Something went wrong.').toString(),
        statusCode: statusCode,
      );
    }
    return ApiException(
      code: 'SERVER_ERROR',
      message: 'Something went wrong. Please try again.',
      statusCode: statusCode,
    );
  }

  static const ApiException network = ApiException(
    code: 'NETWORK_ERROR',
    message: 'No connection. Check your internet and try again.',
  );

  static const ApiException timeout = ApiException(
    code: 'TIMEOUT',
    message: 'The server took too long to respond.',
  );

  bool get isAuthError =>
      statusCode == 401 ||
      code == 'AUTH_FAILED' ||
      code == 'INVALID_TOKEN' ||
      code == 'TOKEN_EXPIRED';

  @override
  String toString() => message;
}
