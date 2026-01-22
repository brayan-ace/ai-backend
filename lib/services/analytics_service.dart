import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme.dart';

/// Premium Analytics Service
/// Tracks user behavior, learning patterns, and provides insights
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final SharedPreferences _prefs;

  // Learning analytics
  Map<String, dynamic> _sessionData = {};
  DateTime? _sessionStart;
  List<String> _conceptsLearned = [];
  List<Map<String, dynamic>> _quizResults = [];
  List<String> _topicsExplored = [];

  // User engagement metrics
  int _totalStudyTime = 0;
  int _sessionsCount = 0;
  double _averageSessionLength = 0;
  int _conceptsMastered = 0;
  double _quizAccuracy = 0;

  /// Initialize analytics tracking
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _sessionStart = DateTime.now();
      _sessionData = {
        'session_id': _generateSessionId(),
        'user_id': FirebaseAuth.instance.currentUser?.uid,
        'start_time': _sessionStart!.toIso8601String(),
        'device_info': await _getDeviceInfo(),
      };

      await _loadPersistedData();
      await _trackSessionStart();

      print('[Analytics] ✅ Premium analytics initialized');
    } catch (e) {
      print('[Analytics] Error initializing: $e');
    }
  }

  /// Track learning session start
  Future<void> _trackSessionStart() async {
    try {
      await _firestore.collection('learning_sessions').add({
        ..._sessionData,
        'event_type': 'session_start',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[Analytics] Error tracking session start: $e');
    }
  }

  /// Track concept learned
  Future<void> trackConceptLearned(
    String concept,
    String module,
    int timeSpent,
  ) async {
    try {
      _conceptsLearned.add(concept);
      _totalStudyTime += timeSpent;

      await _firestore.collection('learning_events').add({
        'session_id': _sessionData['session_id'],
        'user_id': _sessionData['user_id'],
        'event_type': 'concept_learned',
        'concept': concept,
        'module': module,
        'time_spent_seconds': timeSpent,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _updateLearningStreak();
    } catch (e) {
      print('[Analytics] Error tracking concept: $e');
    }
  }

  /// Track quiz completion
  Future<void> trackQuizCompletion(Map<String, dynamic> quizData) async {
    try {
      _quizResults.add(quizData);

      // Calculate accuracy
      int correct = quizData['correct_answers'] ?? 0;
      int total = quizData['total_questions'] ?? 1;
      double accuracy = correct / total;
      _quizAccuracy =
          (_quizAccuracy * _quizResults.length + accuracy) /
          (_quizResults.length + 1);

      await _firestore.collection('learning_events').add({
        'session_id': _sessionData['session_id'],
        'user_id': _sessionData['user_id'],
        'event_type': 'quiz_completed',
        'quiz_data': quizData,
        'accuracy': accuracy,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Check for achievements
      await _checkQuizAchievements(accuracy);
    } catch (e) {
      print('[Analytics] Error tracking quiz: $e');
    }
  }

  /// Track topic exploration
  Future<void> trackTopicExplored(String topic, String category) async {
    try {
      _topicsExplored.add(topic);

      await _firestore.collection('learning_events').add({
        'session_id': _sessionData['session_id'],
        'user_id': _sessionData['user_id'],
        'event_type': 'topic_explored',
        'topic': topic,
        'category': category,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[Analytics] Error tracking topic: $e');
    }
  }

  /// Track user interaction
  Future<void> trackInteraction(
    String action,
    Map<String, dynamic>? context,
  ) async {
    try {
      await _firestore.collection('user_interactions').add({
        'session_id': _sessionData['session_id'],
        'user_id': _sessionData['user_id'],
        'action': action,
        'context': context,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[Analytics] Error tracking interaction: $e');
    }
  }

  /// End current session
  Future<void> endSession() async {
    try {
      if (_sessionStart == null) return;

      int sessionDuration = DateTime.now().difference(_sessionStart!).inSeconds;
      _totalStudyTime += sessionDuration;
      _sessionsCount++;
      _averageSessionLength = _totalStudyTime / _sessionsCount;

      await _firestore.collection('learning_sessions').add({
        ..._sessionData,
        'event_type': 'session_end',
        'duration_seconds': sessionDuration,
        'concepts_learned': _conceptsLearned,
        'topics_explored': _topicsExplored,
        'quiz_results_count': _quizResults.length,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _savePersistedData();
      await _generateInsights();

      print(
        '[Analytics] Session ended: ${sessionDuration}s, ${_conceptsLearned.length} concepts',
      );
    } catch (e) {
      print('[Analytics] Error ending session: $e');
    }
  }

  /// Get comprehensive learning analytics
  Future<Map<String, dynamic>> getLearningAnalytics() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return {};

      // Get last 30 days of data
      DateTime thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));

      QuerySnapshot sessionsSnapshot = await _firestore
          .collection('learning_sessions')
          .where('user_id', isEqualTo: userId)
          .where('timestamp', isGreaterThan: thirtyDaysAgo)
          .orderBy('timestamp', descending: true)
          .get();

      QuerySnapshot eventsSnapshot = await _firestore
          .collection('learning_events')
          .where('user_id', isEqualTo: userId)
          .where('timestamp', isGreaterThan: thirtyDaysAgo)
          .get();

      // Process data
      List<Map<String, dynamic>> sessions = sessionsSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      List<Map<String, dynamic>> events = eventsSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      return {
        'total_sessions': sessions.length,
        'total_study_time': _calculateTotalStudyTime(sessions),
        'average_session_length': _calculateAverageSessionLength(sessions),
        'concepts_learned': _getUniqueConcepts(events),
        'topics_explored': _getUniqueTopics(events),
        'quiz_accuracy': _calculateQuizAccuracy(events),
        'learning_streak': await _getCurrentLearningStreak(),
        'most_active_day': _getMostActiveDay(sessions),
        'preferred_time': _getPreferredStudyTime(sessions),
        'learning_velocity': _calculateLearningVelocity(events),
        'engagement_score': _calculateEngagementScore(sessions, events),
      };
    } catch (e) {
      print('[Analytics] Error getting analytics: $e');
      return {};
    }
  }

  /// Generate personalized insights
  Future<List<String>> generatePersonalizedInsights() async {
    try {
      final analytics = await getLearningAnalytics();
      List<String> insights = [];

      // Learning pattern insights
      if (analytics['learning_velocity'] != null) {
        double velocity = analytics['learning_velocity'];
        if (velocity > 0.8) {
          insights.add(
            '🚀 You\'re learning at an exceptional pace! Keep up the momentum.',
          );
        } else if (velocity < 0.3) {
          insights.add(
            '📈 Consider breaking down complex topics into smaller steps for better retention.',
          );
        }
      }

      // Time-based insights
      String preferredTime = analytics['preferred_time'] ?? 'evening';
      if (preferredTime == 'morning') {
        insights.add(
          '🌅 You learn best in the morning! Schedule important topics during your peak hours.',
        );
      } else if (preferredTime == 'evening') {
        insights.add(
          '🌙 Evening sessions work well for you. Use this time for review and consolidation.',
        );
      }

      // Engagement insights
      double engagement = analytics['engagement_score'] ?? 0;
      if (engagement > 0.8) {
        insights.add(
          '💪 Your engagement is outstanding! You\'re making the most of every session.',
        );
      } else if (engagement < 0.5) {
        insights.add(
          '🎯 Try setting smaller, achievable goals to boost your engagement.',
        );
      }

      // Streak insights
      int streak = analytics['learning_streak'] ?? 0;
      if (streak >= 7) {
        insights.add(
          '🔥 Amazing consistency! Your learning streak shows real dedication.',
        );
      } else if (streak >= 3) {
        insights.add(
          '👍 Great job maintaining your learning streak! Keep it going.',
        );
      }

      return insights;
    } catch (e) {
      print('[Analytics] Error generating insights: $e');
      return ['Keep up the great work with your learning journey!'];
    }
  }

  /// Check for quiz achievements
  Future<void> _checkQuizAchievements(double accuracy) async {
    try {
      if (accuracy >= 0.9) {
        await _trackAchievement('perfect_quiz', 'Perfect Quiz Score');
      }

      if (_quizResults.length >= 10) {
        double avgAccuracy =
            _quizResults
                .map(
                  (quiz) =>
                      (quiz['correct_answers'] ?? 0) /
                      (quiz['total_questions'] ?? 1),
                )
                .reduce((a, b) => a + b) /
            _quizResults.length;

        if (avgAccuracy >= 0.8) {
          await _trackAchievement('quiz_master', 'Quiz Master');
        }
      }
    } catch (e) {
      print('[Analytics] Error checking achievements: $e');
    }
  }

  /// Track achievement
  Future<void> _trackAchievement(String achievementId, String title) async {
    try {
      await _firestore.collection('achievements').add({
        'user_id': _sessionData['user_id'],
        'achievement_id': achievementId,
        'title': title,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // This could trigger a notification
      print('[Analytics] 🎉 Achievement unlocked: $title');
    } catch (e) {
      print('[Analytics] Error tracking achievement: $e');
    }
  }

  /// Update learning streak
  Future<void> _updateLearningStreak() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final prefs = await _prefs;
      final lastStudyDate = prefs.getString('last_study_date');
      final today = DateTime.now();

      if (lastStudyDate != null) {
        final lastStudy = DateTime.parse(lastStudyDate);
        final daysDiff = today.difference(lastStudy).inDays;

        if (daysDiff == 1) {
          // Continuation of streak
          int currentStreak = prefs.getInt('learning_streak') ?? 0;
          await prefs.setInt('learning_streak', currentStreak + 1);
        } else if (daysDiff > 1) {
          // Streak broken
          await prefs.setInt('learning_streak', 1);
        }
      } else {
        // First session
        await prefs.setInt('learning_streak', 1);
      }

      await prefs.setString('last_study_date', today.toIso8601String());
    } catch (e) {
      print('[Analytics] Error updating streak: $e');
    }
  }

  /// Get current learning streak
  Future<int> _getCurrentLearningStreak() async {
    try {
      final prefs = await _prefs;
      return prefs.getInt('learning_streak') ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Helper methods for analytics calculations
  String _generateSessionId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(10000)}';
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    return {
      'platform': 'Flutter',
      'version': '1.0.0',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _loadPersistedData() async {
    try {
      final prefs = await _prefs;
      _totalStudyTime = prefs.getInt('total_study_time') ?? 0;
      _sessionsCount = prefs.getInt('sessions_count') ?? 0;
      _averageSessionLength = prefs.getDouble('average_session_length') ?? 0;
      _conceptsMastered = prefs.getInt('concepts_mastered') ?? 0;
      _quizAccuracy = prefs.getDouble('quiz_accuracy') ?? 0;
    } catch (e) {
      print('[Analytics] Error loading persisted data: $e');
    }
  }

  Future<void> _savePersistedData() async {
    try {
      final prefs = await _prefs;
      await prefs.setInt('total_study_time', _totalStudyTime);
      await prefs.setInt('sessions_count', _sessionsCount);
      await prefs.setDouble('average_session_length', _averageSessionLength);
      await prefs.setInt('concepts_mastered', _conceptsMastered);
      await prefs.setDouble('quiz_accuracy', _quizAccuracy);
    } catch (e) {
      print('[Analytics] Error saving persisted data: $e');
    }
  }

  Future<void> _generateInsights() async {
    try {
      final insights = await generatePersonalizedInsights();
      for (String insight in insights) {
        await _firestore.collection('user_insights').add({
          'user_id': _sessionData['user_id'],
          'insight': insight,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('[Analytics] Error generating insights: $e');
    }
  }

  // Analytics calculation methods
  int _calculateTotalStudyTime(List<Map<String, dynamic>> sessions) {
    return sessions.fold(
      0,
      (sum, session) => sum + (session['duration_seconds'] as int? ?? 0),
    );
  }

  double _calculateAverageSessionLength(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return 0;
    int totalTime = _calculateTotalStudyTime(sessions);
    return totalTime / sessions.length;
  }

  List<String> _getUniqueConcepts(List<Map<String, dynamic>> events) {
    Set<String> concepts = events
        .where((event) => event['event_type'] == 'concept_learned')
        .map((event) => event['concept'] as String)
        .toSet();
    return concepts.toList();
  }

  List<String> _getUniqueTopics(List<Map<String, dynamic>> events) {
    Set<String> topics = events
        .where((event) => event['event_type'] == 'topic_explored')
        .map((event) => event['topic'] as String)
        .toSet();
    return topics.toList();
  }

  double _calculateQuizAccuracy(List<Map<String, dynamic>> events) {
    List<Map<String, dynamic>> quizEvents = events
        .where((event) => event['event_type'] == 'quiz_completed')
        .toList();

    if (quizEvents.isEmpty) return 0;

    double totalAccuracy = quizEvents
        .map((event) => event['accuracy'] as double? ?? 0)
        .reduce((a, b) => a + b);

    return totalAccuracy / quizEvents.length;
  }

  String _getMostActiveDay(List<Map<String, dynamic>> sessions) {
    Map<String, int> dayCounts = {};
    for (var session in sessions) {
      DateTime timestamp = (session['timestamp'] as Timestamp).toDate();
      String day = _getDayName(timestamp.weekday);
      dayCounts[day] = (dayCounts[day] ?? 0) + 1;
    }

    if (dayCounts.isEmpty) return 'Monday';

    return dayCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  String _getPreferredStudyTime(List<Map<String, dynamic>> sessions) {
    Map<String, int> hourCounts = {};
    for (var session in sessions) {
      DateTime timestamp = (session['timestamp'] as Timestamp).toDate();
      int hour = timestamp.hour;
      String period = _getTimePeriod(hour);
      hourCounts[period] = (hourCounts[period] ?? 0) + 1;
    }

    if (hourCounts.isEmpty) return 'evening';

    return hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double _calculateLearningVelocity(List<Map<String, dynamic>> events) {
    List<Map<String, dynamic>> conceptEvents = events
        .where((event) => event['event_type'] == 'concept_learned')
        .toList();

    if (conceptEvents.length < 2) return 0.5;

    // Simple velocity calculation: concepts per session
    return conceptEvents.length / math.max(1, _sessionsCount);
  }

  double _calculateEngagementScore(
    List<Map<String, dynamic>> sessions,
    List<Map<String, dynamic>> events,
  ) {
    if (sessions.isEmpty) return 0;

    double sessionScore = math.min(
      1.0,
      sessions.length / 10.0,
    ); // 10 sessions = full score
    double interactionScore = math.min(
      1.0,
      events.length / 50.0,
    ); // 50 interactions = full score
    double consistencyScore = _calculateConsistencyScore(sessions);

    return (sessionScore + interactionScore + consistencyScore) / 3;
  }

  double _calculateConsistencyScore(List<Map<String, dynamic>> sessions) {
    if (sessions.length < 7) return sessions.length / 7.0;

    // Check last 7 days
    DateTime sevenDaysAgo = DateTime.now().subtract(Duration(days: 7));
    int recentSessions = sessions.where((session) {
      DateTime timestamp = (session['timestamp'] as Timestamp).toDate();
      return timestamp.isAfter(sevenDaysAgo);
    }).length;

    return recentSessions / 7.0;
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Monday';
    }
  }

  String _getTimePeriod(int hour) {
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
  }
}
