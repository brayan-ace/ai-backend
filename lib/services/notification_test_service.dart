import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'study_activity_service.dart';
import 'study_notification_service.dart';

/// Notification Test Service
/// Debug utility to test notification system and verify setup
class NotificationTestService {
  static final NotificationTestService _instance =
      NotificationTestService._internal();

  factory NotificationTestService() => _instance;

  NotificationTestService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final StudyActivityService _activityService = StudyActivityService();
  final StudyNotificationService _notificationService =
      StudyNotificationService();

  /// Check notification permission status
  Future<Map<String, dynamic>> checkNotificationPermissionStatus() async {
    try {
      final status = await Permission.notification.status;

      return {
        'isDenied': status.isDenied,
        'isGranted': status.isGranted,
        'isPermanentlyDenied': status.isPermanentlyDenied,
        'isRestricted': status.isRestricted,
        'status': status.toString(),
        'message': _getPermissionMessage(status),
      };
    } catch (e) {
      return {'error': true, 'message': 'Error checking permission: $e'};
    }
  }

  /// Request notification permission
  Future<Map<String, dynamic>> requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();

      return {
        'isDenied': status.isDenied,
        'isGranted': status.isGranted,
        'isPermanentlyDenied': status.isPermanentlyDenied,
        'isRestricted': status.isRestricted,
        'status': status.toString(),
        'message': _getPermissionMessage(status),
      };
    } catch (e) {
      return {'error': true, 'message': 'Error requesting permission: $e'};
    }
  }

  /// Send test notification (immediate)
  Future<Map<String, dynamic>> sendTestNotification({
    required String title,
    required String body,
    String channelId = 'test_channel',
  }) async {
    try {
      // Create test channel if needed
      const AndroidNotificationChannel testChannel = AndroidNotificationChannel(
        'test_channel',
        'Test Notifications',
        description: 'Channel for testing notifications',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(testChannel);

      // Send test notification
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Test Notifications',
            channelDescription: 'Channel for testing notifications',
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

      print('[NotificationTest] ✅ Test notification sent: $title');
      return {
        'success': true,
        'message': 'Test notification sent',
        'title': title,
        'body': body,
      };
    } catch (e) {
      print('[NotificationTest] ❌ Error sending test notification: $e');
      return {
        'success': false,
        'error': true,
        'message': 'Error sending test notification: $e',
      };
    }
  }

  /// Send study streak notification
  Future<Map<String, dynamic>> sendStudyStreakTest(int days) async {
    try {
      await _notificationService.notifyStreakMilestone(days);
      return {
        'success': true,
        'message': 'Study streak notification sent for $days days',
        'streak': days,
      };
    } catch (e) {
      return {
        'success': false,
        'error': true,
        'message': 'Error sending streak notification: $e',
      };
    }
  }

  /// Test full study activity flow
  Future<Map<String, dynamic>> testStudyActivityFlow() async {
    try {
      // Record study activity
      final streakData = await _activityService.recordStudyActivity(
        activityType: 'test_message',
        metadata: 'Test activity',
      );

      // Get stats
      final stats = await _activityService.getStudyStats();

      return {
        'success': true,
        'message': 'Study activity recorded',
        'streak': streakData.currentStreak,
        'streakIncremented': streakData.streakIncremented,
        'stats': {
          'currentStreak': stats.currentStreak,
          'longestStreak': stats.longestStreak,
          'lastStudyTime': stats.lastStudyTime?.toString(),
          'lastNotifiedMilestone': stats.lastNotifiedMilestone,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': true,
        'message': 'Error testing study activity: $e',
      };
    }
  }

  /// Get complete notification system status
  Future<Map<String, dynamic>> getNotificationSystemStatus() async {
    try {
      final permissionStatus = await checkNotificationPermissionStatus();
      final stats = await _activityService.getStudyStats();

      return {
        'permission': permissionStatus,
        'studyStats': {
          'currentStreak': stats.currentStreak,
          'longestStreak': stats.longestStreak,
          'lastStudyTime': stats.lastStudyTime?.toString(),
          'lastNotifiedMilestone': stats.lastNotifiedMilestone,
          'shouldSendReminder': _activityService.shouldSendDailyReminder(),
        },
        'nextMilestones': _getNextMilestones(stats.currentStreak),
      };
    } catch (e) {
      return {'error': true, 'message': 'Error getting system status: $e'};
    }
  }

  // ============================================================================
  // PRIVATE HELPERS
  // ============================================================================

  String _getPermissionMessage(PermissionStatus status) {
    if (status.isDenied) {
      return 'Notification permission denied. Tap to request.';
    } else if (status.isGranted) {
      return '✅ Notifications enabled! You\'ll receive study reminders.';
    } else if (status.isPermanentlyDenied) {
      return '⚠️ Notification permission permanently denied. Go to Settings > Notifications to enable.';
    } else if (status.isRestricted) {
      return '⚠️ Notifications restricted on this device.';
    }
    return 'Unknown permission status';
  }

  List<int> _getNextMilestones(int currentStreak) {
    const List<int> allMilestones = [3, 7, 14, 30];
    return allMilestones.where((m) => m > currentStreak).toList();
  }
}
