// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData buildTheme(Color baseColor, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    
    // Adjust primary color for contrast based on theme mode
    final hsl = HSLColor.fromColor(baseColor);
    final Color adjustedPrimary = isDark 
      ? hsl.withLightness((hsl.lightness + 0.35).clamp(0.0, 0.9)).withSaturation((hsl.saturation + 0.3).clamp(0.0, 1.0)).toColor()
      : hsl.withLightness((hsl.lightness - 0.1).clamp(0.2, 1.0)).toColor();

    final colorScheme = ColorScheme.fromSeed(
      seedColor: adjustedPrimary,
      primary: adjustedPrimary,
      brightness: brightness,
      surface: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1F2937),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          backgroundColor: adjustedPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
            width: 1.0,
          ),
        ),
      ),
    );
  }
}
