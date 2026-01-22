import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;
import '../utils/theme.dart';
import '../services/push_notification_service.dart';
import '../services/user_profile_service.dart';

/// Premium Notification Settings Screen
/// Allows users to manage their push notification preferences
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final PushNotificationService _notificationService =
      PushNotificationService();
  final UserProfileService _userProfile = UserProfileService.instance;

  bool _notificationsEnabled = true;
  int _dailyStudyHour = 19;
  int _dailyStudyMinute = 0;
  bool _dailyNotificationsEnabled = true;
  bool _achievementNotificationsEnabled = true;
  bool _insightNotificationsEnabled = true;
  bool _streakNotificationsEnabled = true;
  bool _weeklyProgressNotificationsEnabled = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      _notificationsEnabled = await _notificationService
          .getNotificationsEnabled();
      final studyTime = await _notificationService.getDailyStudyTime();
      _dailyStudyHour = studyTime['hour']!;
      _dailyStudyMinute = studyTime['minute']!;

      // Load user preferences from UserProfileService
      await _userProfile.init();
      _dailyNotificationsEnabled =
          await _userProfile.getPreference('daily_notifications_enabled') ??
          true;
      _achievementNotificationsEnabled =
          await _userProfile.getPreference(
            'achievement_notifications_enabled',
          ) ??
          true;
      _insightNotificationsEnabled =
          await _userProfile.getPreference('insight_notifications_enabled') ??
          true;
      _streakNotificationsEnabled =
          await _userProfile.getPreference('streak_notifications_enabled') ??
          true;
      _weeklyProgressNotificationsEnabled =
          await _userProfile.getPreference(
            'weekly_progress_notifications_enabled',
          ) ??
          true;
    } catch (e) {
      print('[NotificationSettings] Error loading settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      // Save notification service settings
      await _notificationService.setNotificationsEnabled(_notificationsEnabled);
      await _notificationService.setDailyStudyTime(
        _dailyStudyHour,
        _dailyStudyMinute,
      );

      // Save user preferences
      await _userProfile.setPreference(
        'daily_notifications_enabled',
        _dailyNotificationsEnabled,
      );
      await _userProfile.setPreference(
        'achievement_notifications_enabled',
        _achievementNotificationsEnabled,
      );
      await _userProfile.setPreference(
        'insight_notifications_enabled',
        _insightNotificationsEnabled,
      );
      await _userProfile.setPreference(
        'streak_notifications_enabled',
        _streakNotificationsEnabled,
      );
      await _userProfile.setPreference(
        'weekly_progress_notifications_enabled',
        _weeklyProgressNotificationsEnabled,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Settings saved successfully!'),
            ],
          ),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Error saving settings: $e'),
            ],
          ),
          backgroundColor: AppTheme.error,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGradientStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Notification Settings',
          style: AppTheme.headlineMedium.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: AppTheme.primaryBlue),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Master Toggle
                  _buildSectionCard(
                    title: '🔔 Enable Notifications',
                    subtitle: 'Turn on/off all push notifications',
                    child: Switch(
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() => _notificationsEnabled = value);
                      },
                      activeColor: AppTheme.primaryBlue,
                    ),
                  ),

                  const SizedBox(height: AppTheme.spaceLg),

                  // Daily Study Reminders
                  _buildSectionCard(
                    title: '📚 Daily Study Reminders',
                    subtitle:
                        'Get personalized daily reminders to keep your learning momentum',
                    child: Column(
                      children: [
                        Switch(
                          value: _dailyNotificationsEnabled,
                          onChanged: (value) {
                            setState(() => _dailyNotificationsEnabled = value);
                          },
                          activeColor: AppTheme.primaryBlue,
                        ),
                        const SizedBox(height: AppTheme.spaceMd),
                        _buildTimeSelector(),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.spaceLg),

                  // Achievement Notifications
                  _buildSectionCard(
                    title: '🎉 Achievements',
                    subtitle:
                        'Celebrate your learning milestones and achievements',
                    child: Switch(
                      value: _achievementNotificationsEnabled,
                      onChanged: (value) {
                        setState(
                          () => _achievementNotificationsEnabled = value,
                        );
                      },
                      activeColor: AppTheme.success,
                    ),
                  ),

                  const SizedBox(height: AppTheme.spaceLg),

                  // Learning Insights
                  _buildSectionCard(
                    title: '💡 Learning Insights',
                    subtitle:
                        'Receive personalized insights and recommendations',
                    child: Switch(
                      value: _insightNotificationsEnabled,
                      onChanged: (value) {
                        setState(() => _insightNotificationsEnabled = value);
                      },
                      activeColor: AppTheme.accentBlue,
                    ),
                  ),

                  const SizedBox(height: AppTheme.spaceLg),

                  // Learning Streaks
                  _buildSectionCard(
                    title: '🔥 Learning Streaks',
                    subtitle:
                        'Stay motivated with streak milestone notifications',
                    child: Switch(
                      value: _streakNotificationsEnabled,
                      onChanged: (value) {
                        setState(() => _streakNotificationsEnabled = value);
                      },
                      activeColor: AppTheme.warning,
                    ),
                  ),

                  const SizedBox(height: AppTheme.spaceLg),

                  // Weekly Progress
                  _buildSectionCard(
                    title: '📊 Weekly Progress',
                    subtitle: 'Get weekly summaries of your learning progress',
                    child: Switch(
                      value: _weeklyProgressNotificationsEnabled,
                      onChanged: (value) {
                        setState(
                          () => _weeklyProgressNotificationsEnabled = value,
                        );
                      },
                      activeColor: AppTheme.primaryBlue,
                    ),
                  ),

                  const SizedBox(height: AppTheme.spaceXl),

                  // Test Notifications
                  _buildTestSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppTheme.surfaceGradient),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.surfaceElevated.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.headlineSmall.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              child,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Study Time',
            style: AppTheme.labelMedium.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showTimePicker(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMd,
                      vertical: AppTheme.spaceSm,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppTheme.surfaceElevated,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          Icons.schedule,
                          color: AppTheme.primaryBlue,
                          size: 20,
                        ),
                        Text(
                          '${_dailyStudyHour.toString().padLeft(2, '0')}:${_dailyStudyMinute.toString().padLeft(2, '0')}',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showTimePicker() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _dailyStudyHour, minute: _dailyStudyMinute),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dailyStudyHour = picked.hour;
        _dailyStudyMinute = picked.minute;
      });
    }
  }

  Widget _buildTestSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppTheme.surfaceGradient),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.surfaceElevated.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🧪 Test Notifications',
            style: AppTheme.headlineSmall.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send test notifications to verify they\'re working properly',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testDailyNotification,
                  icon: Icon(Icons.notifications_active),
                  label: Text('Test Daily Reminder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testAchievementNotification,
                  icon: Icon(Icons.emoji_events),
                  label: Text('Test Achievement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testInsightNotification,
                  icon: Icon(Icons.lightbulb),
                  label: Text('Test Insight'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testStreakNotification,
                  icon: Icon(Icons.local_fire_department),
                  label: Text('Test Streak'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warning,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _testDailyNotification() async {
    await _notificationService.sendLearningInsightNotification(
      insight: 'Test Daily Study Reminder',
      recommendation:
          'This is a test notification to verify your daily reminders are working.',
    );
  }

  Future<void> _testAchievementNotification() async {
    await _notificationService.sendAchievementNotification(
      title: 'Test Achievement',
      description:
          'This is a test achievement notification to verify your achievement alerts are working.',
      achievementId: 'test_achievement',
    );
  }

  Future<void> _testInsightNotification() async {
    await _notificationService.sendLearningInsightNotification(
      insight: 'Test Learning Insight',
      recommendation:
          'This is a test insight notification to verify your learning insights are working.',
    );
  }

  Future<void> _testStreakNotification() async {
    await _notificationService.sendStreakNotification(5);
  }
}
