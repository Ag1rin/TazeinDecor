# Vazir Font Setup

## ✅ Font Configuration Complete

The Vazir font (Persian/Farsi) has been configured for the entire app.

## Font Files Location

All Vazir font files are in: `frontend/assets/fonts/`

- Vazirmatn-Thin.ttf (weight: 100)
- Vazirmatn-ExtraLight.ttf (weight: 200)
- Vazirmatn-Light.ttf (weight: 300)
- Vazirmatn-Regular.ttf (weight: 400) - Default
- Vazirmatn-Medium.ttf (weight: 500)
- Vazirmatn-SemiBold.ttf (weight: 600)
- Vazirmatn-Bold.ttf (weight: 700)
- Vazirmatn-ExtraBold.ttf (weight: 800)
- Vazirmatn-Black.ttf (weight: 900)

## Configuration

### pubspec.yaml
- ✅ Fonts section added with all Vazir weights
- ✅ Assets folder configured

### main.dart
- ✅ Default fontFamily set to 'Vazir'
- ✅ All TextTheme styles use Vazir font

## Usage

The font is now applied globally to all text in the app. You can also use it explicitly:

```dart
Text(
  'متن فارسی',
  style: TextStyle(
    fontFamily: 'Vazir',
    fontWeight: FontWeight.bold, // Uses Vazirmatn-Bold.ttf
  ),
)
```

## Font Weights

- `FontWeight.w100` → Vazirmatn-Thin
- `FontWeight.w200` → Vazirmatn-ExtraLight
- `FontWeight.w300` → Vazirmatn-Light
- `FontWeight.w400` → Vazirmatn-Regular (default)
- `FontWeight.w500` → Vazirmatn-Medium
- `FontWeight.w600` → Vazirmatn-SemiBold
- `FontWeight.w700` → Vazirmatn-Bold
- `FontWeight.w800` → Vazirmatn-ExtraBold
- `FontWeight.w900` → Vazirmatn-Black

## After Setup

Run:
```bash
flutter pub get
flutter clean
flutter run
```

The font should now be applied to all text in your app!

## Download Vazir Font

If you need to download the font files, visit:
https://github.com/rastikerdar/vazir-font

Download the TTF files and place them in `frontend/assets/fonts/`

