# PowerShell script to fix persian_datetime_picker compatibility issues with Flutter 3.9
# Run this after: flutter pub get
# Usage: .\fix_persian_picker.ps1

$pubCache = $env:PUB_CACHE
if (-not $pubCache) {
    $pubCache = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev"
}

$packagePath = "$pubCache\persian_datetime_picker-2.7.0\lib\src"

Write-Host "Fixing persian_datetime_picker compatibility issues..." -ForegroundColor Green

if (-not (Test-Path $packagePath)) {
    Write-Host "Error: Package not found at $packagePath" -ForegroundColor Red
    Write-Host "Please run 'flutter pub get' first" -ForegroundColor Yellow
    exit 1
}

# Fix 1: ptime_picker.dart
$file1 = "$packagePath\ptime_picker.dart"
if (Test-Path $file1) {
    (Get-Content $file1) -replace 'timePickerTheme\.inputDecorationTheme;', 'timePickerTheme.inputDecorationTheme as InputDecorationTheme?;' | Set-Content $file1
    Write-Host "Fixed: ptime_picker.dart" -ForegroundColor Green
}

# Fix 2: pdate_picker_dialog.dart
$file2 = "$packagePath\pdate_picker_dialog.dart"
if (Test-Path $file2) {
    (Get-Content $file2) -replace 'final DialogTheme dialogTheme = Theme\.of\(context\)\.dialogTheme;', 'final DialogTheme dialogTheme = Theme.of(context).dialogTheme as DialogTheme;' | Set-Content $file2
    Write-Host "Fixed: pdate_picker_dialog.dart" -ForegroundColor Green
}

# Fix 3: pdate_picker_common.dart - replace hashValues with Object.hash
$file3 = "$packagePath\pdate_picker_common.dart"
if (Test-Path $file3) {
    (Get-Content $file3) -replace 'int get hashCode => hashValues\(start, end\);', 'int get hashCode => Object.hash(start, end);' | Set-Content $file3
    Write-Host "Fixed: pdate_picker_common.dart" -ForegroundColor Green
}

# Fix 4: pdate_range_picker_dialog.dart
$file4 = "$packagePath\pdate_range_picker_dialog.dart"
if (Test-Path $file4) {
    (Get-Content $file4) -replace 'final DialogTheme dialogTheme = Theme\.of\(context\)\.dialogTheme;', 'final DialogTheme dialogTheme = Theme.of(context).dialogTheme as DialogTheme;' | Set-Content $file4
    Write-Host "Fixed: pdate_range_picker_dialog.dart" -ForegroundColor Green
}

# Fix 5: pinput_date_range_picker.dart
$file5 = "$packagePath\pinput_date_range_picker.dart"
if (Test-Path $file5) {
    (Get-Content $file5) -replace 'Theme\.of\(context\)\.inputDecorationTheme;', 'Theme.of(context).inputDecorationTheme as InputDecorationTheme;' | Set-Content $file5
    Write-Host "Fixed: pinput_date_range_picker.dart" -ForegroundColor Green
}

Write-Host "`nDone! All files have been patched." -ForegroundColor Green
Write-Host "You can now run: flutter run" -ForegroundColor Yellow

