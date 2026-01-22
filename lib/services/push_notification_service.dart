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
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  Timer? _dailyStudyTimer;
  Timer? _weeklyProgressTimer;

  // Notification channels
  static const String _dailyStudyChannel = 'daily_study_reminders';
  static const String _achievementChannel = 'achievements';
  static const String _learningChannel = 'learning_insights';
  static const String _streakChannel = 'learning_streaks';

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone
      tz.initializeTimeZones();

      // Request permissions
      await _notifications.initialize(
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
    const AndroidNotificationSettings androidSettings = AndroidNotificationSettings(
      channels: [
        AndroidNotificationChannel(
          _dailyStudyChannel,
          'Daily Study Reminders',
          description: 'Personalized daily reminders to keep your learning momentum',
          importance: Importance.high,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound('notification_sound'),
          playSound: true,
          enableVibration: true,
          vibrationPattern: [0, 250, 500, 250],
          ledColor: AppTheme.primaryBlue,
          ledOnMs: 1000,
          ledOffMs: 500,
          icon: '@mipmap/ic_launcher',
        ),
        AndroidNotificationChannel(
          _achievementChannel,
          'Achievements & Milestones',
          description: 'Celebrate your learning achievements and milestones',
          importance: Importance.high,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound('achievement_sound'),
          playSound: true,
          enableVibration: true,
          vibrationPattern: [0, 100, 100, 100, 200],
          ledColor: AppTheme.success,
          ledOnMs: 1500,
          ledOffMs: 500,
          icon: '@mipmap/ic_launcher',
        ),
        AndroidNotificationChannel(
          _learningChannel,
          'Learning Insights',
          description: 'Personalized insights and recommendations for your learning journey',
          importance: Importance.default,
          priority: Priority.default,
          sound: RawResourceAndroidNotificationSound('insight_sound'),
          playSound: true,
          enableVibration: false,
          ledColor: AppTheme.accentBlue,
          ledOnMs: 800,
          ledOffMs: 400,
          icon: '@mipmap/ic_launcher',
        ),
        AndroidNotificationChannel(
          _streakChannel,
          'Learning Streaks',
          description: 'Maintain your learning streak and stay motivated',
          importance: Importance.high,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound('streak_sound'),
          playSound: true,
          enableVibration: true,
          vibrationPattern: [0, 200, 100, 200, 100],
          ledColor: AppTheme.warning,
          ledOnMs: 1200,
          ledOffMs: 600,
          icon: '@mipmap/ic_launcher',
        ),
      ],
    );

    const DarwinNotificationSettings iosSettings = DarwinNotificationSettings(
      categories: [
        DarwinNotificationCategory(
          _dailyStudyChannel,
          actions: [
            DarwinNotificationAction.plain('study_now', 'Study Now'),
            DarwinNotificationAction.plain('snooze', 'Snooze'),
          ],
        ),
        DarwinNotificationCategory(
          _achievementChannel,
          actions: [
            DarwinNotificationAction.plain('view', 'View Achievement'),
            DarwinNotificationAction.plain('share', 'Share'),
          ],
        ),
      ],
    );

    await _notifications.initialize(
      androidSettings: androidSettings,
      iosSettings: iosSettings,
    );
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
    _dailyStudyTimer = Timer.periodic(Duration(hours: 24), (timer) async {
      await _sendDailyStudyReminder(studyHour, studyMinute);
    });

    // Send initial notification if it's study time
    final now = DateTime.now();
    if (now.hour == studyHour && now.minute >= studyMinute && now.minute < studyMinute + 5) {
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
      final studyStreak = await userProfile.getStudyStreak();
      lastStudyDate = await userProfile.getLastStudyDate();
      final preferredTopics = await userProfile.getPreferredTopics();

      // Personalize message based on user data
      String title = '📚 Time to Learn, $displayName!';
      String body = _generatePersonalizedMessage(studyStreak, lastStudyDate, preferredTopics);

      // Check if user is on a streak
      final isOnStreak = _isOnStudyStreak(lastStudyDate);
      if (isOnStreak && studyStreak > 1) {
        title = '🔥 ${studyStreak} Day Streak! Keep it up!';
        body = 'You\'re on fire! Continue your learning journey today.';
      }

      await _notifications.zonedSchedule(
        0,
        title,
        body,
        tz.TZDateTime.now(tz.local).add(Duration(
          hours: hour - DateTime.now().hour,
          minutes: minute - DateTime.now().minute,
        )),
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId: _dailyStudyChannel,
            icon: '@mipmap/ic_launcher',
            largeIcon: const DrawableResourceAndroidBitmap('notification_icon'),
            styleInformation: BigTextStyleInformation(
              '$body\n\nTap to start your personalized learning session!',
            ),
            actions: [
              AndroidNotificationAction('study_now', 'Study Now', icon: '@drawable/ic_study'),
              AndroidNotificationAction('snooze', 'Snooze', icon: '@drawable/ic_snooze'),
            ],
            priority: Priority.high,
            autoCancel: false,
            ongoing: false,
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: _dailyStudyChannel,
            title: title,
            body: body,
            sound: 'notification_sound.aiff',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
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

  /// Generate personalized message based on user data
  String _generatePersonalizedMessage(int streak, DateTime? lastStudy, List<String> topics) {
    final daysSinceLastStudy = lastStudy != null 
        ? DateTime.now().difference(lastStudy).inDays 
        : 999;

    if (daysSinceLastStudy > 3) {
      return 'It\'s been ${daysSinceLastStudy} days since your last session. Your learning journey misses you!';
    }

    if (topics.isNotEmpty) {
      final topic = topics.first;
      return 'Ready to continue learning about $topic? Let\'s make today count!';
    }

    if (streak > 0) {
      return 'Keep up the great work! Every small step forward is progress toward your goals.';
    }

    return 'Your personalized learning journey awaits. What will you discover today?';
  }

  /// Check if user is on a study streak
  bool _isOnStudyStreak(DateTime? lastStudyDate) {
    if (lastStudyDate == null) return false;
    
    final daysSinceLastStudy = DateTime.now().difference(lastStudyDate).inDays;
    return daysSinceLastStudy <= 2; // Allow 2-day grace period
  }

  /// Send achievement notification
  Future<void> sendAchievementNotification({
    required String title,
    required String description,
    required String achievementId,
  }) async {
    try {
      await _notifications.show(
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId: _achievementChannel,
            icon: '@mipmap/ic_launcher',
            largeIcon: const DrawableResourceAndroidBitmap('achievement_icon'),
            styleInformation: BigTextStyleInformation(description),
            actions: [
              AndroidNotificationAction('view', 'View Achievement'),
              AndroidNotificationAction('share', 'Share'),
            ],
            priority: Priority.high,
            autoCancel: false,
            color: AppTheme.success.value,
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: _achievementChannel,
            title: '🎉 $title',
            body: description,
            sound: 'achievement_sound.aiff',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
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
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId: _learningChannel,
            icon: '@mipmap/ic_launcher',
            styleInformation: BigTextStyleInformation('$insight\n\n💡 $recommendation'),
            priority: Priority.default,
            autoCancel: true,
            color: AppTheme.accentBlue.value,
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: _learningChannel,
            title: '💡 Learning Insight',
            body: insight,
            sound: 'insight_sound.aiff',
            presentAlert: false,
            presentBadge: false,
            presentSound: true,
          ),
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
        message = 'Amazing dedication! You\'ve been learning for 7 days straight!';
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
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId: _streakChannel,
            icon: '@mipmap/ic_launcher',
            largeIcon: const DrawableResourceAndroidBitmap('streak_icon'),
            styleInformation: BigTextStyleInformation('$title\n\n$message'),
            priority: Priority.high,
            autoCancel: false,
            color: AppTheme.warning.value,
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: _streakChannel,
            title: title,
            body: message,
            sound: 'streak_sound.aiff',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
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

    _weeklyProgressTimer = Timer.periodic(Duration(days: 7), (timer) async {
      await _sendWeeklyProgressNotification();
    });
  }

  /// Send weekly progress notification
  Future<void> _sendWeeklyProgressNotification() async {
    try {
      final userProfile = UserProfileService.instance;
      final weeklyProgress = await userProfile.getWeeklyProgress();
      final totalSessions = await userProfile.getTotalStudySessions();
      final avgSessionDuration = await userProfile.getAverageSessionDuration();

      String title = '📊 Your Weekly Progress';
      String body = 'You completed $weeklyProgress sessions this week! Keep up the great work.';

      if (weeklyProgress > 7) {
        title = '🚀 Outstanding Week!';
        body = 'Amazing progress! $weeklyProgress study sessions this week. You\'re on fire!';
      }

      await _notifications.show(
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId: _learningChannel,
            icon: '@mipmap/ic_launcher',
            styleInformation: BigTextStyleInformation(
              '$title\n\n$body\n\nTotal sessions: $totalSessions\nAvg duration: ${avgSessionDuration}min'
            ),
            priority: Priority.default,
            autoCancel: true,
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: _learningChannel,
            title: title,
            body: body,
            sound: 'insight_sound.aiff',
            presentAlert: false,
            presentBadge: false,
            presentSound: true,
          ),
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

    print('[PushNotification] Notifications ${enabled ? 'enabled' : 'disabled'}');
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

    print('[PushNotification] Daily study time set to ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
  }

  /// Get daily study reminder time
  Future<Map<String, int>> getDailyStudyTime() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'hour': prefs.getInt('daily_study_hour') ?? 19,
      'minute': prefs.getInt('daily_study_minute') ?? 0,
    };
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    print('[PushNotification] All notifications cancelled');
  }

  /// Dispose resources
  void dispose() {
    _dailyStudyTimer?.cancel();
    _weeklyProgressTimer?.cancel();
    _notifications.cancelAll();
  }
}
