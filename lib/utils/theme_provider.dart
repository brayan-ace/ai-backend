import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  double _textScaleFactor = 1.0;

  ThemeMode get themeMode => _themeMode;
  double get textScaleFactor => _textScaleFactor;

  ThemeProvider() {
    _loadFromPreferences();
  }

  Future<void> _loadFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeStr = prefs.getString('theme_mode') ?? 'dark';
    _textScaleFactor = prefs.getDouble('text_size') ?? 1.0;

    switch (themeModeStr) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      case 'system':
        _themeMode = ThemeMode.system;
        break;
      default:
        _themeMode = ThemeMode.dark;
    }

    notifyListeners();
  }

  Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode);

    switch (mode) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      case 'system':
        _themeMode = ThemeMode.system;
        break;
    }

    notifyListeners();
  }

  Future<void> setTextScaleFactor(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('text_size', scale);
    _textScaleFactor = scale;
    notifyListeners();
  }
}
