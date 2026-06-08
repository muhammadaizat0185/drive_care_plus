import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService instance = ThemeService._internal();

  ThemeService._internal();

  // Selected theme parameters
  Color _primaryColor = const Color(0xFF1B8A5A); // Default Premium Emerald Green
  ThemeMode _themeMode = ThemeMode.light;

  Color get primaryColor => _primaryColor;
  ThemeMode get themeMode => _themeMode;

  // Modern preset palettes for users to choose
  static const Map<String, Color> presets = {
    'Emerald Green': Color(0xFF1B8A5A),
    'Mint Fresh': Color(0xFF10B981),
    'Teal Ocean': Color(0xFF0F766E),
    'Classic Blue': Color(0xFF1E40AF),
    'Dark Charcoal': Color(0xFF1F2937),
    'Berry Red': Color(0xFFBE123C),
    'Nordic Steel': Color(0xFF475569),
  };

  // Load theme configuration from preferences
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorValue = prefs.getInt('theme_primary_color');
      if (colorValue != null) {
        _primaryColor = Color(colorValue);
      }
      final modeIndex = prefs.getInt('theme_mode_index');
      if (modeIndex != null) {
        _themeMode = ThemeMode.values[modeIndex];
      }
    } catch (e) {
      debugPrint('Error loading theme settings: $e');
    }
    notifyListeners();
  }

  // Update and persist primary color
  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      // ignore: deprecated_member_use
      await prefs.setInt('theme_primary_color', color.value);
    } catch (e) {
      debugPrint('Error saving primary color: $e');
    }
  }

  // Update primary color in memory without persisting (for trial preview)
  void previewPrimaryColor(Color color) {
    _primaryColor = color;
    notifyListeners();
  }

  // Update and persist theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_mode_index', mode.index);
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }
}
