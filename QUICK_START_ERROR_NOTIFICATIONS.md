# Quick Start Guide - Premium Error Notifications

## 30-Second Setup

### 1. Add to your chat/message screen

```dart
import 'dart:io';
import '../services/network_connectivity_service.dart';
import '../widgets/premium_error_notification.dart';

class MyChatScreen extends StatefulWidget {
  @override
  _MyChatScreenState createState() => _MyChatScreenState();
}

class _MyChatScreenState extends State<MyChatScreen> {
  final NetworkConnectivityService _connectivity = 
      NetworkConnectivityService();

  @override
  void initState() {
    super.initState();
    _connectivity.initialize();
  }

  @override
  void dispose() {
    _connectivity.dispose();
    super.dispose();
  }
}
```

### 2. Wrap your send message function

```dart
Future<void> _sendMessage(String message) async {
  // Check internet
  if (!_connectivity.isConnected) {
    await showPremiumError(
      context,
      errorType: 'network',
      onRetry: () => _sendMessage(message),
    );
    return;
  }

  try {
    await ApiService.send('chat', {'message': message});
    // Success ✅
  } on SocketException catch (_) {
    await showPremiumError(context, errorType: 'network',
        onRetry: () => _sendMessage(message));
  } on TimeoutException catch (_) {
    await showPremiumError(context, errorType: 'timeout',
        onRetry: () => _sendMessage(message));
  } catch (e) {
    await showPremiumError(context, errorType: 'generic',
        onRetry: () => _sendMessage(message));
  }
}
```

## Error Types & Themes

| Type | Icon | Color | Use When |
|------|------|-------|----------|
| `network` | 📡 | Red | No internet |
| `timeout` | ⏱️ | Orange | Request too slow |
| `server_error` | ☁️ | Purple | Server unavailable |
| `generic` | ❌ | Indigo | Unknown error |

## Features

✨ **Automatic Features:**
- Multi-language support (5 languages)
- Theme integration (matches your app)
- Smooth animations
- Auto-dismiss after 6 seconds
- Tap retry to resend
- Network monitoring in background

## Available Languages

🌍 Translations built-in for:
- 🇬🇧 English
- 🇪🇸 Spanish
- 🇫🇷 French
- 🇮🇳 Hindi
- 🇸🇦 Arabic

## Common Patterns

### Pattern 1: Simple Integration
```dart
try {
  await ApiService.send('chat', data);
} catch (e) {
  await showPremiumError(context, errorType: 'generic');
}
```

### Pattern 2: With Retry
```dart
await showPremiumError(
  context,
  errorType: 'network',
  onRetry: () => _sendMessage(message),
);
```

### Pattern 3: Custom Message
```dart
await showPremiumError(
  context,
  errorType: 'timeout',
  customMessage: 'Your custom error message',
  onRetry: () => retryFunction(),
);
```

### Pattern 4: Listen to Connection Changes
```dart
_connectivity.connectionStatus.listen((isConnected) {
  print(isConnected ? '✅ Online' : '❌ Offline');
});
```

## File Locations

```
lib/
├── services/
│   └── network_connectivity_service.dart      ← Connectivity monitoring
├── widgets/
│   └── premium_error_notification.dart        ← Error UI
├── examples/
│   └── chat_integration_example.dart          ← Full example
```

## What Each File Does

| File | Purpose |
|------|---------|
| `network_connectivity_service.dart` | Monitors internet in background |
| `premium_error_notification.dart` | Shows beautiful error notifications |
| `chat_integration_example.dart` | Complete working example |
| `PREMIUM_ERROR_NOTIFICATION_GUIDE.md` | Full documentation |

## Testing

### Test Network Error
```dart
// Disconnect Wi-Fi/data, then:
_sendMessage("Test message");
// → Red error notification appears
```

### Test Timeout
```dart
// Wait for API to timeout naturally
// → Orange notification appears
```

### Test Offline Mode
```dart
bool offline = !await _connectivity.checkConnectivity();
// Use offline state for testing
```

## Colors Used

```
Network Error (Red):
- Background: #7F1D1D (dark red)
- Border: #DC2626
- Text: White

Timeout (Orange):
- Background: #78350F (dark orange)
- Border: #CAA006
- Text: White

Server Error (Purple):
- Background: #4C1D95 (dark purple)
- Border: #AB B3D9FF
- Text: White

Generic (Indigo):
- Background: #312E81 (dark indigo)
- Border: #818CF8
- Text: White
```

## Customization

### Change Display Duration
```dart
await showPremiumError(
  context,
  errorType: 'network',
  displayDuration: Duration(seconds: 10), // Show for 10 seconds
);
```

### Override Message
```dart
await showPremiumError(
  context,
  errorType: 'network',
  customMessage: 'Check your connection and try again!',
);
```

### No Retry Button
```dart
// Omit onRetry parameter for auto-dismiss only
await showPremiumError(
  context,
  errorType: 'timeout',
);
```

## Troubleshooting

**Q: Error notification not showing?**
A: Ensure NavigatorState is available and use mounted check

**Q: Connectivity always says offline?**
A: Check your network permissions and that google.com is accessible

**Q: Localization keys not found?**
A: Verify error keys exist in all locale JSON files

**Q: Want retry functionality?**
A: Pass `onRetry: () => retryFunction()` parameter

## Next Steps

1. ✅ Copy the two new files to your lib folder
2. ✅ Add error messages to locale files (already done!)
3. ✅ Implement in your chat/message screens
4. ✅ Test with network disconnected
5. ✅ Customize colors/messages if needed

## Support

For detailed documentation, see: `PREMIUM_ERROR_NOTIFICATION_GUIDE.md`

For full working example, see: `lib/examples/chat_integration_example.dart`

---

**That's it!** You now have enterprise-grade error handling with premium design. 🚀
