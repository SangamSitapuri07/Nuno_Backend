/// Defensive JSON coercion helpers.
///
/// The backend serialises BigInt as String (see the BigInt.toJSON patch in
/// src/server.ts) and Prisma Floats/Ints can arrive as either num type, so
/// every read goes through these.
class J {
  J._();

  static Map<String, dynamic> map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static List<dynamic> list(dynamic v) => v is List ? v : const [];

  static String str(dynamic v, [String fallback = '']) =>
      v == null ? fallback : v.toString();

  static String? strOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  static int int_(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.round() ?? fallback;
    return fallback;
  }

  static double dbl(dynamic v, [double fallback = 0]) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static bool bool_(dynamic v, [bool fallback = false]) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.toLowerCase() == 'true';
    return fallback;
  }

  static DateTime? date(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    return DateTime.tryParse(v.toString());
  }

  /// Epoch milliseconds (socket payloads use Date.now()).
  static DateTime dateMs(dynamic v) => v == null
      ? DateTime.now()
      : DateTime.fromMillisecondsSinceEpoch(int_(v, DateTime.now().millisecondsSinceEpoch));
}
