// Script to fix persian_datetime_picker compatibility issues with Flutter 3.9
// Run this after: flutter pub get
// Usage: dart fix_persian_picker.dart

import 'dart:io';

void main() {
  final pubCache =
      Platform.environment['PUB_CACHE'] ??
      Platform.environment['LOCALAPPDATA']! + r'\Pub\Cache\hosted\pub.dev';

  final packagePath = '$pubCache/persian_datetime_picker-2.7.0/lib/src';

  print('Fixing persian_datetime_picker compatibility issues...');

  // Fix 1: ptime_picker.dart
  _fixFile(
    '$packagePath/ptime_picker.dart',
    'timePickerTheme.inputDecorationTheme;',
    'timePickerTheme.inputDecorationTheme as InputDecorationTheme?;',
  );

  // Fix 2: pdate_picker_dialog.dart
  _fixFile(
    '$packagePath/pdate_picker_dialog.dart',
    'final DialogTheme dialogTheme = Theme.of(context).dialogTheme;',
    'final DialogTheme dialogTheme = Theme.of(context).dialogTheme as DialogTheme;',
  );

  // Fix 3: pdate_picker_common.dart - replace hashValues with Object.hash
  _fixFile(
    '$packagePath/pdate_picker_common.dart',
    'int get hashCode => hashValues(start, end);',
    'int get hashCode => Object.hash(start, end);',
  );

  // Fix 4: pdate_range_picker_dialog.dart
  _fixFile(
    '$packagePath/pdate_range_picker_dialog.dart',
    'final DialogTheme dialogTheme = Theme.of(context).dialogTheme;',
    'final DialogTheme dialogTheme = Theme.of(context).dialogTheme as DialogTheme;',
  );

  // Fix 5: pinput_date_range_picker.dart
  _fixFile(
    '$packagePath/pinput_date_range_picker.dart',
    'Theme.of(context).inputDecorationTheme;',
    'Theme.of(context).inputDecorationTheme as InputDecorationTheme;',
  );
}

void _fixFile(String filePath, String oldText, String newText) {
  try {
    final file = File(filePath);
    if (!file.existsSync()) {
      print('Warning: File not found: $filePath');
      return;
    }

    String content = file.readAsStringSync();
    if (content.contains(oldText)) {
      content = content.replaceAll(oldText, newText);
      file.writeAsStringSync(content);
      print('Fixed: ${filePath.split('/').last}');
    } else {
      print('Already fixed or pattern not found: ${filePath.split('/').last}');
    }
  } catch (e) {
    print('Error fixing $filePath: $e');
  }
}
