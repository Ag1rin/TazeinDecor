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
  
  static String formatNumberString(String numberStr) {
    try {
      final number = int.parse(numberStr);
      return formatNumber(number);
    } catch (e) {
      return numberStr;
    }
  }
}

