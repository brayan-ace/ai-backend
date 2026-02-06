import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'app_language';
  // static const String _defaultLanguage = 'en';

  static const Map<String, Map<String, String>> _languageNames = {
    'en': {'native': 'English', 'code': 'en'},
    'es': {'native': 'Español', 'code': 'es'},
    'fr': {'native': 'Français', 'code': 'fr'},
    'ar': {'native': 'العربية', 'code': 'ar'},
    'hi': {'native': 'हिंदी', 'code': 'hi'},
  };

  late SharedPreferences _prefs;
  late Locale _currentLocale;
  bool _isInitialized = false;

  Locale get currentLocale => _currentLocale;
  String get currentLanguageCode => _currentLocale.languageCode;
  bool get isArabic => _currentLocale.languageCode == 'ar';
  bool get isRTL => _currentLocale.languageCode == 'ar';
  bool get isInitialized => _isInitialized;

  static Map<String, String> get languageNames =>
      _languageNames.map((key, value) => MapEntry(key, value['native']!));

  LanguageProvider() {
    _currentLocale = const Locale('en');
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final savedLanguage = _prefs.getString(_languageKey);

    if (savedLanguage != null && _languageNames.containsKey(savedLanguage)) {
      _currentLocale = Locale(savedLanguage);
    } else {
      // Try device language
      final deviceLocale = WidgetsBinding.instance.window.locale;
      if (_languageNames.containsKey(deviceLocale.languageCode)) {
        _currentLocale = Locale(deviceLocale.languageCode);
      } else {
        _currentLocale = const Locale('en');
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    if (!_languageNames.containsKey(languageCode)) {
      return;
    }

    if (_currentLocale.languageCode == languageCode) {
      return;
    }

    _currentLocale = Locale(languageCode);
    await _prefs.setString(_languageKey, languageCode);
    notifyListeners();
  }

  bool isSupportedLanguage(String languageCode) {
    return _languageNames.containsKey(languageCode);
  }

  String getLanguageName(String languageCode) {
    return _languageNames[languageCode]?['native'] ?? languageCode;
  }

  List<String> get supportedLanguageCodes => _languageNames.keys.toList();
}
