import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'push_notification_service.dart';

/// Premium Gamification Service
/// Manages achievements, rewards, and learning streaks
class GamificationService {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PushNotificationService _notificationService =
      PushNotificationService();
  late final SharedPreferences _prefs;

  // User stats
  int _userLevel = 1;
  int _totalXP = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  List<String> _unlockedAchievements = [];
  List<String> _earnedBadges = [];
  Map<String, int> _categoryProgress = {};

  /// Initialize gamification system
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadUserStats();
      await _checkDailyLogin();
      print('[Gamification] ✅ Premium gamification initialized');
    } catch (e) {
      print('[Gamification] Error initializing: $e');
    }
  }

  /// Award XP to user
  Future<void> awardXP(int amount, {String? reason}) async {
    try {
      _totalXP += amount;
      await _checkLevelUp();
      await _saveUserStats();

      // Track XP gain
      await _firestore.collection('xp_gains').add({
        'user_id': FirebaseAuth.instance.currentUser?.uid,
        'amount': amount,
        'reason': reason ?? 'Learning activity',
        'timestamp': FieldValue.serverTimestamp(),
        'level_before': _userLevel - 1,
        'level_after': _userLevel,
      });

      print('[Gamification] +$amount XP awarded (Total: $_totalXP)');
    } catch (e) {
      print('[Gamification] Error awarding XP: $e');
    }
  }

  /// Update learning streak
  Future<void> updateStreak() async {
    try {
      final today = DateTime.now();
      final lastStudy = await _getLastStudyDate();

      if (lastStudy == null) {
        // First study session
        _currentStreak = 1;
      } else {
        final daysDiff = today.difference(lastStudy).inDays;

        if (daysDiff == 0) {
          // Already studied today, no change
          return;
        } else if (daysDiff == 1) {
          // Continuation of streak
          _currentStreak++;
          await _checkStreakMilestones();
        } else {
          // Streak broken, start new one
          if (_currentStreak > _longestStreak) {
            _longestStreak = _currentStreak;
          }
          _currentStreak = 1;
        }
      }

      await _setLastStudyDate(today);
      await _saveUserStats();

      // Award streak XP
      await awardXP(_currentStreak * 5, reason: 'Daily streak');

      print('[Gamification] Streak updated: $_currentStreak days');
    } catch (e) {
      print('[Gamification] Error updating streak: $e');
    }
  }

  /// Check and unlock achievements
  Future<void> checkAchievements({
    int? conceptsLearned,
    int? quizzesCompleted,
    double? quizAccuracy,
    int? studyTimeMinutes,
    String? category,
  }) async {
    try {
      final achievements = await _getAvailableAchievements();

      for (final achievement in achievements) {
        if (_unlockedAchievements.contains(achievement['id'])) continue;

        bool unlocked = false;

        // Check achievement conditions
        switch (achievement['id']) {
          case 'first_concept':
            unlocked = conceptsLearned != null && conceptsLearned >= 1;
            break;
          case 'concept_master':
            unlocked = conceptsLearned != null && conceptsLearned >= 10;
            break;
          case 'quiz_perfect':
            unlocked = quizAccuracy != null && quizAccuracy >= 1.0;
            break;
          case 'quiz_expert':
            unlocked =
                quizAccuracy != null &&
                quizAccuracy >= 0.9 &&
                quizzesCompleted != null &&
                quizzesCompleted >= 5;
            break;
          case 'study_warrior':
            unlocked = studyTimeMinutes != null && studyTimeMinutes >= 60;
            break;
          case 'streak_warrior':
            unlocked = _currentStreak >= 7;
            break;
          case 'streak_legend':
            unlocked = _currentStreak >= 30;
            break;
          case 'level_master':
            unlocked = _userLevel >= 10;
            break;
          case 'xp_collector':
            unlocked = _totalXP >= 1000;
            break;
        }

        if (unlocked) {
          await _unlockAchievement(achievement);
        }
      }
    } catch (e) {
      print('[Gamification] Error checking achievements: $e');
    }
  }

  /// Unlock achievement
  Future<void> _unlockAchievement(Map<String, dynamic> achievement) async {
    try {
      _unlockedAchievements.add(achievement['id']);

      // Award achievement XP
      await awardXP(
        achievement['xp_reward'] ?? 50,
        reason: 'Achievement: ${achievement['title']}',
      );

      // Send notification
      await _notificationService.sendAchievementNotification(
        title: achievement['title'],
        description: achievement['description'],
        achievementId: achievement['id'],
      );

      // Save to database
      await _firestore.collection('user_achievements').add({
        'user_id': FirebaseAuth.instance.currentUser?.uid,
        'achievement_id': achievement['id'],
        'achievement': achievement,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('[Gamification] 🏆 Achievement unlocked: ${achievement['title']}');
    } catch (e) {
      print('[Gamification] Error unlocking achievement: $e');
    }
  }

  /// Check for level up
  Future<void> _checkLevelUp() async {
    try {
      final newLevel = _calculateLevel(_totalXP);
      if (newLevel > _userLevel) {
        final oldLevel = _userLevel;
        _userLevel = newLevel;

        // Award level up bonus XP
        await awardXP(newLevel * 100, reason: 'Level up to level $newLevel');

        // Send notification
        await _notificationService.sendAchievementNotification(
          title: 'Level Up!',
          description: 'Congratulations! You\'ve reached level $newLevel!',
          achievementId: 'level_up_$newLevel',
        );

        // Save level up event
        await _firestore.collection('level_ups').add({
          'user_id': FirebaseAuth.instance.currentUser?.uid,
          'old_level': oldLevel,
          'new_level': newLevel,
          'total_xp': _totalXP,
          'timestamp': FieldValue.serverTimestamp(),
        });

        print('[Gamification] ⬆️ Level up: $oldLevel → $newLevel');
      }
    } catch (e) {
      print('[Gamification] Error checking level up: $e');
    }
  }

  /// Check streak milestones
  Future<void> _checkStreakMilestones() async {
    try {
      if (_currentStreak == 3) {
        await _notificationService.sendStreakNotification(3);
      } else if (_currentStreak == 7) {
        await _notificationService.sendStreakNotification(7);
      } else if (_currentStreak == 30) {
        await _notificationService.sendStreakNotification(30);
      } else if (_currentStreak == 100) {
        await _notificationService.sendStreakNotification(100);
      }
    } catch (e) {
      print('[Gamification] Error checking streak milestones: $e');
    }
  }

  /// Get user's current stats
  Map<String, dynamic> getUserStats() {
    return {
      'level': _userLevel,
      'totalXP': _totalXP,
      'currentStreak': _currentStreak,
      'longestStreak': _longestStreak,
      'unlockedAchievements': _unlockedAchievements,
      'earnedBadges': _earnedBadges,
      'categoryProgress': _categoryProgress,
      'xpToNextLevel': _getXPToNextLevel(),
      'levelProgress': _getLevelProgress(),
    };
  }

  /// Get leaderboard
  Future<List<Map<String, dynamic>>> getLeaderboard({
    String type = 'xp',
  }) async {
    try {
      QuerySnapshot snapshot;

      switch (type) {
        case 'xp':
          snapshot = await _firestore
              .collection('users')
              .orderBy('total_xp', descending: true)
              .limit(10)
              .get();
          break;
        case 'streak':
          snapshot = await _firestore
              .collection('users')
              .orderBy('current_streak', descending: true)
              .limit(10)
              .get();
          break;
        case 'level':
          snapshot = await _firestore
              .collection('users')
              .orderBy('level', descending: true)
              .limit(10)
              .get();
          break;
        default:
          return [];
      }

      return snapshot.docs
          .map(
            (doc) => {'userId': doc.id, ...doc.data() as Map<String, dynamic>},
          )
          .toList();
    } catch (e) {
      print('[Gamification] Error getting leaderboard: $e');
      return [];
    }
  }

  /// Get available achievements
  Future<List<Map<String, dynamic>>> _getAvailableAchievements() async {
    return [
      {
        'id': 'first_concept',
        'title': 'First Steps',
        'description': 'Learn your first concept',
        'icon': '🌱',
        'xp_reward': 50,
        'badge': 'beginner',
      },
      {
        'id': 'concept_master',
        'title': 'Concept Master',
        'description': 'Learn 10 concepts',
        'icon': '🎓',
        'xp_reward': 200,
        'badge': 'scholar',
      },
      {
        'id': 'quiz_perfect',
        'title': 'Perfect Score',
        'description': 'Get 100% on a quiz',
        'icon': '🎯',
        'xp_reward': 100,
        'badge': 'perfectionist',
      },
      {
        'id': 'quiz_expert',
        'title': 'Quiz Expert',
        'description': 'Score 90%+ on 5 quizzes',
        'icon': '🧠',
        'xp_reward': 300,
        'badge': 'genius',
      },
      {
        'id': 'study_warrior',
        'title': 'Study Warrior',
        'description': 'Study for 1 hour total',
        'icon': '⚔️',
        'xp_reward': 150,
        'badge': 'dedicated',
      },
      {
        'id': 'streak_warrior',
        'title': 'Streak Warrior',
        'description': '7-day learning streak',
        'icon': '🔥',
        'xp_reward': 350,
        'badge': 'consistent',
      },
      {
        'id': 'streak_legend',
        'title': 'Streak Legend',
        'description': '30-day learning streak',
        'icon': '👑',
        'xp_reward': 1000,
        'badge': 'legendary',
      },
      {
        'id': 'level_master',
        'title': 'Level Master',
        'description': 'Reach level 10',
        'icon': '⭐',
        'xp_reward': 500,
        'badge': 'expert',
      },
      {
        'id': 'xp_collector',
        'title': 'XP Collector',
        'description': 'Earn 1000 total XP',
        'icon': '💎',
        'xp_reward': 200,
        'badge': 'collector',
      },
    ];
  }

  /// Calculate level based on XP
  int _calculateLevel(int xp) {
    // Level formula: 100 * level^1.5 XP required
    int level = 1;
    while (_getXPRequiredForLevel(level + 1) <= xp) {
      level++;
    }
    return level;
  }

  /// Get XP required for specific level
  int _getXPRequiredForLevel(int level) {
    return (100 * math.pow(level, 1.5)).round();
  }

  /// Get XP needed for next level
  int _getXPToNextLevel() {
    final nextLevelXP = _getXPRequiredForLevel(_userLevel + 1);
    return nextLevelXP - _totalXP;
  }

  /// Get progress towards next level
  double _getLevelProgress() {
    final currentLevelXP = _getXPRequiredForLevel(_userLevel);
    final nextLevelXP = _getXPRequiredForLevel(_userLevel + 1);
    final levelRange = nextLevelXP - currentLevelXP;
    final progress = _totalXP - currentLevelXP;
    return (progress / levelRange).clamp(0.0, 1.0);
  }

  /// Load user stats from storage
  Future<void> _loadUserStats() async {
    try {
      final prefs = await _prefs;
      _userLevel = prefs.getInt('user_level') ?? 1;
      _totalXP = prefs.getInt('total_xp') ?? 0;
      _currentStreak = prefs.getInt('current_streak') ?? 1;
      _longestStreak = prefs.getInt('longest_streak') ?? 1;
      _unlockedAchievements =
          prefs.getStringList('unlocked_achievements') ?? [];
      _earnedBadges = prefs.getStringList('earned_badges') ?? [];

      // Load category progress
      final categoryProgressJson = prefs.getString('category_progress');
      if (categoryProgressJson != null) {
        // Parse JSON and convert to Map<String, int>
        // This is simplified - in production, use proper JSON parsing
        _categoryProgress['math'] = prefs.getInt('math_progress') ?? 0;
        _categoryProgress['science'] = prefs.getInt('science_progress') ?? 0;
        _categoryProgress['history'] = prefs.getInt('history_progress') ?? 0;
        _categoryProgress['language'] = prefs.getInt('language_progress') ?? 0;
      }
    } catch (e) {
      print('[Gamification] Error loading user stats: $e');
    }
  }

  /// Save user stats to storage
  Future<void> _saveUserStats() async {
    try {
      final prefs = await _prefs;
      await prefs.setInt('user_level', _userLevel);
      await prefs.setInt('total_xp', _totalXP);
      await prefs.setInt('current_streak', _currentStreak);
      await prefs.setInt('longest_streak', _longestStreak);
      await prefs.setStringList('unlocked_achievements', _unlockedAchievements);
      await prefs.setStringList('earned_badges', _earnedBadges);

      // Save to database
      await _firestore
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .set({
            'level': _userLevel,
            'total_xp': _totalXP,
            'current_streak': _currentStreak,
            'longest_streak': _longestStreak,
            'unlocked_achievements': _unlockedAchievements,
            'earned_badges': _earnedBadges,
            'last_updated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      print('[Gamification] Error saving user stats: $e');
    }
  }

  /// Check daily login
  Future<void> _checkDailyLogin() async {
    try {
      final today = DateTime.now();
      final lastLogin = await _getLastLoginDate();

      if (lastLogin == null || !isSameDay(lastLogin, today)) {
        // First login or new day
        await _setLastLoginDate(today);
        await awardXP(10, reason: 'Daily login');

        if (_currentStreak == 0) {
          _currentStreak = 1;
        } else {
          final daysDiff = today.difference(lastLogin!).inDays;
          if (daysDiff == 1) {
            _currentStreak++;
          } else {
            _currentStreak = 1;
          }
        }

        await _saveUserStats();
      }
    } catch (e) {
      print('[Gamification] Error checking daily login: $e');
    }
  }

  /// Check if two dates are the same day
  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Get last study date
  Future<DateTime?> _getLastStudyDate() async {
    try {
      final prefs = await _prefs;
      final dateString = prefs.getString('last_study_date');
      return dateString != null ? DateTime.parse(dateString) : null;
    } catch (e) {
      return null;
    }
  }

  /// Set last study date
  Future<void> _setLastStudyDate(DateTime date) async {
    try {
      final prefs = await _prefs;
      await prefs.setString('last_study_date', date.toIso8601String());
    } catch (e) {
      print('[Gamification] Error setting last study date: $e');
    }
  }

  /// Get last login date
  Future<DateTime?> _getLastLoginDate() async {
    try {
      final prefs = await _prefs;
      final dateString = prefs.getString('last_login_date');
      return dateString != null ? DateTime.parse(dateString) : null;
    } catch (e) {
      return null;
    }
  }

  /// Set last login date
  Future<void> _setLastLoginDate(DateTime date) async {
    try {
      final prefs = await _prefs;
      await prefs.setString('last_login_date', date.toIso8601String());
    } catch (e) {
      print('[Gamification] Error setting last login date: $e');
    }
  }
}
