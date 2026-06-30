import 'package:flutter/material.dart';

class AppTheme {
  // High contrast colors for outdoor/solar visibility
  static const Color primaryColor = Color(0xFF00FF88); // Bright green
  static const Color backgroundColor = Color(0xFF0A0A0A); // Deep black
  static const Color surfaceColor = Color(0xFF1A1A1A); // Dark surface
  static const Color cardColor = Color(0xFF2A2A2A); // Card background
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color recordingRed = Color(0xFFFF3333); // Bright red
  static const Color pausedAmber = Color(0xFFFFD700); // Bright amber
  static const Color successGreen = Color(0xFF00FF00); // Neon green
  static const Color errorRed = Color(0xFFFF0000); // Pure red
  static const Color warningOrange = Color(0xFFFF8800); // Bright orange

  // High contrast text styles
  static const TextStyle highContrastText = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
    fontSize: 16,
  );

  static const TextStyle highContrastLargeText = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
    fontSize: 24,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: primaryColor,
        surface: surfaceColor,
        error: errorRed,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textPrimary,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: textPrimary,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: textSecondary,
          fontSize: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.black,
          minimumSize: Size(double.infinity, 56), // Larger touch target
          textStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceColor,
        contentTextStyle: TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      iconTheme: IconThemeData(
        color: Colors.white,
        size: 28,
      ),
    );
  }
}
