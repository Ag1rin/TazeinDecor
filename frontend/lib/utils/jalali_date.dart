/// Custom Jalali/Shamsi Date System
/// Implements Gregorian-Jalali conversion without external dependencies
/// Based on the Jalali calendar algorithm

import 'persian_number.dart';

/// Represents a date in the Jalali (Persian/Shamsi) calendar
class JalaliDate {
  final int year;
  final int month;
  final int day;

  const JalaliDate(this.year, this.month, this.day);

  /// Persian month names
  static const List<String> monthNames = [
    '', // Index 0 unused
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  /// Persian short month names
  static const List<String> shortMonthNames = [
    '',
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  /// Persian day of week names (Saturday = 0)
  static const List<String> dayOfWeekNames = [
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
  ];

  /// Persian short day names
  static const List<String> shortDayOfWeekNames = [
    'ش',
    'ی',
    'د',
    'س',
    'چ',
    'پ',
    'ج',
  ];

  /// Days in each Jalali month (non-leap year)
  static const List<int> _daysInMonth = [
    0, // Index 0 unused
    31, 31, 31, 31, 31, 31, // First 6 months have 31 days
    30, 30, 30, 30, 30, 29, // Last 6 months have 30/29 days
  ];

  /// Get current Jalali date
  static JalaliDate now() {
    return fromDateTime(DateTime.now());
  }

  /// Create JalaliDate from DateTime (Gregorian)
  static JalaliDate fromDateTime(DateTime dateTime) {
    return _gregorianToJalali(dateTime.year, dateTime.month, dateTime.day);
  }

  /// Convert this Jalali date to DateTime (Gregorian)
  DateTime toDateTime() {
    return _jalaliToGregorian(year, month, day);
  }

  /// Check if this year is a leap year in Jalali calendar
  bool get isLeapYear => _isJalaliLeapYear(year);

  /// Get the number of days in the current month
  int get daysInMonth {
    if (month == 12) {
      return isLeapYear ? 30 : 29;
    }
    return _daysInMonth[month];
  }

  /// Get the day of week (0 = Saturday, 6 = Friday)
  int get weekDay {
    final gregorian = toDateTime();
    // DateTime.weekday: 1 = Monday, 7 = Sunday
    // Jalali weekday: 0 = Saturday, 6 = Friday
    // Convert: Saturday(7) -> 0, Sunday(7) -> 1, ..., Friday(5) -> 6
    final d = gregorian.weekday;
    return (d + 1) % 7;
  }

  /// Get Persian name of the month
  String get monthName => monthNames[month];

  /// Get Persian name of the day of week
  String get dayOfWeekName => dayOfWeekNames[weekDay];

  /// Format as yyyy/MM/dd
  String format() {
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$year/$m/$d';
  }

  /// Format with Persian digits
  String formatPersian() {
    return PersianNumber.toPersian(format());
  }

  /// Format as "dd MonthName yyyy" (e.g., "15 آذر 1403")
  String formatWithMonthName() {
    return '$day ${monthNames[month]} $year';
  }

  /// Format as "dd MonthName yyyy" with Persian digits
  String formatWithMonthNamePersian() {
    return '${PersianNumber.toPersian(day.toString())} ${monthNames[month]} ${PersianNumber.toPersian(year.toString())}';
  }

  /// Format as "DayName dd MonthName yyyy"
  String formatFull() {
    return '${dayOfWeekNames[weekDay]} $day ${monthNames[month]} $year';
  }

  /// Format as "DayName dd MonthName yyyy" with Persian digits
  String formatFullPersian() {
    return '${dayOfWeekNames[weekDay]} ${PersianNumber.toPersian(day.toString())} ${monthNames[month]} ${PersianNumber.toPersian(year.toString())}';
  }

  /// Add days to this date
  JalaliDate addDays(int days) {
    final gregorian = toDateTime().add(Duration(days: days));
    return fromDateTime(gregorian);
  }

  /// Add months to this date
  JalaliDate addMonths(int months) {
    int newYear = year;
    int newMonth = month + months;

    while (newMonth > 12) {
      newMonth -= 12;
      newYear++;
    }
    while (newMonth < 1) {
      newMonth += 12;
      newYear--;
    }

    // Clamp day to valid range for the new month
    final maxDay = _getDaysInMonth(newYear, newMonth);
    final newDay = day > maxDay ? maxDay : day;

    return JalaliDate(newYear, newMonth, newDay);
  }

  /// Subtract days from this date
  JalaliDate subtractDays(int days) => addDays(-days);

  /// Subtract months from this date
  JalaliDate subtractMonths(int months) => addMonths(-months);

  /// Get first day of the month
  JalaliDate get firstDayOfMonth => JalaliDate(year, month, 1);

  /// Get last day of the month
  JalaliDate get lastDayOfMonth => JalaliDate(year, month, daysInMonth);

  /// Compare this date with another
  int compareTo(JalaliDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  /// Check if this date is before another
  bool isBefore(JalaliDate other) => compareTo(other) < 0;

  /// Check if this date is after another
  bool isAfter(JalaliDate other) => compareTo(other) > 0;

  /// Check if this date is the same as another
  bool isSameDay(JalaliDate other) =>
      year == other.year && month == other.month && day == other.day;

  /// Check if this date is today
  bool get isToday => isSameDay(JalaliDate.now());

  @override
  bool operator ==(Object other) =>
      other is JalaliDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'JalaliDate($year, $month, $day)';

  // ============= CONVERSION ALGORITHMS =============
  // Using the proven 33-year cycle algorithm (standard Persian calendar)

  /// Days at the start of each Gregorian month
  static const List<int> _gDaysInMonth = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];

  /// Check if a Jalali year is a leap year using 33-year cycle
  static bool _isJalaliLeapYear(int year) {
    // Leap years in the 33-year cycle: 1, 5, 9, 13, 17, 22, 26, 30
    final breaks = [1, 5, 9, 13, 17, 22, 26, 30];
    final cycle = year > 0 ? ((year - 1) % 33) + 1 : ((year % 33) + 33) % 33;
    return breaks.contains(cycle == 0 ? 33 : cycle);
  }

  /// Get days in a specific Jalali month
  static int _getDaysInMonth(int year, int month) {
    if (month >= 1 && month <= 6) return 31;
    if (month >= 7 && month <= 11) return 30;
    if (month == 12) return _isJalaliLeapYear(year) ? 30 : 29;
    return 0;
  }

  /// Convert Gregorian date to Jalali date
  /// Uses the proven 33-year cycle algorithm
  static JalaliDate _gregorianToJalali(int gy, int gm, int gd) {
    int jy;
    
    if (gy > 1600) {
      jy = 979;
      gy -= 1600;
    } else {
      jy = 0;
      gy -= 621;
    }
    
    int gy2 = (gm > 2) ? (gy + 1) : gy;
    int days = (365 * gy) + 
               ((gy2 + 3) ~/ 4) - 
               ((gy2 + 99) ~/ 100) + 
               ((gy2 + 399) ~/ 400) - 
               80 + gd + _gDaysInMonth[gm - 1];
    
    jy += 33 * (days ~/ 12053);
    days %= 12053;
    jy += 4 * (days ~/ 1461);
    days %= 1461;
    
    if (days > 365) {
      jy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }
    
    int jm = (days < 186) ? 1 + (days ~/ 31) : 7 + ((days - 186) ~/ 30);
    int jd = 1 + ((days < 186) ? (days % 31) : ((days - 186) % 30));
    
    return JalaliDate(jy, jm, jd);
  }

  /// Convert Jalali date to Gregorian DateTime
  /// Uses the proven 33-year cycle algorithm
  static DateTime _jalaliToGregorian(int jy, int jm, int jd) {
    int gy;
    
    if (jy > 979) {
      gy = 1600;
      jy -= 979;
    } else {
      gy = 621;
    }
    
    int days = (365 * jy) + 
               ((jy ~/ 33) * 8) + 
               (((jy % 33) + 3) ~/ 4) + 
               78 + jd + 
               ((jm < 7) ? (jm - 1) * 31 : ((jm - 7) * 30) + 186);
    
    gy += 400 * (days ~/ 146097);
    days %= 146097;
    
    if (days > 36524) {
      gy += 100 * (--days ~/ 36524);
      days %= 36524;
      if (days >= 365) days++;
    }
    
    gy += 4 * (days ~/ 1461);
    days %= 1461;
    
    if (days > 365) {
      gy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }
    
    int gd = days + 1;
    
    // Days in each Gregorian month
    List<int> sal_a = [
      0, 31, 
      ((gy % 4 == 0 && gy % 100 != 0) || (gy % 400 == 0)) ? 29 : 28,
      31, 30, 31, 30, 31, 31, 30, 31, 30, 31
    ];
    
    int gm = 0;
    while (gm < 13 && gd > sal_a[gm]) {
      gd -= sal_a[gm++];
    }
    
    return DateTime(gy, gm, gd);
  }

  /// Parse a Jalali date string (format: yyyy/MM/dd)
  static JalaliDate? parse(String dateString) {
    try {
      // Convert Persian digits to English first
      final normalized = PersianNumber.toEnglish(dateString);
      final parts = normalized.split('/');
      if (parts.length != 3) return null;

      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      // Validate
      if (month < 1 || month > 12) return null;
      if (day < 1 || day > _getDaysInMonth(year, month)) return null;

      return JalaliDate(year, month, day);
    } catch (e) {
      return null;
    }
  }

  /// Validate if a given Jalali date is valid
  static bool isValid(int year, int month, int day) {
    if (month < 1 || month > 12) return false;
    if (day < 1) return false;
    if (day > _getDaysInMonth(year, month)) return false;
    return true;
  }
}

/// Extension on DateTime for easy Jalali conversion
extension DateTimeJalaliExtension on DateTime {
  /// Convert to JalaliDate
  JalaliDate toJalali() => JalaliDate.fromDateTime(this);

  /// Format as Jalali date string
  String toJalaliString() => toJalali().format();

  /// Format as Jalali date string with Persian digits
  String toJalaliPersianString() => toJalali().formatPersian();
}
