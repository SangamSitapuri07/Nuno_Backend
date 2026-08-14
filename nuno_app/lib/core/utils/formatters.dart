import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  /// "2m ago", "3h ago", "5d ago", or an absolute date beyond a week.
  static String relativeTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM y').format(time);
  }

  /// "Online", or "Last seen 3h ago".
  static String lastSeen(DateTime? time) {
    if (time == null) return 'Never played';
    return 'Last seen ${relativeTime(time).toLowerCase()}';
  }

  /// 1234 -> "1,234"
  static String number(int value) => NumberFormat.decimalPattern().format(value);

  /// 15300 -> "15.3K"
  static String compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 10000) return '${(value / 1000).toStringAsFixed(1)}K';
    return number(value);
  }

  /// Seconds -> "2:05"
  static String duration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String date(DateTime? time) =>
      time == null ? '' : DateFormat('d MMM y').format(time);
}
