import 'package:intl/intl.dart';

class SafeBloomDateUtils {
  /// Strips time components and returns a DateTime at 00:00:00.000 in local time.
  static DateTime dateOnly(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Returns canonical yyyy-MM-dd string key.
  static String dateKey(DateTime dt) {
    return dt.toIso8601String().substring(0, 10);
  }

  /// Returns abbreviated month name.
  static String monthAbbr(int month) {
    if (month < 1 || month > 12) return '';
    return DateFormat.MMM().format(DateTime(2026, month, 1));
  }
}
