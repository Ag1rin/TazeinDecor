// Persian number utilities
import 'package:intl/intl.dart';

class PersianNumber {
  static const Map<String, String> _englishToPersian = {
    '0': '۰',
    '1': '۱',
    '2': '۲',
    '3': '۳',
    '4': '۴',
    '5': '۵',
    '6': '۶',
    '7': '۷',
    '8': '۸',
    '9': '۹',
  };
  
  static const Map<String, String> _persianToEnglish = {
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
  };
  
  static String toPersian(String text) {
    String result = text;
    _englishToPersian.forEach((en, fa) {
      result = result.replaceAll(en, fa);
    });
    return result;
  }
  
  static String toEnglish(String text) {
    String result = text;
    _persianToEnglish.forEach((fa, en) {
      result = result.replaceAll(fa, en);
    });
    return result;
  }
  
  static String formatPrice(double price) {
    final formatter = NumberFormat('#,###');
    return toPersian(formatter.format(price));
  }
  
  static String formatNumber(int number) {
    final formatter = NumberFormat('#,###');
    return toPersian(formatter.format(number));
  }

  /// Formats a double number to a string and converts to Persian digits.
  /// [decimalDigits] determines the number of decimal places.
  /// If not specified, uses `toString()` for minimal decimals.
  /// Examples:
  /// formatDecimal(12.0) -> "۱۲"
  /// formatDecimal(12.5) -> "۱۲.۵"
  /// formatDecimal(12.567, decimalDigits: 2) -> "۱۲.۵۷"
  /// formatDecimal(12.001, decimalDigits: 2) -> "۱۲.۰۰"
  static String formatDecimal(double number, {int? decimalDigits}) {
    String englishNumberString;
    if (decimalDigits != null) {
      englishNumberString = number.toStringAsFixed(decimalDigits);
    } else {
      englishNumberString = number.toString();
      // Remove trailing ".0" if it's an integer to keep it clean, e.g., "12.0" becomes "12"
      if (englishNumberString.endsWith('.0')) {
        englishNumberString = englishNumberString.substring(0, englishNumberString.length - 2);
      }
    }
    return toPersian(englishNumberString);
  }
  
  static String formatNumberString(String numberStr) {
    try {
      final number = int.parse(numberStr);
      return formatNumber(number);
    } catch (e) {
      return numberStr;
    }
  }
}

