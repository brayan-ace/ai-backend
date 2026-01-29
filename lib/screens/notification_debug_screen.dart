import 'package:flutter/material.dart';
import '../services/notification_test_service.dart';

/// Notification Debug Screen
/// Test and verify the notification system is working correctly
class NotificationDebugScreen extends StatefulWidget {
  const NotificationDebugScreen({Key? key}) : super(key: key);

  @override
  State<NotificationDebugScreen> createState() =>
      _NotificationDebugScreenState();
}

class _NotificationDebugScreenState extends State<NotificationDebugScreen> {
  final NotificationTestService _testService = NotificationTestService();
  Map<String, dynamic>? _systemStatus;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() => _loading = true);
    final status = await _testService.getNotificationSystemStatus();
    setState(() {
      _systemStatus = status;
      _loading = false;
    });
  }

  Future<void> _requestPermission() async {
    setState(() => _loading = true);
    final result = await _testService.requestNotificationPermission();
    setState(() => _loading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Permission updated')),
      );
      _refreshStatus();
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() => _loading = true);
    final result = await _testService.sendTestNotification(
      title: '🧪 Test Notification',
      body:
          'This is a test notification. If you see this, notifications are working!',
    );
    setState(() => _loading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['success'] == true
                ? '✅ Test notification sent!'
                : '❌ Failed to send notification',
          ),
        ),
      );
    }
  }

  Future<void> _testStudyActivity() async {
    setState(() => _loading = true);
    final result = await _testService.testStudyActivityFlow();
    setState(() => _loading = false);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(result['success'] == true ? '✅ Success' : '❌ Error'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(result['message'] ?? ''),
                SizedBox(height: 16),
                if (result['stats'] != null) ...[
                  Text(
                    'Current Streak: ${result['stats']['currentStreak']} days',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    'Longest Streak: ${result['stats']['longestStreak']} days',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    'Last Study: ${result['stats']['lastStudyTime'] ?? 'Never'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        ),
      );
      _refreshStatus();
    }
  }

  Future<void> _sendStreakNotification(int days) async {
    setState(() => _loading = true);
    final result = await _testService.sendStudyStreakTest(days);
    setState(() => _loading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['success'] == true
                ? '✅ ${days}-day streak notification sent!'
                : '❌ Failed to send notification',
          ),
        ),
      );
      _refreshStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('🔔 Notification Debug'), elevation: 0),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Permission Status
                  _buildSection(
                    title: '📋 Permission Status',
                    child: _buildPermissionStatus(),
                  ),
                  SizedBox(height: 16),

                  // Study Stats
                  _buildSection(
                    title: '📊 Study Stats',
                    child: _buildStudyStats(),
                  ),
                  SizedBox(height: 16),

                  // Action Buttons
                  _buildSection(
                    title: '🧪 Test Actions',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _requestPermission,
                          icon: Icon(Icons.notifications_active),
                          label: Text('Request Permission'),
                        ),
                        SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _sendTestNotification,
                          icon: Icon(Icons.send),
                          label: Text('Send Test Notification'),
                        ),
                        SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _testStudyActivity,
                          icon: Icon(Icons.school),
                          label: Text('Record Study Activity'),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _sendStreakNotification(3),
                                icon: Icon(Icons.local_fire_department),
                                label: Text('3-Day Streak'),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _sendStreakNotification(7),
                                icon: Icon(Icons.rocket_launch),
                                label: Text('7-Day Streak'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Next Milestones
                  if (_systemStatus != null &&
                      _systemStatus!['nextMilestones'] != null)
                    _buildSection(
                      title: '🎯 Upcoming Milestones',
                      child: Text(
                        _systemStatus!['nextMilestones'].isEmpty
                            ? 'No upcoming milestones'
                            : 'Next: ${_systemStatus!['nextMilestones'].first} days',
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshStatus,
        child: Icon(Icons.refresh),
        tooltip: 'Refresh Status',
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionStatus() {
    if (_systemStatus == null || _systemStatus!['permission'] == null) {
      return Text('Loading...');
    }

    final perm = _systemStatus!['permission'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusRow(
          'Status',
          perm['isGranted'] == true ? '✅ Granted' : '❌ ${perm['status']}',
          perm['isGranted'] == true ? Colors.green : Colors.red,
        ),
        SizedBox(height: 8),
        Text(
          perm['message'] ?? '',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildStudyStats() {
    if (_systemStatus == null || _systemStatus!['studyStats'] == null) {
      return Text('Loading...');
    }

    final stats = _systemStatus!['studyStats'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatRow('Current Streak', '${stats['currentStreak']} days'),
        _buildStatRow('Longest Streak', '${stats['longestStreak']} days'),
        _buildStatRow('Last Study', stats['lastStudyTime'] ?? 'Never'),
        _buildStatRow(
          'Should Send Reminder',
          stats['shouldSendReminder'] == true ? '✅ Yes' : '❌ No',
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
