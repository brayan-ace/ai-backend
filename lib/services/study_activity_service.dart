import 'package:shared_preferences/shared_preferences.dart';

/// Study Activity Service
/// Tracks study interactions, manages learning streaks, and persists activity data
///
/// What counts as "Studying":
/// - Sending a message in a Study Bot chat
/// - Starting or completing a study module
/// - Starting or completing a quiz
class StudyActivityService {
  static final StudyActivityService _instance =
      StudyActivityService._internal();

  factory StudyActivityService() => _instance;

  StudyActivityService._internal();

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // Preference keys
  static const String _lastStudyTimestampKey = 'study_last_timestamp';
  static const String _lastActivityDateKey =
      'study_last_activity_date'; // UNIFIED: Both app open AND study activity use this
  static const String _currentStreakKey = 'study_current_streak';
  static const String _lastStreakMilestoneKey = 'study_last_milestone';
  static const String _longestStreakKey = 'study_longest_streak';

  /// Initialize the study activity service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      print('[StudyActivity] ✅ Study activity service initialized');
      _logCurrentState();
    } catch (e) {
      print('[StudyActivity] ❌ Error initializing: $e');
      rethrow;
    }
  }

  /// Record a study activity (message in chat, quiz, module, etc.)
  /// Returns the updated streak information
  /// Uses CALENDAR DAY tracking (not 24-hour windows)
  /// UNIFIED: Now shares date tracking with app open
  Future<StudyStreakData> recordStudyActivity({
    required String activityType, // 'message', 'quiz', 'module', etc.
    String? botId,
    String? metadata,
  }) async {
    _ensureInitialized();

    try {
      final now = DateTime.now();
      final today = _dateOnly(now);
      final lastActivityDate = _getLastActivityDate();

      // First activity ever
      if (lastActivityDate == null) {
        await _setLastActivityDate(today);
        await _setCurrentStreak(1);
        print('[StudyActivity] 🎯 First activity recorded. Streak: 1');
        return _buildStreakData(1, false);
      }

      // Same day - don't increment streak
      if (lastActivityDate.isAtSameMomentAs(today)) {
        final currentStreak = _getCurrentStreak();
        print(
          '[StudyActivity] ⏱️  Already active today. Streak remains: $currentStreak',
        );
        return _buildStreakData(currentStreak, false);
      }

      // Different day - check if within 48 hours
      final hoursDiff = now
          .difference(
            DateTime(
              lastActivityDate.year,
              lastActivityDate.month,
              lastActivityDate.day,
            ),
          )
          .inHours;

      if (hoursDiff < 48) {
        // Within 48 hours, different day - INCREMENT STREAK
        final newStreak = _getCurrentStreak() + 1;
        await _setCurrentStreak(newStreak);
        await _setLastActivityDate(today);

        // Update longest streak if applicable
        final longestStreak = _getLongestStreak();
        if (newStreak > longestStreak) {
          await _setLongestStreak(newStreak);
        }

        print(
          '[StudyActivity] 🔥 New day! Streak incremented! New streak: $newStreak',
        );
        return _buildStreakData(newStreak, true);
      }

      // More than 48 hours since last activity - RESET STREAK
      if (hoursDiff >= 48) {
        await _setCurrentStreak(1);
        await _setLastActivityDate(today);
        // Reset milestone when streak resets
        await _prefs.remove(_lastStreakMilestoneKey);
        print(
          '[StudyActivity] 🔄 Streak broken (${(hoursDiff / 24).toStringAsFixed(1)} days). Reset to 1.',
        );
        return _buildStreakData(1, false);
      }

      // Should not reach here, but return current state
      return _buildStreakData(_getCurrentStreak(), false);
    } catch (e) {
      print('[StudyActivity] ❌ Error recording activity: $e');
      rethrow;
    }
  }

  /// Record app open and update streak if new day
  /// This increments the streak whenever user opens the app on a new calendar day
  /// Returns the updated streak information
  /// Uses CALENDAR DAY tracking (not 24-hour windows)
  /// UNIFIED: Now shares date tracking with study activity
  Future<StudyStreakData> recordAppOpen() async {
    _ensureInitialized();

    try {
      final now = DateTime.now();
      final today = _dateOnly(now);
      final lastActivityDate = _getLastActivityDate();

      // First activity ever
      if (lastActivityDate == null) {
        await _setLastActivityDate(today);
        await _setCurrentStreak(1);
        print('[StudyActivity] 🎯 First app open. Streak: 1');
        return _buildStreakData(1, false);
      }

      // Same day - don't increment streak
      if (lastActivityDate.isAtSameMomentAs(today)) {
        final currentStreak = _getCurrentStreak();
        print(
          '[StudyActivity] ⏱️  Already opened app today. Streak remains: $currentStreak',
        );
        return _buildStreakData(currentStreak, false);
      }

      // Different day - check if within 48 hours
      final hoursDiff = now
          .difference(
            DateTime(
              lastActivityDate.year,
              lastActivityDate.month,
              lastActivityDate.day,
            ),
          )
          .inHours;

      if (hoursDiff < 48) {
        // Within 48 hours, different day - INCREMENT STREAK
        final newStreak = _getCurrentStreak() + 1;
        await _setCurrentStreak(newStreak);
        await _setLastActivityDate(today);

        // Update longest streak if applicable
        final longestStreak = _getLongestStreak();
        if (newStreak > longestStreak) {
          await _setLongestStreak(newStreak);
        }

        print(
          '[StudyActivity] 🔥 Streak incremented on app open! New streak: $newStreak',
        );
        return _buildStreakData(newStreak, true);
      }

      // More than 48 hours since last activity - RESET STREAK
      if (hoursDiff >= 48) {
        await _setCurrentStreak(1);
        await _setLastActivityDate(today);
        // Reset milestone when streak resets
        await _prefs.remove(_lastStreakMilestoneKey);
        print(
          '[StudyActivity] 🔄 Streak broken (${(hoursDiff / 24).toStringAsFixed(1)} days). Reset to 1.',
        );
        return _buildStreakData(1, false);
      }

      // Should not reach here, but return current state
      return _buildStreakData(_getCurrentStreak(), false);
    } catch (e) {
      print('[StudyActivity] ❌ Error recording app open: $e');
      rethrow;
    }
  }

  /// Check if the user should receive a daily reminder
  /// Returns true if:
  /// - No study session recorded yet, OR
  /// - More than 24 hours since last study
  bool shouldSendDailyReminder() {
    _ensureInitialized();

    final lastStudyTimestamp = _getLastStudyTimestamp();

    if (lastStudyTimestamp == null) {
      print(
        '[StudyActivity] 📢 Should send reminder: No study session recorded',
      );
      return true;
    }

    final timeDiffHours = DateTime.now().difference(lastStudyTimestamp).inHours;

    if (timeDiffHours >= 24) {
      print(
        '[StudyActivity] 📢 Should send reminder: ${timeDiffHours}h since last study',
      );
      return true;
    }

    print(
      '[StudyActivity] 🤐 Should skip reminder: Recent study (${timeDiffHours}h ago)',
    );
    return false;
  }

  /// Check if a milestone should be notified
  /// Returns true if streak has reached a milestone and hasn't been notified yet
  bool shouldNotifyMilestone(int streakDays) {
    _ensureInitialized();

    // Only notify on specific milestones
    const List<int> milestones = [3, 7];

    if (!milestones.contains(streakDays)) {
      return false;
    }

    final lastMilestone = _getLastStreakMilestone();

    // Only notify if this milestone hasn't been notified yet
    if (lastMilestone != null && lastMilestone >= streakDays) {
      print('[StudyActivity] 🚫 Milestone $streakDays already notified');
      return false;
    }

    print('[StudyActivity] 🎉 Milestone $streakDays should be notified');
    return true;
  }

  /// Mark a milestone as notified
  Future<void> markMilestoneNotified(int streakDays) async {
    _ensureInitialized();

    try {
      final lastMilestone = _getLastStreakMilestone() ?? 0;
      if (streakDays > lastMilestone) {
        await _prefs.setInt(_lastStreakMilestoneKey, streakDays);
        print('[StudyActivity] ✅ Marked milestone $streakDays as notified');
      }
    } catch (e) {
      print('[StudyActivity] ❌ Error marking milestone: $e');
    }
  }

  /// Get current streak data
  StudyStreakData getCurrentStreakData() {
    _ensureInitialized();
    return _buildStreakData(_getCurrentStreak(), false);
  }

  /// Reset streak (admin/testing only)
  Future<void> resetStreak() async {
    _ensureInitialized();

    try {
      await _prefs.remove(_lastStudyTimestampKey);
      await _prefs.remove(_currentStreakKey);
      await _prefs.remove(_lastStreakMilestoneKey);
      print('[StudyActivity] 🔄 Streak reset');
    } catch (e) {
      print('[StudyActivity] ❌ Error resetting streak: $e');
    }
  }

  /// Get full study stats
  Future<StudyStats> getStudyStats() async {
    _ensureInitialized();

    return StudyStats(
      currentStreak: _getCurrentStreak(),
      longestStreak: _getLongestStreak(),
      lastStudyTime: _getLastStudyTimestamp(),
      lastNotifiedMilestone: _getLastStreakMilestone() ?? 0,
    );
  }

  // ============================================================================
  // PRIVATE HELPERS
  // ============================================================================

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception(
        'StudyActivityService not initialized. Call initialize() first.',
      );
    }
  }

  // Helper to get date only (without time)
  DateTime _dateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  DateTime? _getLastStudyTimestamp() {
    final timestamp = _prefs.getString(_lastStudyTimestampKey);
    if (timestamp == null) return null;
    return DateTime.parse(timestamp);
  }

  // Get last activity date (calendar day only) - UNIFIED for both app open and study activity
  DateTime? _getLastActivityDate() {
    final dateStr = _prefs.getString(_lastActivityDateKey);
    if (dateStr == null) return null;
    return DateTime.parse(dateStr);
  }

  // Set last activity date (calendar day only) - UNIFIED for both app open and study activity
  Future<void> _setLastActivityDate(DateTime dateTime) async {
    final dateOnly = _dateOnly(dateTime);
    await _prefs.setString(_lastActivityDateKey, dateOnly.toIso8601String());
  }

  int _getCurrentStreak() {
    return _prefs.getInt(_currentStreakKey) ?? 0;
  }

  Future<void> _setCurrentStreak(int streak) async {
    await _prefs.setInt(_currentStreakKey, streak);
  }

  int _getLongestStreak() {
    return _prefs.getInt(_longestStreakKey) ?? 0;
  }

  Future<void> _setLongestStreak(int streak) async {
    await _prefs.setInt(_longestStreakKey, streak);
  }

  int? _getLastStreakMilestone() {
    final value = _prefs.getInt(_lastStreakMilestoneKey);
    return value == 0 ? null : value;
  }

  StudyStreakData _buildStreakData(int currentStreak, bool streakIncremented) {
    return StudyStreakData(
      currentStreak: currentStreak,
      streakIncremented: streakIncremented,
      timestamp: DateTime.now(),
    );
  }

  void _logCurrentState() {
    print('[StudyActivity] Current state:');
    print('  - Current Streak: ${_getCurrentStreak()}');
    print('  - Longest Streak: ${_getLongestStreak()}');
    print('  - Last Activity Date: ${_getLastActivityDate()}');
    print('  - Last Notified Milestone: ${_getLastStreakMilestone()}');
  }
}

/// Data class for streak information
class StudyStreakData {
  final int currentStreak;
  final bool streakIncremented;
  final DateTime timestamp;

  StudyStreakData({
    required this.currentStreak,
    required this.streakIncremented,
    required this.timestamp,
  });

  @override
  String toString() =>
      'StudyStreakData(streak: $currentStreak, incremented: $streakIncremented)';
}

/// Data class for study statistics
class StudyStats {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastStudyTime;
  final int lastNotifiedMilestone;

  StudyStats({
    required this.currentStreak,
    required this.longestStreak,
    this.lastStudyTime,
    required this.lastNotifiedMilestone,
  });

  @override
  String toString() =>
      '''StudyStats(
    current: $currentStreak,
    longest: $longestStreak,
    lastStudy: $lastStudyTime,
    milestone: $lastNotifiedMilestone
  )''';
}
