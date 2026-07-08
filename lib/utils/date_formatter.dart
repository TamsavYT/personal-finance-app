import 'package:intl/intl.dart';

/// Utility class for formatting dates and times throughout the app.
///
/// Provides standard, short, and relative date formats, along with
/// month-name and weekday-name lookups.
class DateFormatter {
  DateFormatter._();

  static final DateFormat _fullDateFormat = DateFormat('MMM dd, yyyy');
  static final DateFormat _shortDateFormat = DateFormat('dd MMM');
  static final DateFormat _timeFormat = DateFormat('h:mm a');

  /// Formats [date] as `Jun 25, 2026`.
  static String formatDate(DateTime date) {
    return _fullDateFormat.format(date);
  }

  /// Formats [date] as `25 Jun`.
  static String formatDateShort(DateTime date) {
    return _shortDateFormat.format(date);
  }

  /// Returns the full month-year string for a given [month] and [year],
  /// e.g. `June 2026`.
  static String formatMonth(int month, int year) {
    final date = DateTime(year, month);
    return DateFormat('MMMM yyyy').format(date);
  }

  /// Formats [date]'s time component as `2:30 PM`.
  static String formatTime(DateTime date) {
    return _timeFormat.format(date);
  }

  /// Returns a human-friendly relative label:
  /// - `Today` if the date is today
  /// - `Yesterday` if the date was yesterday
  /// - Otherwise the full formatted date
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    final difference = today.difference(target).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else {
      return formatDate(date);
    }
  }

  /// Returns the full month name for [month] (1–12).
  static String getMonthName(int month) {
    const months = [
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
    return months[month - 1];
  }

  /// Returns the full weekday name for [weekday] (1 = Monday … 7 = Sunday).
  static String getWeekdayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }
}
