# Smart Study Notifications + Streak System - Implementation Guide

## Overview

A robust, intelligent notification system that tracks daily study streaks, celebrates milestones, and sends smart reminders only when users haven't studied recently.

## Architecture

### 1. **StudyActivityService** (`lib/services/study_activity_service.dart`)

The core service that tracks study interactions and manages streak logic.

#### Key Responsibilities:

- ✅ Track study activities (messages, quizzes, modules)
- ✅ Calculate and persist streaks locally via SharedPreferences
- ✅ Enforce 24-hour streak rules
- ✅ Manage milestone notifications
- ✅ Provide study statistics

#### Streak Logic (Critical):

```
When a valid study interaction happens:

1. If lastStudyTimestamp is null:
   - Set streak = 1

2. Else calculate time difference:
   - If difference ≤ 24 hours → Do NOT increment (same day)
   - If difference > 24h AND ≤ 48h → Increment streak by 1
   - If difference > 48 hours → Reset streak to 1

3. Update lastStudyTimestamp to now
```

#### Data Persistence:

```dart
// Local storage via SharedPreferences
study_last_timestamp      // DateTime of last study
study_current_streak      // Current streak days
study_longest_streak      // Longest streak ever
study_last_milestone      // Last notified milestone (3 or 7)
```

#### Public Methods:

**recordStudyActivity()**

```dart
// Record when user sends a message, completes a quiz, etc.
final streakData = await _studyActivityService.recordStudyActivity(
  activityType: 'message',     // 'message', 'quiz', 'module'
  botId: widget.botId,
  metadata: 'User message...'
);

// Returns: StudyStreakData with current streak and increment status
// streakData.currentStreak → Current streak count
// streakData.streakIncremented → Whether streak was incremented
```

**shouldSendDailyReminder()**

```dart
// Check if user should receive a reminder
if (_studyActivityService.shouldSendDailyReminder()) {
  // Send reminder - no study in ≥24 hours
}
```

**shouldNotifyMilestone()**

```dart
// Check if milestone (3 or 7 days) should be notified
if (_studyActivityService.shouldNotifyMilestone(streakDays)) {
  // Show milestone notification
}
```

**markMilestoneNotified()**

```dart
// Prevent duplicate milestone notifications
await _studyActivityService.markMilestoneNotified(3);  // Mark day 3 done
```

**getStudyStats()**

```dart
// Get full statistics
final stats = await _studyActivityService.getStudyStats();
// stats.currentStreak
// stats.longestStreak
// stats.lastStudyTime
// stats.lastNotifiedMilestone
```

### 2. **StudyNotificationService** (`lib/services/study_notification_service.dart`)

Handles notification scheduling and delivery.

#### Key Responsibilities:

- ✅ Schedule daily reminders (9 AM, timezone-safe)
- ✅ Send milestone celebrations (3-day, 7-day)
- ✅ Prevent spam notifications
- ✅ Handle iOS/Android differences

#### Notification Types:

**Daily Reminder** (9 AM every day)

```
Title: 🧠 Time to Study!
Body: Your study bot misses you ✨ Let's do a quick learning session today.
Condition: Only if no study in last 24 hours
Channel: Study Reminders (High priority)
```

**Milestone Notifications**

```
3-Day Streak:
  Title: 🔥 3-Day Streak!
  Body: 🔥 3-day streak! You're building a powerful study habit.

7-Day Streak:
  Title: 🚀 7-Day Streak!
  Body: 🚀 7 DAYS STRAIGHT! You're officially unstoppable. Keep it up!

Channel: Streak Milestones (High priority)
```

#### Public Methods:

**initialize()**

```dart
// Call once at app startup (in main.dart)
await StudyNotificationService().initialize();
```

**scheduleDailyReminder()**

```dart
// Schedule/reschedule the daily reminder
await _studyNotificationService.scheduleDailyReminder();
// Smart check: Only notifies if ≥24 hours since last study
```

**notifyStreakMilestone()**

```dart
// Send milestone notification and mark as notified
await _studyNotificationService.notifyStreakMilestone(3);  // 3-day milestone
await _studyNotificationService.notifyStreakMilestone(7);  // 7-day milestone
```

**cancelAllNotifications()**

```dart
// Clean up all study notifications
await _studyNotificationService.cancelAllNotifications();
```

## Integration Points

### 1. Study Bot Chat (study_plan_chat_screen.dart)

When user sends a message and receives bot response:

```dart
// After successful backend response
final streakData = await _studyActivityService.recordStudyActivity(
  activityType: 'message',
  botId: widget.botId,
  metadata: 'User message...'
);

// Check if milestone should be celebrated
if (streakData.streakIncremented) {
  if (_studyActivityService.shouldNotifyMilestone(streakData.currentStreak)) {
    await _studyNotificationService.notifyStreakMilestone(
      streakData.currentStreak,
    );
  }
}
```

### 2. Quiz Completion

```dart
// After user completes a quiz
await _studyActivityService.recordStudyActivity(
  activityType: 'quiz',
  botId: widget.botId,
  metadata: 'Quiz: $quizTitle',
);
```

### 3. Module Completion

```dart
// After user completes a module
await _studyActivityService.recordStudyActivity(
  activityType: 'module',
  botId: widget.botId,
  metadata: 'Module: $moduleName',
);
```

### 4. App Startup (main.dart)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await StudyActivityService().initialize();
  await StudyNotificationService().initialize();

  runApp(MyApp());
}
```

## Testing & Validation

### 1. Test Streak Logic

```dart
// Test case 1: First study
await service.recordStudyActivity(activityType: 'message');
// Expected: streak = 1

// Test case 2: Study same day
await service.recordStudyActivity(activityType: 'message');
// Expected: streak = 1 (no increment)

// Test case 3: Study after 25 hours
// (Wait or mock time)
await service.recordStudyActivity(activityType: 'message');
// Expected: streak = 2 (incremented)

// Test case 4: Study after 49 hours
await service.recordStudyActivity(activityType: 'message');
// Expected: streak = 1 (reset)
```

### 2. Test Milestone Notifications

```dart
// Record activities until day 3
// On 3rd day, streak should increment to 3
// Notification should automatically trigger

// Check it doesn't notify twice
// Should be marked and skipped next time
```

### 3. Test Daily Reminders

```dart
// Schedule reminder
await _studyNotificationService.scheduleDailyReminder();

// If no study in 24h: Should send
// If recent study: Should skip
```

### 4. Test Persistence

```dart
// Record activity
await service.recordStudyActivity(activityType: 'message');

// Close and reopen app
// Verify: streak persists, timestamp persists, milestone state persists
```

## Data Flow Diagram

```
User Studies (Message/Quiz/Module)
           ↓
_sendMessageToBackend() or equivalent
           ↓
recordStudyActivity()
           ├─ Check lastStudyTimestamp
           ├─ Calculate time difference
           ├─ Apply streak logic
           └─ Persist to SharedPreferences
           ↓
Check shouldNotifyMilestone()
           ├─ Is currentStreak a milestone? (3 or 7)
           ├─ Was this milestone already notified?
           └─ If not → Call notifyStreakMilestone()
           ↓
notifyStreakMilestone()
           ├─ Show notification (iOS/Android)
           ├─ Call markMilestoneNotified()
           └─ Update lastNotifiedMilestone in SharedPreferences
```

## Configuration

### Milestones

Currently configured for days 3 and 7. To add more:

In `study_activity_service.dart`:

```dart
const List<int> milestones = [3, 7, 14, 30];  // Add day 14, 30, etc.
```

In `study_notification_service.dart`:

```dart
(String, String, String) _getMilestoneNotificationContent(int streakDays) {
  switch (streakDays) {
    case 14:
      return ('🌟 2-Week Streak!', '14 DAYS! You\'re a study superstar!', '🌟');
    // ... add more cases
  }
}
```

### Daily Reminder Time

Currently: 9 AM local time. To change:

In `study_notification_service.dart`:

```dart
scheduledDate = scheduledDate.copyWith(
  hour: 14,  // Change to 2 PM
  minute: 0,
  second: 0,
);
```

### Notification Channels

Configured for high priority. To adjust:

In `study_notification_service.dart`:

```dart
importance: Importance.low,  // Change importance level
priority: Priority.low,
playSound: false,            // Disable sound if needed
enableVibration: false,
```

## Timezone Considerations

✅ **Timezone Safe**: All notifications use `tz.TZDateTime` for correct local time handling
✅ **Daylight Saving**: Automatically handled by `timezone` package
✅ **International**: Works correctly across all timezones

## Notifications Disabled?

If user has disabled notifications in settings:

1. Services still track streaks locally
2. Notifications won't be sent (but can be re-enabled)
3. Streaks persist even if notifications are off

## Error Handling

- Service initialization errors logged but don't crash app
- Study activity recording wrapped in try-catch
- Notification scheduling failures don't block chat functionality
- All errors logged with `[StudyActivity]` and `[StudyNotification]` prefixes

## Dependencies

All required dependencies already in pubspec.yaml:

- ✅ `shared_preferences: ^2.1.0` - Local persistence
- ✅ `flutter_local_notifications: ^17.0.0` - Notifications
- ✅ `timezone: ^0.9.2` - Timezone handling
- ✅ `firebase_auth: ^5.0.0` - User authentication

## Future Enhancements

1. **Customizable Milestones**: Allow users to set their own milestone celebrations
2. **Sound Customization**: Different notification sounds for different events
3. **Streak History**: Display streak history with charts
4. **Social Sharing**: Share milestones to social media
5. **Streak Breaks Recovery**: Notify users about recovering streaks
6. **Weekly Reports**: Summarize study activity each week
7. **Team Streaks**: Compete with friends on streaks
8. **Notification Timing**: Let users customize when they get reminders

## Debug Logging

All services include detailed logging:

```
[StudyActivity] ✅ Study activity service initialized
[StudyActivity] 🎯 First study session recorded. Streak: 1
[StudyActivity] 🔥 Streak incremented! New streak: 2
[StudyActivity] 🔄 Streak broken (>2.5 days). Reset to 1.
[StudyActivity] 📢 Should send reminder: 25h since last study
[StudyActivity] 🎉 Milestone 3 should be notified
[StudyActivity] ✅ Marked milestone 3 as notified

[StudyNotification] ✅ Study notification service initialized
[StudyNotification] 📅 Daily reminder scheduled for 2026-01-29 09:00:00
[StudyNotification] 🎉 Milestone notification sent: 3 days
```

To debug, enable logging or check app console output in Flutter DevTools.
