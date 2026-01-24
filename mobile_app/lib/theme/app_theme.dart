import 'package:flutter/material.dart';

class AppTheme {
  // Figma Spec: Light Mode Colors
  static const Color lightBgStart = Color(0xFFF8FBFF);
  static const Color lightBgEnd = Color(0xFFDDF2FF);
  static const Color lightPrimaryBlue = Color(0xFF2FA4FF);
  static const Color lightTextPrimary = Color(0xFF0A2540);

  // Figma Spec: Dark Mode Colors
  static const Color darkBgStart = Color(0xFF1E1E2C); // Softer Charcoal
  static const Color darkBgEnd = Color(0xFF2D2D44);
  static const Color darkAccentCyan = Color(0xFF2ED9FF);
  static const Color darkTextPrimary = Color(0xFFEAF6FF);
  
  // Backward Compatibility / Shared Brand Colors
  static const Color primaryColor = lightPrimaryBlue; // Map to new blue
  static const Color secondaryColor = darkAccentCyan; // Map to new cyan

  // Button Gradient
  static const Color btnGradientTop = Color(0xFF4FC3FF);
  static const Color btnGradientBottom = Color(0xFF1E88E5);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: lightPrimaryBlue,
      scaffoldBackgroundColor: lightBgStart, // Default, handled by gradient bg
      fontFamily: 'Outfit',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(color: lightTextPrimary, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: lightTextPrimary),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: lightTextPrimary),
        bodyLarge: TextStyle(fontSize: 16, color: lightTextPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: lightTextPrimary),
      ),
      colorScheme: const ColorScheme.light(
        primary: lightPrimaryBlue,
        secondary: lightPrimaryBlue,
        surface: Colors.white,
        onSurface: lightTextPrimary,
      ),
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: darkAccentCyan,
      scaffoldBackgroundColor: darkBgStart,
      fontFamily: 'Outfit',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(color: darkTextPrimary, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: darkTextPrimary),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: darkTextPrimary),
        bodyLarge: TextStyle(fontSize: 16, color: darkTextPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: darkTextPrimary),
      ),
      colorScheme: const ColorScheme.dark(
        primary: darkAccentCyan,
        secondary: darkAccentCyan,
        surface: Color(0xFF0A1E30),
        onSurface: darkTextPrimary,
      ),
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
