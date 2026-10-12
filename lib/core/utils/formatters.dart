import 'package:flutter/material.dart';

/// Date, time and duration formatting helpers (no external packages).
class Fmt {
  Fmt._();

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const List<String> _monthsShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const List<String> _weekdaysShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime addDays(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day + n);

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String two(int n) => n.toString().padLeft(2, '0');

  static String weekdayShort(DateTime d) => _weekdaysShort[d.weekday - 1];

  static String monthName(int month) => _months[month - 1];

  static String date(DateTime d) =>
      '${d.day} ${_monthsShort[d.month - 1]} ${d.year}';

  static String dayMonth(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]}';

  static String dateLong(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

  static String monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

  static String isoDate(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

  /// "Today", "Yesterday" or a long date such as "Monday, 5 October".
  static String relativeDay(DateTime d, DateTime now) {
    final today = dayOnly(now);
    final day = dayOnly(d);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    return dateLong(d);
  }

  static String time(DateTime d) => _time12(d.hour, d.minute);

  static String timeOfDay(TimeOfDay t) => _time12(t.hour, t.minute);

  static String _time12(int hour24, int minute) {
    final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final suffix = hour24 < 12 ? 'AM' : 'PM';
    return '$hour:${two(minute)} $suffix';
  }

  /// "9 s", "1 min 5 s", "2 min".
  static String duration(Duration d) {
    final total = d.inSeconds;
    if (total < 60) return '$total s';
    final minutes = total ~/ 60;
    final seconds = total % 60;
    if (seconds == 0) return '$minutes min';
    return '$minutes min $seconds s';
  }

  static String seconds(int s) => duration(Duration(seconds: s));

  static String oneDecimal(double v) => v.toStringAsFixed(1);
}
