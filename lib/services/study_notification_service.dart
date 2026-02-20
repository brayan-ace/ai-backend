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
  /// Schedule UNCONDITIONAL daily reminders at 6 AM and 6 PM EVERY DAY
  /// These notifications will be sent regardless of whether user has studied or opened the app
  /// Scheduled for 6 AM and 6 PM every day in the user's timezone
  Future<void> scheduleDailyReminder() async {
    _ensureInitialized();

    try {
      // Get user's timezone
      final tzLocation = tz.local;

      // Schedule for 6 AM - UNCONDITIONAL
      await _scheduleReminderAtTime(6, 0, tzLocation);

      // Schedule for 6 PM (18:00) - UNCONDITIONAL
      await _scheduleReminderAtTime(18, 0, tzLocation);

      print(
        '[StudyNotification] ✅ UNCONDITIONAL Daily reminders scheduled for 6 AM and 6 PM (will send every day)',
      );
    } catch (e) {
      print('[StudyNotification] ❌ Error scheduling daily reminder: $e');
    }
  }

  /// Helper method to schedule a reminder at a specific time
  Future<void> _scheduleReminderAtTime(
    int hour,
    int minute,
    tz.Location tzLocation,
  ) async {
    try {
      var scheduledDate = tz.TZDateTime.now(tzLocation);

      // Create scheduled date for the given time
      var scheduledDateTime = tz.TZDateTime(
        tzLocation,
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        hour,
        minute,
        0,
      );

      // If it's already past this time, schedule for tomorrow
      if (scheduledDateTime.isBefore(tz.TZDateTime.now(tzLocation))) {
        scheduledDateTime = scheduledDateTime.add(Duration(days: 1));
      }

      await _notifications.zonedSchedule(
        _dailyReminderNotificationId + hour, // Different ID for each time
        '🧠 Time to Study!',
        'Your study bot misses you ✨ Let\'s do a quick learning session today.',
        scheduledDateTime,
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
        '[StudyNotification] 📅 Reminder scheduled for ${scheduledDateTime.toString()}',
      );
    } catch (e) {
      print(
        '[StudyNotification] ❌ Error scheduling reminder at ${hour}:$minute: $e',
      );
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
