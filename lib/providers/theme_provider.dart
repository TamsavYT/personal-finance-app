import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeString = prefs.getString('theme_mode') ?? 'dark';

      switch (themeString) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'system':
          _themeMode = ThemeMode.system;
          break;
        case 'dark':
        default:
          _themeMode = ThemeMode.dark;
          break;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  Future<void> toggleTheme() async {
    try {
      if (_themeMode == ThemeMode.dark) {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.dark;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'theme_mode',
        _themeMode == ThemeMode.dark ? 'dark' : 'light',
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling theme: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      _themeMode = mode;

      final prefs = await SharedPreferences.getInstance();
      String themeString;
      switch (mode) {
        case ThemeMode.light:
          themeString = 'light';
          break;
        case ThemeMode.system:
          themeString = 'system';
          break;
        case ThemeMode.dark:
        default:
          themeString = 'dark';
          break;
      }
      await prefs.setString('theme_mode', themeString);

      notifyListeners();
    } catch (e) {
      debugPrint('Error setting theme mode: $e');
    }
  }
}
