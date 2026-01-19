import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing user profile data (username, preferences)
/// Uses SharedPreferences for local storage with Firebase UID as key prefix
class UserProfileService {
  static const String _usernameKey = 'user_username';
  static const String _onboardingCompleteKey = 'onboarding_complete';
  
  static UserProfileService? _instance;
  SharedPreferences? _prefs;
  
  UserProfileService._();
  
  /// Singleton instance
  static UserProfileService get instance {
    _instance ??= UserProfileService._();
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
  
  /// Save username for the current user
  Future<bool> saveUsername(String username) async {
    await init();
    if (_prefs == null || _currentUid == null) return false;
    return await _prefs!.setString(_userKey(_usernameKey), username.trim());
  }
  
  /// Get username for the current user
  /// Returns null if not set or user not logged in
  Future<String?> getUsername() async {
    await init();
    if (_prefs == null || _currentUid == null) return null;
    return _prefs!.getString(_userKey(_usernameKey));
  }
  
  /// Get username synchronously (requires init() to be called first)
  String? getUsernameSync() {
    if (_prefs == null || _currentUid == null) return null;
    return _prefs!.getString(_userKey(_usernameKey));
  }
  
  /// Check if onboarding has been completed
  Future<bool> isOnboardingComplete() async {
    await init();
    if (_prefs == null) return false;
    return _prefs!.getBool(_onboardingCompleteKey) ?? false;
  }
  
  /// Mark onboarding as complete
  Future<bool> setOnboardingComplete(bool complete) async {
    await init();
    if (_prefs == null) return false;
    return await _prefs!.setBool(_onboardingCompleteKey, complete);
  }
  
  /// Clear all user data (for logout)
  Future<void> clearUserData() async {
    await init();
    if (_prefs == null || _currentUid == null) return;
    await _prefs!.remove(_userKey(_usernameKey));
  }
  
  /// Get display name with fallback
  /// Priority: stored username > Firebase displayName > email prefix > "User"
  Future<String> getDisplayName() async {
    await init();
    
    // Try stored username first
    final username = await getUsername();
    if (username != null && username.isNotEmpty) {
      return username;
    }
    
    // Try Firebase displayName
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    
    // Try email prefix
    if (user?.email != null && user!.email!.isNotEmpty) {
      final emailPrefix = user.email!.split('@').first;
      if (emailPrefix.isNotEmpty) {
        return emailPrefix;
      }
    }
    
    // Fallback
    return 'User';
  }
  
  /// Get display name synchronously with fallback
  String getDisplayNameSync() {
    // Try stored username first
    final username = getUsernameSync();
    if (username != null && username.isNotEmpty) {
      return username;
    }
    
    // Try Firebase displayName
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    
    // Try email prefix
    if (user?.email != null && user!.email!.isNotEmpty) {
      final emailPrefix = user.email!.split('@').first;
      if (emailPrefix.isNotEmpty) {
        return emailPrefix;
      }
    }
    
    // Fallback
    return 'User';
  }
}
