import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing app settings and capabilities
class SettingsService {
  static const String _webSearchKey = 'capability_web_search';
  static const String _quizArtifactKey = 'capability_quiz_artifact';
  static const String _colorModeKey = 'color_mode';

  static SettingsService? _instance;
  SharedPreferences? _prefs;

  SettingsService._();

  /// Singleton instance
  static SettingsService get instance {
    _instance ??= SettingsService._();
    return _instance!;
  }

  /// Initialize the service (call once at app startup)
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get the current user's UID for key prefixing
  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  /// Build a user-specific key
  String _userKey(String key) {
    final uid = _currentUid;
    if (uid == null) return key;
    return '${uid}_$key';
  }

  // Capability Settings
  Future<bool> getWebSearchCapability() async {
    await init();
    if (_prefs == null) return false; // Default to disabled
    return _prefs!.getBool(_userKey(_webSearchKey)) ?? false;
  }

  Future<void> setWebSearchCapability(bool enabled) async {
    await init();
    if (_prefs == null) return;
    await _prefs!.setBool(_userKey(_webSearchKey), enabled);
  }

  Future<bool> getQuizArtifactCapability() async {
    await init();
    if (_prefs == null) return true; // Default to enabled
    return _prefs!.getBool(_userKey(_quizArtifactKey)) ?? true;
  }

  Future<void> setQuizArtifactCapability(bool enabled) async {
    await init();
    if (_prefs == null) return;
    await _prefs!.setBool(_userKey(_quizArtifactKey), enabled);
  }

  // Color Mode Settings
  Future<String> getColorMode() async {
    await init();
    if (_prefs == null) return 'dark'; // Default to dark
    return _prefs!.getString(_userKey(_colorModeKey)) ?? 'dark';
  }

  Future<void> setColorMode(String mode) async {
    await init();
    if (_prefs == null) return;
    await _prefs!.setString(_userKey(_colorModeKey), mode);
  }

  // Synchronous getters for immediate UI updates
  bool getWebSearchCapabilitySync() {
    if (_prefs == null) return false;
    return _prefs!.getBool(_userKey(_webSearchKey)) ?? false;
  }

  bool getQuizArtifactCapabilitySync() {
    if (_prefs == null) return true;
    return _prefs!.getBool(_userKey(_quizArtifactKey)) ?? true;
  }

  String getColorModeSync() {
    if (_prefs == null) return 'dark';
    return _prefs!.getString(_userKey(_colorModeKey)) ?? 'dark';
  }
}
