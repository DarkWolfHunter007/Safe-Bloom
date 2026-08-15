import 'package:intl/intl.dart';

extension DateTimeX on DateTime {
  DateTime get dateOnly => DateTime(year, month, day);
  String get dateKey => toIso8601String().substring(0, 10);
}

class SafeBloomDateUtils {
  static DateTime dateOnly(DateTime dt) => dt.dateOnly;
  static String dateKey(DateTime dt) => dt.dateKey;
  static String monthAbbr(int month) => (month >= 1 && month <= 12) ? DateFormat.MMM().format(DateTime(2026, month, 1)) : '';
}
