import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  double _textScaleFactor = 0.91; // Default: 91% text size
  String _fontFamily = 'Georgia'; // Default font

  ThemeMode get themeMode => _themeMode;
  double get textScaleFactor => _textScaleFactor;
  String get fontFamily => _fontFamily;

  ThemeProvider() {
    _loadFromPreferences();
  }

  Future<void> _loadFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeStr = prefs.getString('theme_mode') ?? 'dark';
    _textScaleFactor =
        prefs.getDouble('text_size') ?? 0.91; // Default: 91% text size
    _fontFamily = prefs.getString('font_family') ?? 'Georgia'; // Default font

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

    // Update AppTheme's current font family
    AppTheme.updateFontFamily(_fontFamily);

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

  Future<void> setFontFamily(String fontFamily) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_family', fontFamily);
    _fontFamily = fontFamily;
    AppTheme.updateFontFamily(fontFamily);
    notifyListeners();
  }
}
