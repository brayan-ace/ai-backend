import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:permission_handler/permission_handler.dart';
import 'study_activity_service.dart';

/// Study Notification Service
/// Manages notifications for study streaks and daily reminders
/// Handles:
/// - Daily reminders (only when no recent study)
/// - Milestone notifications (3-day and 7-day streaks)
/// - Timezone-safe notification scheduling
class StudyNotificationService {
  static final StudyNotificationService _instance =
      StudyNotificationService._internal();

  factory StudyNotificationService() => _instance;

  StudyNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final StudyActivityService _activityService = StudyActivityService();

  bool _isInitialized = false;

  // Notification IDs
  static const int _dailyReminderNotificationId = 1001;
  static const int _streakMilestoneNotificationId = 1002;

  // Notification channels
  static const String _studyReminderChannel = 'study_reminders';
  static const String _streakMilestoneChannel = 'streak_milestones';

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone data
      tz_data.initializeTimeZones();

      // Android initialization
      const AndroidInitializationSettings androidInitializationSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization
      const DarwinInitializationSettings iosInitializationSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      // Combined initialization
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

      // Request notification permissions (Android 13+)
      await _requestNotificationPermissions();

      _isInitialized = true;
      print('[StudyNotification] ✅ Study notification service initialized');
    } catch (e) {
      print('[StudyNotification] ❌ Error initializing: $e');
      rethrow;
    }
  }

  /// Request notification permissions (Android 13+)
  Future<void> _requestNotificationPermissions() async {
    try {
      final status = await Permission.notification.request();
      print('[StudyNotification] Notification permission: $status');

      if (status.isDenied) {
        print('[StudyNotification] ⚠️ Notification permission denied');
      } else if (status.isGranted) {
        print('[StudyNotification] ✅ Notification permission granted');
      } else if (status.isPermanentlyDenied) {
        print(
          '[StudyNotification] ⚠️ Notification permission permanently denied - open app settings',
        );
      }
    } catch (e) {
      print(
        '[StudyNotification] ⚠️ Could not request notification permission: $e',
      );
    }
  }

  /// Schedule daily study reminder
  /// Only sends if the user hasn't studied in the last 24 hours
  /// Scheduled for 9 AM every day in the user's timezone
  Future<void> scheduleDailyReminder() async {
    _ensureInitialized();

    try {
      // Check if reminder should be sent
      if (!_activityService.shouldSendDailyReminder()) {
        print('[StudyNotification] Daily reminder skipped (recent study)');
        return;
      }

      // Get user's timezone
      final tzLocation = tz.local;

      // Schedule for 9 AM today or tomorrow
      var scheduledDate = tz.TZDateTime.from(
        DateTime.now().add(Duration(hours: 9)),
        tzLocation,
      );

      // If it's already past 9 AM, schedule for tomorrow
      if (scheduledDate.isBefore(tz.TZDateTime.now(tzLocation))) {
        scheduledDate = scheduledDate.add(Duration(days: 1));
      }

      // Reset the time to 9 AM
      final scheduledDateTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        9,
        0,
        0,
      );
      scheduledDate = tz.TZDateTime.from(scheduledDateTime, tzLocation);

      await _notifications.zonedSchedule(
        _dailyReminderNotificationId,
        '🧠 Time to Study!',
        'Your study bot misses you ✨ Let\'s do a quick learning session today.',
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _studyReminderChannel,
            'Study Reminders',
            channelDescription:
                'Daily reminders to keep your learning momentum',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
      );

      print(
        '[StudyNotification] 📅 Daily reminder scheduled for ${scheduledDate.toString()}',
      );
    } catch (e) {
      print('[StudyNotification] ❌ Error scheduling daily reminder: $e');
    }
  }

  /// Send milestone notification for streaks
  /// Automatically called when user reaches 3-day or 7-day streaks
  Future<void> notifyStreakMilestone(int streakDays) async {
    _ensureInitialized();

    try {
      // Check if this milestone should be notified
      if (!_activityService.shouldNotifyMilestone(streakDays)) {
        print('[StudyNotification] Milestone $streakDays already notified');
        return;
      }

      // Get milestone message
      final (title, body, emoji) = _getMilestoneNotificationContent(streakDays);

      // Show notification immediately
      await _notifications.show(
        _streakMilestoneNotificationId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _streakMilestoneChannel,
            'Streak Milestones',
            channelDescription: 'Celebrate your learning streaks',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );

      // Mark milestone as notified
      await _activityService.markMilestoneNotified(streakDays);

      print(
        '[StudyNotification] 🎉 Milestone notification sent: $streakDays days',
      );
    } catch (e) {
      print('[StudyNotification] ❌ Error notifying milestone: $e');
    }
  }

  /// Cancel all study notifications
  Future<void> cancelAllNotifications() async {
    _ensureInitialized();

    try {
      await _notifications.cancel(_dailyReminderNotificationId);
      await _notifications.cancel(_streakMilestoneNotificationId);
      print('[StudyNotification] All study notifications cancelled');
    } catch (e) {
      print('[StudyNotification] ❌ Error cancelling notifications: $e');
    }
  }

  // ============================================================================
  // PRIVATE HELPERS
  // ============================================================================

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception(
        'StudyNotificationService not initialized. Call initialize() first.',
      );
    }
  }

  Future<void> _createNotificationChannels() async {
    try {
      // Study reminder channel
      const AndroidNotificationChannel studyReminderChannel =
          AndroidNotificationChannel(
            _studyReminderChannel,
            'Study Reminders',
            description: 'Daily reminders to keep your learning momentum',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          );

      // Streak milestone channel
      const AndroidNotificationChannel streakMilestoneChannel =
          AndroidNotificationChannel(
            _streakMilestoneChannel,
            'Streak Milestones',
            description: 'Celebrate your learning streaks',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          );

      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(studyReminderChannel);

      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(streakMilestoneChannel);

      print('[StudyNotification] ✅ Notification channels created');
    } catch (e) {
      print('[StudyNotification] Warning: Could not create channels: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('[StudyNotification] Notification tapped: ${response.payload}');
    // TODO: Handle notification tap (navigate to study screen)
  }

  (String title, String body, String emoji) _getMilestoneNotificationContent(
    int streakDays,
  ) {
    switch (streakDays) {
      case 3:
        return (
          '🔥 3-Day Streak!',
          '🔥 3-day streak! You\'re building a powerful study habit.',
          '🔥',
        );
      case 7:
        return (
          '🚀 7-Day Streak!',
          '🚀 7 DAYS STRAIGHT! You\'re officially unstoppable. Keep it up!',
          '🚀',
        );
      default:
        return (
          '⭐ Streak Milestone!',
          'Congratulations on your $streakDays-day streak!',
          '⭐',
        );
    }
  }
}
