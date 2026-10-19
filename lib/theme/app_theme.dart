
import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.green,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF101810),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4CAF50),
      brightness: Brightness.dark,
      surface: const Color(0xFF1B281D),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF101810),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFF1B281D),
      elevation: 2,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1B281D),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF4CAF50),
          width: 2,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    useMaterial3: true,
  );
}
