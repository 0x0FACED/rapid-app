import 'package:flutter/material.dart';

class AppTheme {
  // Tokyo Night Theme (Dark)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF7AA2F7), // Tokyo Night Blue
        secondary: Color(0xFF9ECE6A), // Tokyo Night Green
        surface: Color(0xFF1A1B26), // Background
        surfaceContainerHighest: Color(0xFF24283B), // Elevated bg
        error: Color(0xFFF7768E), // Red
        onPrimary: Color(0xFF1A1B26),
        onSecondary: Color(0xFF1A1B26),
        onSurface: Color(0xFFC0CAF5), // Text
        onError: Color(0xFF1A1B26),
      ),

      scaffoldBackgroundColor: const Color(0xFF1A1B26),

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1B26),
        elevation: 0,
        centerTitle: true,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF24283B),
        selectedItemColor: Color(0xFF7AA2F7),
        unselectedItemColor: Color(0xFF565F89),
        type: BottomNavigationBarType.fixed,
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF24283B),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF24283B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // Light (Grey) Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      colorScheme: const ColorScheme.light(
        primary: Color(0xFF5C6BC0),
        secondary: Color(0xFF66BB6A),
        surface: Color(0xFFF5F5F5),
        surfaceContainerHighest: Color(0xFFEEEEEE),
        error: Color(0xFFE57373),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF424242),
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: const Color(0xFFF5F5F5),

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFEEEEEE),
        elevation: 0,
        centerTitle: true,
        foregroundColor: Color(0xFF424242),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFEEEEEE),
        selectedItemColor: Color(0xFF5C6BC0),
        unselectedItemColor: Color(0xFF9E9E9E),
        type: BottomNavigationBarType.fixed,
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
    );
  }
}
