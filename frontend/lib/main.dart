library;

// Main entry point

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/invoice_provider.dart';
import 'widgets/connectivity_wrapper.dart';
import 'pages/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations (optional)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => InvoiceProvider()),
      ],
      child: Directionality(
        // IMPROVED: Ensure RTL support at app level
        textDirection: TextDirection.rtl,
        child: MaterialApp(
          title: 'Tazein Decor',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          fontFamily: 'Vazir', // Persian/Farsi font
          // Apply Vazir to all text styles
          textTheme: const TextTheme(
            displayLarge: TextStyle(fontFamily: 'Vazir'),
            displayMedium: TextStyle(fontFamily: 'Vazir'),
            displaySmall: TextStyle(fontFamily: 'Vazir'),
            headlineLarge: TextStyle(fontFamily: 'Vazir'),
            headlineMedium: TextStyle(fontFamily: 'Vazir'),
            headlineSmall: TextStyle(fontFamily: 'Vazir'),
            titleLarge: TextStyle(fontFamily: 'Vazir'),
            titleMedium: TextStyle(fontFamily: 'Vazir'),
            titleSmall: TextStyle(fontFamily: 'Vazir'),
            bodyLarge: TextStyle(fontFamily: 'Vazir'),
            bodyMedium: TextStyle(fontFamily: 'Vazir'),
            bodySmall: TextStyle(fontFamily: 'Vazir'),
            labelLarge: TextStyle(fontFamily: 'Vazir'),
            labelMedium: TextStyle(fontFamily: 'Vazir'),
            labelSmall: TextStyle(fontFamily: 'Vazir'),
          ),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          // Custom Jalali date picker implemented (no external package needed)
        ],
        supportedLocales: const [
          Locale('fa', 'IR'), // Persian
          Locale('en', 'US'),
        ],
        locale: const Locale('fa', 'IR'),
        home: const ConnectivityWrapper(child: SplashScreen()),
        ),
      ),
    );
  }
}
