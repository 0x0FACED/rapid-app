import 'package:flutter/material.dart';

class AppTheme {
  // Tokyo Night цвета
  static const _backgroundDark = Color(0xFF1a1b26);
  static const _surfaceDark = Color(0xFF16161e);
  static const _surfaceVariant = Color(0xFF24283b);

  // Акцентные цвета Tokyo Night
  static const _primary = Color(0xFF7aa2f7); // Синий
  static const _secondary = Color(0xFFbb9af7); // Фиолетовый
  static const _success = Color.fromARGB(255, 79, 145, 9); // Зелёный
  static const _warning = Color(0xFFe0af68); // Жёлтый
  static const _error = Color(0xFFf7768e); // Красный

  static const _textPrimary = Color(0xFFc0caf5);
  static const _textSecondary = Color(0xFF9aa5ce);
  static const _textDisabled = Color(0xFF565f89);
  // Tokyo Night Theme (Dark)
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      colorScheme: ColorScheme.dark(
        brightness: Brightness.dark,
        primary: _primary,
        onPrimary: _backgroundDark,
        secondary: _secondary,
        onSecondary: _backgroundDark,
        tertiary: _success, // Зелёный как tertiary
        onTertiary: _backgroundDark,
        error: _error,
        onError: _backgroundDark,
        surface: _surfaceDark,
        onSurface: _textPrimary,
        surfaceContainerHighest: _surfaceVariant,
        outline: _textDisabled,
      ),

      scaffoldBackgroundColor: _backgroundDark,

      cardTheme: CardThemeData(
        color: _surfaceDark,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: _backgroundDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: _textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: _textPrimary),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primary, width: 2),
        ),
      ),

      textTheme: TextTheme(
        displayLarge: TextStyle(color: _textPrimary),
        displayMedium: TextStyle(color: _textPrimary),
        displaySmall: TextStyle(color: _textPrimary),
        headlineLarge: TextStyle(color: _textPrimary),
        headlineMedium: TextStyle(color: _textPrimary),
        headlineSmall: TextStyle(color: _textPrimary),
        titleLarge: TextStyle(color: _textPrimary),
        titleMedium: TextStyle(color: _textPrimary),
        titleSmall: TextStyle(color: _textPrimary),
        bodyLarge: TextStyle(color: _textPrimary),
        bodyMedium: TextStyle(color: _textPrimary),
        bodySmall: TextStyle(color: _textSecondary),
        labelLarge: TextStyle(color: _textPrimary),
        labelMedium: TextStyle(color: _textPrimary),
        labelSmall: TextStyle(color: _textSecondary),
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
