/// Persian Date Utility - Format dates in Persian (Jalali) calendar
/// Uses custom JalaliDate implementation (no external dependencies)

import 'jalali_date.dart';
import 'persian_number.dart';

class PersianDate {
  /// Format DateTime to Persian date string
  /// Format: yyyy/MM/dd (e.g., 1403/09/15)
  static String formatDate(DateTime dateTime) {
    final jalali = JalaliDate.fromDateTime(dateTime);
    return jalali.format();
  }

  /// Format DateTime to Persian date string with Persian digits
  /// Format: ۱۴۰۳/۰۹/۱۵
  static String formatDatePersian(DateTime dateTime) {
    final jalali = JalaliDate.fromDateTime(dateTime);
    return jalali.formatPersian();
  }

  /// Parse datetime string from backend and convert to local timezone (Tehran)
  /// Handles both UTC and timezone-aware datetime strings
  static DateTime parseToLocal(String dateTimeString) {
    try {
      // Parse the datetime string
      DateTime parsed = DateTime.parse(dateTimeString);
      
      // If the datetime is UTC (has 'Z' or ends with '+00:00'), convert to local
      if (parsed.isUtc) {
        return parsed.toLocal();
      }
      
      // If datetime is already in local timezone, return as is
      return parsed;
    } catch (e) {
      // Fallback: try parsing as UTC and convert to local
      try {
        return DateTime.parse(dateTimeString).toUtc().toLocal();
      } catch (e2) {
        // If all parsing fails, return current time
        return DateTime.now();
      }
    }
  }

  /// Format DateTime to Persian date string with time
  /// Format: yyyy/MM/dd HH:mm (e.g., 1403/09/15 14:30)
  /// Uses local timezone (Tehran) for display
  static String formatDateTime(DateTime dateTime) {
    // Ensure we're using local timezone
    final localDateTime = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    final jalali = JalaliDate.fromDateTime(localDateTime);
    final hour = localDateTime.hour.toString().padLeft(2, '0');
    final minute = localDateTime.minute.toString().padLeft(2, '0');
    return '${jalali.format()} $hour:$minute';
  }

  /// Format DateTime to Persian date string with time and Persian digits
  static String formatDateTimePersian(DateTime dateTime) {
    final jalali = JalaliDate.fromDateTime(dateTime);
    final hour = PersianNumber.toPersian(
      dateTime.hour.toString().padLeft(2, '0'),
    );
    final minute = PersianNumber.toPersian(
      dateTime.minute.toString().padLeft(2, '0'),
    );
    return '${jalali.formatPersian()} $hour:$minute';
  }

  /// Format DateTime to Persian date string with full format
  /// Format: yyyy/MM/dd HH:mm:ss (e.g., 1403/09/15 14:30:45)
  static String formatDateTimeFull(DateTime dateTime) {
    final jalali = JalaliDate.fromDateTime(dateTime);
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '${jalali.format()} $hour:$minute:$second';
  }

  /// Format DateTime to Persian date with month name
  /// Format: dd MonthName yyyy (e.g., 15 آذر 1403)
  static String formatDateWithMonthName(DateTime dateTime) {
    final jalali = JalaliDate.fromDateTime(dateTime);
    return jalali.formatWithMonthName();
  }

  /// Format DateTime to Persian date with month name and Persian digits
  static String formatDateWithMonthNamePersian(DateTime dateTime) {
    final jalali = JalaliDate.fromDateTime(dateTime);
    return jalali.formatWithMonthNamePersian();
  }

  /// Format DateTime to Persian date with day name
  /// Format: DayName dd MonthName yyyy (e.g., یکشنبه 15 آذر 1403)
  static String formatDateWithDayName(DateTime dateTime) {
    final jalali = JalaliDate.fromDateTime(dateTime);
    return jalali.formatFull();
  }

  /// Format DateTime to Persian date with day name and Persian digits
  static String formatDateWithDayNamePersian(DateTime dateTime) {
    final jalali = JalaliDate.fromDateTime(dateTime);
    return jalali.formatFullPersian();
  }

  /// Get current Persian date
  static JalaliDate getNow() {
    return JalaliDate.now();
  }

  /// Convert Persian date string to DateTime
  /// Input format: yyyy/MM/dd (e.g., 1403/09/15)
  static DateTime? parseDate(String dateString) {
    final jalali = JalaliDate.parse(dateString);
    return jalali?.toDateTime();
  }

  /// Format relative time (e.g., "2 ساعت پیش", "3 روز پیش")
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.isNegative) {
      // Future date
      final futureDiff = dateTime.difference(now);
      if (futureDiff.inDays > 365) {
        final years = (futureDiff.inDays / 365).floor();
        return 'تا $years سال دیگر';
      } else if (futureDiff.inDays > 30) {
        final months = (futureDiff.inDays / 30).floor();
        return 'تا $months ماه دیگر';
      } else if (futureDiff.inDays > 0) {
        return 'تا ${futureDiff.inDays} روز دیگر';
      } else if (futureDiff.inHours > 0) {
        return 'تا ${futureDiff.inHours} ساعت دیگر';
      } else if (futureDiff.inMinutes > 0) {
        return 'تا ${futureDiff.inMinutes} دقیقه دیگر';
      } else {
        return 'چند لحظه دیگر';
      }
    }

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years سال پیش';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ماه پیش';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} روز پیش';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقیقه پیش';
    } else {
      return 'همین الان';
    }
  }

  /// Format relative time with Persian digits
  static String formatRelativeTimePersian(DateTime dateTime) {
    return PersianNumber.toPersian(formatRelativeTime(dateTime));
  }

  /// Convert ISO date string (YYYY-MM-DD, YYYY-MM, or YYYY) to Persian format
  /// Used for converting backend date strings to Persian
  static String formatIsoDate(String isoDate) {
    try {
      if (isoDate.contains('-')) {
        final parts = isoDate.split('-');
        if (parts.length == 3) {
          // YYYY-MM-DD format
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          final dateTime = DateTime(year, month, day);
          return formatDate(dateTime);
        } else if (parts.length == 2) {
          // YYYY-MM format
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final jalali = JalaliDate.fromDateTime(DateTime(year, month, 1));
          return '${jalali.year}/${jalali.month.toString().padLeft(2, '0')}';
        }
      } else {
        // YYYY format
        final year = int.parse(isoDate);
        final jalali = JalaliDate.fromDateTime(DateTime(year, 1, 1));
        return jalali.year.toString();
      }
      return isoDate;
    } catch (e) {
      return isoDate;
    }
  }

  /// Convert ISO date string to Persian format with Persian digits
  static String formatIsoDatePersian(String isoDate) {
    return PersianNumber.toPersian(formatIsoDate(isoDate));
  }

  /// Get month name in Persian
  static String getMonthName(int month) {
    if (month >= 1 && month <= 12) {
      return JalaliDate.monthNames[month];
    }
    return '';
  }

  /// Get day of week name in Persian
  static String getDayOfWeekName(int dayOfWeek) {
    if (dayOfWeek >= 0 && dayOfWeek <= 6) {
      return JalaliDate.dayOfWeekNames[dayOfWeek];
    }
    return '';
  }
}
