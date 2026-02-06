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
  static const String _lastAppOpenTimestampKey = 'study_last_app_open';
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
  Future<StudyStreakData> recordStudyActivity({
    required String activityType, // 'message', 'quiz', 'module', etc.
    String? botId,
    String? metadata,
  }) async {
    _ensureInitialized();

    try {
      final now = DateTime.now();
      final lastStudyTimestamp = _getLastStudyTimestamp();

      // Check if we should count this as a new study day
      if (lastStudyTimestamp == null) {
        // First study session ever
        await _setLastStudyTimestamp(now);
        await _setCurrentStreak(1);
        print('[StudyActivity] 🎯 First study session recorded. Streak: 1');
        return _buildStreakData(1, false);
      }

      final timeDiffHours = now.difference(lastStudyTimestamp).inHours;

      // Already studied today - don't increment streak
      if (timeDiffHours < 24) {
        print(
          '[StudyActivity] ⏱️  Already studied today ($timeDiffHours hours ago). No streak increment.',
        );
        return _buildStreakData(_getCurrentStreak(), false);
      }

      // More than 24h but less than 48h - increment streak
      if (timeDiffHours >= 24 && timeDiffHours < 48) {
        final newStreak = _getCurrentStreak() + 1;
        await _setCurrentStreak(newStreak);
        await _setLastStudyTimestamp(now);

        // Update longest streak if applicable
        final longestStreak = _getLongestStreak();
        if (newStreak > longestStreak) {
          await _setLongestStreak(newStreak);
        }

        print('[StudyActivity] 🔥 Streak incremented! New streak: $newStreak');
        return _buildStreakData(newStreak, true);
      }

      // More than 48h - reset streak to 1
      if (timeDiffHours >= 48) {
        await _setCurrentStreak(1);
        await _setLastStudyTimestamp(now);
        print(
          '[StudyActivity] 🔄 Streak broken (>${(timeDiffHours / 24).toStringAsFixed(1)} days). Reset to 1.',
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
  /// This increments the streak whenever user opens the app (not just completing activities)
  /// Returns the updated streak information
  Future<StudyStreakData> recordAppOpen() async {
    _ensureInitialized();

    try {
      final now = DateTime.now();
      final lastAppOpenTimestamp = _getLastAppOpenTimestamp();

      // Check if this is a new day since last app open
      if (lastAppOpenTimestamp == null) {
        // First app open ever
        await _setLastAppOpenTimestamp(now);
        await _setCurrentStreak(1);
        await _setLastStudyTimestamp(now);
        print('[StudyActivity] 🎯 First app open. Streak: 1');
        return _buildStreakData(1, false);
      }

      final timeDiffHours = now.difference(lastAppOpenTimestamp).inHours;

      // Already opened app today - don't increment streak
      if (timeDiffHours < 24) {
        print(
          '[StudyActivity] ⏱️  Already opened app today ($timeDiffHours hours ago). No streak increment.',
        );
        return _buildStreakData(_getCurrentStreak(), false);
      }

      // More than 24h but less than 48h - increment streak
      if (timeDiffHours >= 24 && timeDiffHours < 48) {
        final newStreak = _getCurrentStreak() + 1;
        await _setCurrentStreak(newStreak);
        await _setLastAppOpenTimestamp(now);
        await _setLastStudyTimestamp(now);

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

      // More than 48h - reset streak to 1
      if (timeDiffHours >= 48) {
        await _setCurrentStreak(1);
        await _setLastAppOpenTimestamp(now);
        await _setLastStudyTimestamp(now);
        print(
          '[StudyActivity] 🔄 Streak broken (>${(timeDiffHours / 24).toStringAsFixed(1)} days). Reset to 1.',
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

  DateTime? _getLastStudyTimestamp() {
    final timestamp = _prefs.getString(_lastStudyTimestampKey);
    if (timestamp == null) return null;
    return DateTime.parse(timestamp);
  }

  Future<void> _setLastStudyTimestamp(DateTime dateTime) async {
    await _prefs.setString(_lastStudyTimestampKey, dateTime.toIso8601String());
  }

  DateTime? _getLastAppOpenTimestamp() {
    final timestamp = _prefs.getString(_lastAppOpenTimestampKey);
    if (timestamp == null) return null;
    return DateTime.parse(timestamp);
  }

  Future<void> _setLastAppOpenTimestamp(DateTime dateTime) async {
    await _prefs.setString(
      _lastAppOpenTimestampKey,
      dateTime.toIso8601String(),
    );
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
    print('  - Last Study: ${_getLastStudyTimestamp()}');
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
