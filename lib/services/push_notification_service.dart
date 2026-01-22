import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/theme.dart';
import 'user_profile_service.dart';

/// Premium Push Notification Service
/// Handles daily study reminders, achievement notifications, and personalized learning alerts
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  Timer? _dailyStudyTimer;
  Timer? _weeklyProgressTimer;
  DateTime? lastStudyDate;

  // Notification channels
  static const String _dailyStudyChannel = 'daily_study_reminders';
  static const String _achievementChannel = 'achievements';
  static const String _learningChannel = 'learning_insights';
  static const String _streakChannel = 'learning_streaks';

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request permissions
      const AndroidInitializationSettings androidInitializationSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosInitializationSettings =
          DarwinInitializationSettings();
      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: androidInitializationSettings,
            iOS: iosInitializationSettings,
          );
      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channels
      await _createNotificationChannels();

      // Check if user has enabled notifications
      final notificationsEnabled = await getNotificationsEnabled();
      if (notificationsEnabled) {
        await _scheduleDailyNotifications();
        await _scheduleWeeklyProgressNotifications();
      }

      _isInitialized = true;
      print('[PushNotification] ✅ Premium notification service initialized');
    } catch (e) {
      print('[PushNotification] Error initializing: $e');
    }
  }

  /// Create premium notification channels
  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel dailyStudyChannel =
        AndroidNotificationChannel(
          _dailyStudyChannel,
          'Daily Study Reminders',
          description:
              'Personalized daily reminders to keep your learning momentum',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound('notification_sound'),
        );

    const AndroidNotificationChannel achievementChannel =
        AndroidNotificationChannel(
          _achievementChannel,
          'Achievements & Milestones',
          description: 'Celebrate your learning achievements and milestones',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound('achievement_sound'),
        );

    const AndroidNotificationChannel
    learningChannel = AndroidNotificationChannel(
      _learningChannel,
      'Learning Insights',
      description:
          'Personalized insights and recommendations for your learning journey',
      importance: Importance.low,
      playSound: true,
      enableVibration: false,
      sound: RawResourceAndroidNotificationSound('insight_sound'),
    );

    const AndroidNotificationChannel streakChannel = AndroidNotificationChannel(
      _streakChannel,
      'Learning Streaks',
      description: 'Maintain your learning streak and stay motivated',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound('streak_sound'),
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(dailyStudyChannel);
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(achievementChannel);
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(learningChannel);
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(streakChannel);
  }

  /// Schedule daily study notifications
  Future<void> _scheduleDailyNotifications() async {
    // Cancel existing timer
    _dailyStudyTimer?.cancel();

    // Get user's preferred study time
    final prefs = await SharedPreferences.getInstance();
    final studyHour = prefs.getInt('daily_study_hour') ?? 19; // Default 7 PM
    final studyMinute = prefs.getInt('daily_study_minute') ?? 0;

    // Schedule daily notifications
    _dailyStudyTimer = Timer.periodic(const Duration(hours: 24), (timer) async {
      await _sendDailyStudyReminder(studyHour, studyMinute);
    });

    // Send initial notification if it's study time
    final now = DateTime.now();
    if (now.hour == studyHour &&
        now.minute >= studyMinute &&
        now.minute < studyMinute + 5) {
      await _sendDailyStudyReminder(studyHour, studyMinute);
    }
  }

  /// Send premium daily study reminder
  Future<void> _sendDailyStudyReminder(int hour, int minute) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get user's learning data
      final userProfile = UserProfileService.instance;
      final displayName = await userProfile.getDisplayName();
      final studyStreak = 0; // Placeholder
      lastStudyDate = DateTime.now(); // Placeholder
      final preferredTopics = <String>['Math', 'Science']; // Placeholder

      // Personalize message based on user data
      String title = '📚 Time to Learn, $displayName!';
      String body =
          'Your personalized learning journey awaits. What will you discover today?';

      // Check if user is on a streak
      final isOnStreak = studyStreak > 1;
      if (isOnStreak) {
        title = '🔥 ${studyStreak} Day Streak! Keep it up!';
        body = 'You\'re on fire! Continue your learning journey today.';
      }

      await _notifications.zonedSchedule(
        0,
        title,
        body,
        tz.TZDateTime.now(tz.local).add(
          Duration(
            hours: hour - DateTime.now().hour,
            minutes: minute - DateTime.now().minute,
          ),
        ),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _dailyStudyChannel,
            'Daily Study Reminders',
            channelDescription:
                'Personalized daily reminders to keep your learning momentum',
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: _dailyStudyChannel,
          ),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'daily_study_reminder',
      );

      print('[PushNotification] 📚 Daily study reminder sent');
    } catch (e) {
      print('[PushNotification] Error sending daily reminder: $e');
    }
  }

  /// Send achievement notification
  Future<void> sendAchievementNotification({
    required String title,
    required String description,
    required String achievementId,
  }) async {
    try {
      await _notifications.show(
        0,
        '🎉 $title',
        description,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _achievementChannel,
            'Achievements',
            channelDescription:
                'Celebrate your learning achievements and milestones',
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: _achievementChannel,
          ),
        ),
        payload: 'achievement_$achievementId',
      );

      print('[PushNotification] 🎉 Achievement notification sent: $title');
    } catch (e) {
      print('[PushNotification] Error sending achievement: $e');
    }
  }

  /// Send learning insight notification
  Future<void> sendLearningInsightNotification({
    required String insight,
    required String recommendation,
  }) async {
    try {
      await _notifications.show(
        0,
        '💡 Learning Insight',
        insight,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _learningChannel,
            'Learning Insights',
            channelDescription:
                'Personalized insights and recommendations for your learning journey',
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(categoryIdentifier: _learningChannel),
        ),
        payload: 'learning_insight',
      );

      print('[PushNotification] 💡 Learning insight sent');
    } catch (e) {
      print('[PushNotification] Error sending insight: $e');
    }
  }

  /// Send streak milestone notification
  Future<void> sendStreakNotification(int streak) async {
    try {
      String title;
      String message;

      if (streak == 7) {
        title = '🔥 One Week Streak!';
        message =
            'Amazing dedication! You\'ve been learning for 7 days straight!';
      } else if (streak == 30) {
        title = '🌟 One Month Streak!';
        message = 'Incredible commitment! 30 days of continuous learning!';
      } else if (streak == 100) {
        title = '💎 Century Streak!';
        message = 'Legendary! 100 days of learning excellence!';
      } else {
        title = '🔥 $streak Day Streak!';
        message = 'Keep the momentum going! You\'re doing amazing!';
      }

      await _notifications.show(
        0,
        title,
        message,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _streakChannel,
            'Learning Streaks',
            channelDescription:
                'Maintain your learning streak and stay motivated',
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(categoryIdentifier: _streakChannel),
        ),
        payload: 'streak_$streak',
      );

      print('[PushNotification] 🔥 Streak notification sent: $streak days');
    } catch (e) {
      print('[PushNotification] Error sending streak notification: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse notificationResponse) {
    final payload = notificationResponse.payload;
    print('[PushNotification] Notification tapped: $payload');

    // Handle different notification types
    if (payload == 'daily_study_reminder') {
      // Navigate to study screen
      // This would be handled by the app's navigation system
    } else if (payload?.startsWith('achievement_') == true) {
      // Navigate to achievements screen
    } else if (payload == 'learning_insight') {
      // Navigate to insights screen
    } else if (payload?.startsWith('streak_') == true) {
      // Navigate to profile/progress screen
    }
  }

  /// Schedule weekly progress notifications
  Future<void> _scheduleWeeklyProgressNotifications() async {
    _weeklyProgressTimer?.cancel();

    _weeklyProgressTimer = Timer.periodic(const Duration(days: 7), (
      timer,
    ) async {
      await _sendWeeklyProgressNotification();
    });
  }

  /// Send weekly progress notification
  Future<void> _sendWeeklyProgressNotification() async {
    try {
      String title = '📊 Your Weekly Progress';
      String body =
          'You completed 5 sessions this week! Keep up the great work.';

      await _notifications.show(
        0,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _learningChannel,
            'Learning Insights',
            channelDescription:
                'Personalized insights and recommendations for your learning journey',
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(categoryIdentifier: _learningChannel),
        ),
        payload: 'weekly_progress',
      );

      print('[PushNotification] 📊 Weekly progress sent');
    } catch (e) {
      print('[PushNotification] Error sending weekly progress: $e');
    }
  }

  /// Enable/disable notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);

    if (enabled) {
      await _scheduleDailyNotifications();
      await _scheduleWeeklyProgressNotifications();
    } else {
      _dailyStudyTimer?.cancel();
      _weeklyProgressTimer?.cancel();
      await _notifications.cancelAll();
    }

    print(
      '[PushNotification] Notifications ${enabled ? 'enabled' : 'disabled'}',
    );
  }

  /// Check if notifications are enabled
  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true; // Default to enabled
  }

  /// Set daily study reminder time
  Future<void> setDailyStudyTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_study_hour', hour);
    await prefs.setInt('daily_study_minute', minute);

    // Reschedule with new time
    await _scheduleDailyNotifications();
  }

  /// Get daily study reminder time
  Future<Map<String, int>> getDailyStudyTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('daily_study_hour') ?? 19;
    final minute = prefs.getInt('daily_study_minute') ?? 0;
    return {'hour': hour, 'minute': minute};
  }
}
