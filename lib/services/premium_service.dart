import 'dart:math' show max;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing premium status and enforcing free tier restrictions
///
/// Premium restrictions (for non-premium users):
/// - Models: Only GPT-OSS 120B available
/// - Daily image uploads: 4 per day (resets at midnight)
/// - Daily AI messages: 18 per day (resets at midnight)
/// - Custom bots: 2 per month (resets on 1st)
class PremiumService {
  static const String _lastMonthKey = 'premium_reset_month';
  static const String _messageDateKey = 'premium_ai_messages_date';
  static const String _messageCountKey = 'premium_ai_messages_count';
  static const String _customBotsKey = 'premium_custom_bots_count';
  static const String _imageCountKey = 'premium_image_uploads_count';
  static const String _imageDateKey = 'premium_image_date';

  // Restrictions
  static const int maxImageUploadsPerDay = 4;
  static const int maxAiMessagesPerDay = 18;
  static const int maxCustomBotsPerMonth = 2;

  // Available models
  static const List<String> freeModels = ['GPT-OSS 120B'];
  static const List<String> premiumOnlyModels = [
    'GPT-4 Pro',
    'Claude 3 Opus',
    'Gemini Ultra',
    'Extended Context',
  ];

  static PremiumService? _instance;
  SharedPreferences? _prefs;

  PremiumService._();

  static PremiumService get instance {
    _instance ??= PremiumService._();
    return _instance!;
  }

  /// Initialize service (required before use)
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  String _userKey(String key) {
    final uid = _currentUid;
    return uid != null ? '${uid}_$key' : key;
  }

  // ============================================================================
  // PREMIUM STATUS
  // ============================================================================

  /// Check if user has premium subscription
  Future<bool> isPremium() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final doc = await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(user.uid)
          .get();

      if (!doc.exists) return false;
      final rawValue = doc.data()?['isPremium'];
      return (rawValue is bool) ? rawValue : false;
    } catch (e) {
      print('[PremiumService] Error checking premium: $e');
      return false;
    }
  }

  /// Stream premium status updates in real-time
  Stream<bool> premiumStatusStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(false);

    return FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return false;
          final rawValue = doc.data()?['isPremium'];
          return (rawValue is bool) ? rawValue : false;
        })
        .handleError((e) {
          print('[PremiumService] Premium stream error: $e');
          return false;
        });
  }

  // ============================================================================
  // MODEL ACCESS
  // ============================================================================

  /// Get list of available models for user
  Future<List<String>> getAvailableModels() async {
    final premium = await isPremium();
    if (premium) {
      return [...freeModels, ...premiumOnlyModels];
    }
    return freeModels;
  }

  /// Check if user can access a specific model
  Future<bool> canAccessModel(String modelName) async {
    if (freeModels.contains(modelName)) {
      return true;
    }
    final premium = await isPremium();
    return premium && premiumOnlyModels.contains(modelName);
  }

  /// Get locked models list
  List<String> getLockedModels() => premiumOnlyModels;

  // ============================================================================
  // IMAGE UPLOAD TRACKING (Daily - resets at midnight)
  // ============================================================================

  /// Check if user can upload an image today
  Future<bool> canUploadImage() async {
    final premium = await isPremium();
    if (premium) return true;

    await init();
    final today = DateTime.now().toString().split(' ')[0]; // YYYY-MM-DD
    final lastDate = _prefs!.getString(_userKey(_imageDateKey)) ?? '';

    if (lastDate != today) {
      // New day, reset counter
      await _prefs!.setString(_userKey(_imageDateKey), today);
      await _prefs!.setInt(_userKey(_imageCountKey), 0);
      return true;
    }

    final count = _prefs!.getInt(_userKey(_imageCountKey)) ?? 0;
    return count < maxImageUploadsPerDay;
  }

  /// Record an image upload
  Future<void> recordImageUpload() async {
    await init();
    final count = _prefs!.getInt(_userKey(_imageCountKey)) ?? 0;
    await _prefs!.setInt(_userKey(_imageCountKey), count + 1);
  }

  /// Get remaining image uploads for today
  Future<int> getRemainingImageUploads() async {
    final premium = await isPremium();
    if (premium) return maxImageUploadsPerDay;

    await init();
    final today = DateTime.now().toString().split(' ')[0];
    final lastDate = _prefs!.getString(_userKey(_imageDateKey)) ?? '';

    if (lastDate != today) {
      return maxImageUploadsPerDay;
    }

    final count = _prefs!.getInt(_userKey(_imageCountKey)) ?? 0;
    return max(0, maxImageUploadsPerDay - count);
  }

  // ============================================================================
  // AI MESSAGE TRACKING (Daily - resets at midnight)
  // ============================================================================

  /// Check if user can send another AI message
  Future<bool> canSendAiMessage() async {
    final premium = await isPremium();
    if (premium) return true;

    await init();
    _ensureDailyMessageReset();

    final count = _prefs!.getInt(_userKey(_messageCountKey)) ?? 0;
    return count < maxAiMessagesPerDay;
  }

  /// Record an AI message
  Future<void> recordAiMessage() async {
    await init();
    _ensureDailyMessageReset();

    final count = _prefs!.getInt(_userKey(_messageCountKey)) ?? 0;
    await _prefs!.setInt(_userKey(_messageCountKey), count + 1);
  }

  /// Get remaining AI messages for today
  Future<int> getRemainingMessages() async {
    final premium = await isPremium();
    if (premium) return maxAiMessagesPerDay;

    await init();
    _ensureDailyMessageReset();

    final count = _prefs!.getInt(_userKey(_messageCountKey)) ?? 0;
    return max(0, maxAiMessagesPerDay - count);
  }

  // ============================================================================
  // CUSTOM BOT TRACKING (Monthly - resets on 1st of month)
  // ============================================================================

  /// Check if user can create another custom bot
  Future<bool> canCreateBot() async {
    final premium = await isPremium();
    if (premium) return true;

    await init();
    _ensureMonthReset();

    final count = _prefs!.getInt(_userKey(_customBotsKey)) ?? 0;
    return count < maxCustomBotsPerMonth;
  }

  /// Record a bot creation
  Future<void> recordBotCreation() async {
    await init();
    _ensureMonthReset();

    final count = _prefs!.getInt(_userKey(_customBotsKey)) ?? 0;
    await _prefs!.setInt(_userKey(_customBotsKey), count + 1);
  }

  /// Get remaining bots for this month
  Future<int> getRemainingBots() async {
    final premium = await isPremium();
    if (premium) return maxCustomBotsPerMonth;

    await init();
    _ensureMonthReset();

    final count = _prefs!.getInt(_userKey(_customBotsKey)) ?? 0;
    return max(0, maxCustomBotsPerMonth - count);
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Check and reset daily message limit if needed (called at midnight)
  void _ensureDailyMessageReset() {
    if (_prefs == null) return;

    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    final savedDate = _prefs!.getString(_userKey(_messageDateKey)) ?? '';

    if (today != savedDate) {
      // Reset daily message counter
      _prefs!.setString(_userKey(_messageDateKey), today);
      _prefs!.setInt(_userKey(_messageCountKey), 0);
      print('[PremiumService] Daily message limit reset for $today');
    }
  }

  /// Check and reset monthly limits if needed (called on 1st of month)
  void _ensureMonthReset() {
    if (_prefs == null) return;

    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month}';
    final savedMonth = _prefs!.getString(_userKey(_lastMonthKey)) ?? '';

    if (currentMonth != savedMonth) {
      // Reset monthly counters
      _prefs!.setString(_userKey(_lastMonthKey), currentMonth);
      _prefs!.setInt(_userKey(_customBotsKey), 0);
      print('[PremiumService] Monthly limits reset for month $currentMonth');
    }
  }

  /// Clear all cached data (useful for logout/testing)
  Future<void> clearCache() async {
    await init();
    await _prefs!.remove(_userKey(_lastMonthKey));
    await _prefs!.remove(_userKey(_messageDateKey));
    await _prefs!.remove(_userKey(_messageCountKey));
    await _prefs!.remove(_userKey(_customBotsKey));
    await _prefs!.remove(_userKey(_imageCountKey));
    await _prefs!.remove(_userKey(_imageDateKey));
  }

  /// Get all usage stats (for debugging/UI)
  Future<Map<String, int>> getUsageStats() async {
    await init();
    _ensureDailyMessageReset();
    _ensureMonthReset();

    return {
      'aiMessagesUsed': _prefs!.getInt(_userKey(_messageCountKey)) ?? 0,
      'aiMessagesLimit': maxAiMessagesPerDay,
      'imageUploadsUsed': _prefs!.getInt(_userKey(_imageCountKey)) ?? 0,
      'imageUploadsLimit': maxImageUploadsPerDay,
      'customBotsUsed': _prefs!.getInt(_userKey(_customBotsKey)) ?? 0,
      'customBotsLimit': maxCustomBotsPerMonth,
    };
  }
}
