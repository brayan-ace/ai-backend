# ✅ Notification Setup & Troubleshooting Guide

## Quick Checklist

- [ ] Android manifest has `POST_NOTIFICATIONS` permission
- [ ] App requests notification permission on startup
- [ ] Notification channels are created
- [ ] Permission is granted in device settings
- [ ] Test notifications send successfully

## Step 1: Check Android Permission

The app needs the `POST_NOTIFICATIONS` permission for Android 13+.

✅ **Already added to AndroidManifest.xml:**

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

## Step 2: Grant App Permission

### On Android Device:

1. Open **Settings** → **Apps** → **Nexa Smart AI**
2. Tap **Notifications** or **Permissions**
3. Look for **Notifications** permission
4. Toggle it **ON**

**If you don't see Notifications tab:**

- Try: Settings → Apps → Permissions → Notifications
- Or: Settings → Notifications → Manage → Nexa Smart AI

### If permission is "Permanently Denied":

1. Go to Settings → Apps → Nexa Smart AI
2. Tap **Permissions**
3. Find "Notifications"
4. Select **Allow** or **Allow all the time**

## Step 3: Verify Notification Channels

The app creates these notification channels automatically:

```
📱 Android:
- Study Reminders (High Priority)
- Streak Milestones (High Priority)

🍎 iOS:
- Automatically configured with alert + sound + badge
```

**Check if channels exist:**

1. Android: Settings → Apps → Nexa Smart AI → Notifications
   - You should see "Study Reminders" and "Streak Milestones" channels

2. iOS: Settings → Notifications → Nexa Smart AI
   - Should show notification options

## Step 4: Test Notifications

### Option A: Use Debug Screen

```dart
// Add to your main.dart or navigation
import 'screens/notification_debug_screen.dart';

// Navigate to it:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => NotificationDebugScreen(),
  ),
);
```

This screen lets you:

- ✅ Check permission status
- ✅ Request permissions
- ✅ Send test notification
- ✅ Record test study activity
- ✅ Test streak notifications

### Option B: Manual Testing

In your app, add this test button anywhere:

```dart
ElevatedButton(
  onPressed: () async {
    final testService = NotificationTestService();
    await testService.sendTestNotification(
      title: '🧪 Test',
      body: 'Notifications working!',
    );
  },
  child: Text('Test Notification'),
)
```

## Troubleshooting

### ❌ Problem: "No notifications tab in Settings"

**Causes:**

1. Permission not requested yet
2. Device hasn't created notification channels
3. Permission already permanently denied

**Solutions:**

1. **Force restart app** (close completely and reopen)
2. **In app, tap "Request Permission"** (if dialog appears)
3. **Grant permission** in device Settings
4. **Reinstall app** if all else fails

### ❌ Problem: "Notifications not appearing"

**Check list:**

1. **Permission granted?**

   ```dart
   final status = await Permission.notification.status;
   print('Permission: ${status.isGranted}');
   ```

2. **Do Not Disturb enabled?**
   - Check device is not in DND mode
   - Nexa Smart AI notifications may be muted

3. **Notification channels created?**
   - Check: Settings → Apps → Nexa Smart AI → Notifications
   - Should show at least 2 channels

4. **Device battery/performance?**
   - If battery saver is on, notifications may be delayed
   - Try disabling battery saver

5. **App has foreground permission?**
   ```dart
   final foreground = await Permission.notification.isDenied;
   print('Can send foreground: ${!foreground}');
   ```

### ❌ Problem: "Permission always denied"

**If you see: "Permission permanently denied - Go to Settings"**

1. Open **Settings** → **Apps** → **Nexa Smart AI**
2. Look for **Permissions** section
3. Find **Notifications**
4. Tap it and select **Allow** (not "Ask every time")
5. Close settings
6. Re-open app
7. Test again

### ❌ Problem: "Getting permission dialog but can't tap"

**Possible causes:**

- Dialog is behind system UI
- Very old Android version

**Solutions:**

1. Restart device
2. Clear app cache: Settings → Apps → Nexa Smart AI → Storage → Clear Cache
3. Uninstall and reinstall app

## How the System Works

```
┌─────────────────────────────────────────┐
│  User sends message in Study Bot chat   │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│  recordStudyActivity() called            │
│  - Streak logic executed                 │
│  - Data saved to SharedPreferences       │
└──────────────┬──────────────────────────┘
               ↓
        ┌──────────────┐
        │ Streak ≥ 3?  │
        └──────┬───────┘
         Yes ↙      ↖ No
        ↓           ↓
    Notify      Continue
     3-Day     (no notification)
    Streak
        ↓
  notifyStreakMilestone(3)
        ↓
  Check if already notified
        ↓
    Show notification 🎉
```

## Debug Logging

Check logcat/console for debug messages:

```
[StudyNotification] ✅ Study notification service initialized
[StudyNotification] Notification permission: PermissionStatus.granted
[StudyNotification] ✅ Notification permission granted
[StudyNotification] ✅ Notification channels created
[StudyNotification] 📅 Daily reminder scheduled for 2026-01-29 09:00:00
[StudyNotification] 🎉 Milestone notification sent: 3 days
```

If you see ❌ errors, it usually means:

- Permission not granted
- Notification channels not created
- Device restrictions

## Quick Fixes (Try These)

### 1. Clear App Cache

```
Settings → Apps → Nexa Smart AI → Storage → Clear Cache
```

### 2. Reinstall App

```
adb uninstall com.myai
flutter run
```

### 3. Force Re-initialize Services

```dart
// In main.dart, before runApp()
await StudyNotificationService().initialize();
```

### 4. Check Device Settings

**Make sure:**

- Notifications app setting is **ON** (not off/muted)
- Battery saver is **OFF**
- Do Not Disturb is **OFF**
- Device isn't in Bedtime mode

## Expected Behavior

### When Permission is Granted ✅

1. **First time app launches:**
   - Android: May show dialog to grant notification permission
   - iOS: Notification settings created automatically

2. **When user sends a message:**
   - Study activity is recorded
   - Streak counter increments (if ≥24 hours since last study)
   - No immediate notification (only milestones or daily reminders)

3. **On 3rd day milestone:**
   - 🎉 Notification: "🔥 3-day streak! You're building a powerful study habit."

4. **On 7th day milestone:**
   - 🚀 Notification: "🚀 7 DAYS STRAIGHT! You're officially unstoppable."

5. **Daily at 9 AM:**
   - If no study in last 24 hours:
   - 📢 Notification: "Your study bot misses you ✨ Let's do a quick learning session today."

### When Permission is Denied ❌

- No notifications sent
- No error thrown (silently fails)
- Streaks still tracked locally (just no celebrations)

## For Developers

### Test Notification System

```dart
import 'services/notification_test_service.dart';

final testService = NotificationTestService();

// Check permission
final status = await testService.checkNotificationPermissionStatus();
print(status); // {isDenied, isGranted, isPermanentlyDenied, ...}

// Send test notification
await testService.sendTestNotification(
  title: 'Test',
  body: 'This is a test',
);

// Test study activity recording
final activityResult = await testService.testStudyActivityFlow();
print(activityResult); // {success, streak, stats, ...}

// Get system status
final sysStatus = await testService.getNotificationSystemStatus();
print(sysStatus); // {permission, studyStats, nextMilestones, ...}
```

### Monitor Notifications

Add to main.dart:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await StudyNotificationService().initialize();

  // Schedule daily reminder
  await StudyNotificationService().scheduleDailyReminder();

  runApp(MyApp());
}
```

## Still Not Working?

1. **Check logs for errors:**
   - Run: `flutter logs`
   - Look for `[StudyNotification]` lines
   - Post any error messages here

2. **Verify manifest:**

   ```bash
   grep POST_NOTIFICATIONS android/app/src/main/AndroidManifest.xml
   ```

   Should show:

   ```
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   ```

3. **Test on different device/emulator:**
   - If works on one device, likely a device-specific setting
   - Check device manufacturer's notification settings

4. **Update plugins:**
   ```bash
   flutter pub get
   flutter clean
   flutter run
   ```

## Android 12 & Below

Notifications work automatically on Android 12 and below.
Only Android 13+ requires runtime permission request.

## iOS Notes

iOS automatically handles notification permissions.
When first opened, may show: "Allow notifications?"

- Tap "Allow" to enable
- Tap "Don't Allow" to disable

## Need Help?

1. Check the **Notification Debug Screen** in the app
2. Look at console logs: `flutter logs | grep StudyNotification`
3. Check device Settings → Apps → Nexa Smart AI → Notifications
4. Try reinstalling the app
