# Premium Internet Connection Error Notification System

## Overview

A premium, beautifully designed error notification system that alerts users when their internet connection is faulty while sending messages. The system respects your app's theme and supports all language modes (English, Spanish, French, Hindi, Arabic).

## Features

✨ **Premium Design**

- Modern gradient backgrounds that match your app theme
- Smooth slide-in and fade animations
- Dynamic color-coded error types
- Clean, professional UI with glassmorphism effects

🌐 **Multi-Language Support**

- Automatic translations for all 5 supported languages
- Localized error messages
- Language-aware localization via `AppLocalizations`

🎨 **Theme Integration**

- Seamless integration with your existing AppTheme
- Dark mode optimized
- Color-coded errors for quick understanding

🔄 **Smart Connectivity Monitoring**

- Real-time network connection detection
- Configurable polling interval
- Stream-based updates for reactive UI

## Components

### 1. NetworkConnectivityService (`network_connectivity_service.dart`)

Monitors internet connectivity in real-time.

**Key Methods:**

- `initialize()` - Start monitoring connectivity
- `checkConnectivity()` - Manual connectivity check
- `dispose()` - Cleanup resources

**Properties:**

- `isConnected` - Current connection status
- `connectionStatus` - Stream of connection status changes

**Usage:**

```dart
final connectivity = NetworkConnectivityService();
await connectivity.initialize();

// Listen to changes
connectivity.connectionStatus.listen((isConnected) {
  if (!isConnected) {
    print('No internet connection');
  }
});

// Manual check
bool hasInternet = await connectivity.checkConnectivity();
```

### 2. PremiumErrorNotification Widget (`premium_error_notification.dart`)

Beautiful error notification UI component.

**Error Types:**

- `network` - Red theme, Wi-Fi icon (No internet)
- `timeout` - Orange theme, Clock icon (Request timeout)
- `server_error` - Purple theme, Cloud off icon (Server error)
- `generic` - Indigo theme, Error icon (Generic errors)

**Parameters:**

```dart
PremiumErrorNotification(
  errorType: 'network',           // Required: error type
  customMessage: 'Custom error',  // Optional: override message
  onRetry: () => retryAction(),  // Optional: retry callback
  displayDuration: Duration(seconds: 6), // Optional: auto-hide duration
)
```

**Helper Function:**

```dart
await showPremiumError(
  context,
  errorType: 'network',
  customMessage: 'Please check your connection',
  onRetry: () => _sendMessage(message),
);
```

## Implementation

### Step 1: Basic Setup

```dart
import 'package:flutter/material.dart';
import 'services/network_connectivity_service.dart';
import 'widgets/premium_error_notification.dart';
import 'dart:io'; // For exception handling

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
    _initializeConnectivity();
  }

  Future<void> _initializeConnectivity() async {
    await _connectivity.initialize();
  }

  @override
  void dispose() {
    _connectivity.dispose();
    super.dispose();
  }
}
```

### Step 2: Send Message with Error Handling

```dart
Future<void> _sendMessage(String message) async {
  // Check internet before sending
  if (!_connectivity.isConnected) {
    await showPremiumError(
      context,
      errorType: 'network',
      onRetry: () => _sendMessage(message),
    );
    return;
  }

  try {
    final response = await ApiService.send('chat',
      {'message': message}
    );
    // Handle success
  } on TimeoutException catch (_) {
    await showPremiumError(
      context,
      errorType: 'timeout',
      onRetry: () => _sendMessage(message),
    );
  } on SocketException catch (_) {
    await showPremiumError(
      context,
      errorType: 'network',
      onRetry: () => _sendMessage(message),
    );
  } catch (e) {
    String errorType = 'generic';
    if (e.toString().contains('500')) {
      errorType = 'server_error';
    }

    await showPremiumError(
      context,
      errorType: errorType,
      onRetry: () => _sendMessage(message),
    );
  }
}
```

### Step 3: Add Error Messages Localization

Error messages are already added to all locale files:

- `assets/locales/en.json`
- `assets/locales/es.json`
- `assets/locales/fr.json`
- `assets/locales/hi.json`
- `assets/locales/ar.json`

Access in code:

```dart
final title = AppLocalizations.of(context).t('error.network.title');
final message = AppLocalizations.of(context).t('error.network.message');
```

## Localization Keys

### English (en)

```json
{
  "error": {
    "network": {
      "title": "No Internet Connection",
      "message": "Please check your Wi-Fi or mobile data and try again"
    },
    "timeout": {
      "title": "Request Timed Out",
      "message": "The request is taking too long. Please try again"
    },
    "server": {
      "title": "Server Error",
      "message": "Our AI service is temporarily unavailable. Please try again"
    },
    "generic": {
      "title": "Something Went Wrong",
      "message": "An unexpected error occurred. Please try again"
    },
    "retryButton": "Try Again"
  }
}
```

### Spanish (es)

```json
{
  "error": {
    "network": {
      "title": "Sin conexión a Internet",
      "message": "Por favor, verifica tu Wi-Fi o datos móviles e intenta de nuevo"
    },
    "timeout": {
      "title": "Tiempo de espera agotado",
      "message": "La solicitud está demorando demasiado. Por favor, intenta de nuevo"
    },
    "server": {
      "title": "Error del servidor",
      "message": "Nuestro servicio de IA no está disponible temporalmente. Por favor, intenta de nuevo"
    },
    "generic": {
      "title": "Algo salió mal",
      "message": "Ocurrió un error inesperado. Por favor, intenta de nuevo"
    },
    "retryButton": "Intentar de nuevo"
  }
}
```

### French (fr)

```json
{
  "error": {
    "network": {
      "title": "Pas de connexion Internet",
      "message": "Veuillez vérifier votre Wi-Fi ou vos données mobiles et réessayer"
    },
    "timeout": {
      "title": "Délai d'attente dépassé",
      "message": "La demande prend trop de temps. Veuillez réessayer"
    },
    "server": {
      "title": "Erreur du serveur",
      "message": "Notre service IA n'est temporairement pas disponible. Veuillez réessayer"
    },
    "generic": {
      "title": "Un problème est survenu",
      "message": "Une erreur inattendue s'est produite. Veuillez réessayer"
    },
    "retryButton": "Réessayer"
  }
}
```

### Hindi (hi)

```json
{
  "error": {
    "network": {
      "title": "इंटरनेट कनेक्शन नहीं",
      "message": "कृपया अपने Wi-Fi या मोबाइल डेटा की जांच करें और पुनः प्रयास करें"
    },
    "timeout": {
      "title": "अनुरोध का समय समाप्त हो गया",
      "message": "अनुरोध में बहुत लंबा समय लग रहा है। कृपया दोबारा प्रयास करें"
    },
    "server": {
      "title": "सर्वर त्रुटि",
      "message": "हमारी AI सेवा अस्थायी रूप से उपलब्ध नहीं है। कृपया पुनः प्रयास करें"
    },
    "generic": {
      "title": "कुछ गलत हो गया",
      "message": "एक अप्रत्याशित त्रुटि हुई। कृपया दोबारा प्रयास करें"
    },
    "retryButton": "दोबारा प्रयास करें"
  }
}
```

### Arabic (ar)

```json
{
  "error": {
    "network": {
      "title": "لا توجد اتصال بالإنترنت",
      "message": "يرجى التحقق من شبكة Wi-Fi أو بيانات الهاتف المحمول والمحاولة مرة أخرى"
    },
    "timeout": {
      "title": "انتهاء وقت الطلب",
      "message": "يستغرق الطلب وقتاً طويلاً جداً. يرجى المحاولة مرة أخرى"
    },
    "server": {
      "title": "خطأ في الخادم",
      "message": "خدمة الذكاء الاصطناعي غير متاحة مؤقتاً. يرجى المحاولة مرة أخرى"
    },
    "generic": {
      "title": "حدث خطأ ما",
      "message": "حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى"
    },
    "retryButton": "حاول مرة أخرى"
  }
}
```

## Advanced Usage

### Custom Messages

```dart
await showPremiumError(
  context,
  errorType: 'network',
  customMessage: 'Custom error message that overrides default',
  onRetry: () => _sendMessage(message),
);
```

### Display Duration Control

```dart
await showPremiumError(
  context,
  errorType: 'timeout',
  displayDuration: Duration(seconds: 10), // Show for 10 seconds
  onRetry: () => retryAction(),
);
```

### Without Retry Button

```dart
// For non-critical errors, you can omit the retry callback
await showPremiumError(
  context,
  errorType: 'timeout',
  // Auto-hides after displayDuration
);
```

### Listening to Connection Status

```dart
StreamSubscription<bool> sub =
    _connectivity.connectionStatus.listen((isConnected) {
  if (isConnected) {
    print('✅ Connection restored');
    // Maybe retry failed operations
  } else {
    print('❌ Connection lost');
    // Disable send button, show warning banner, etc.
  }
});

// Don't forget to cancel
sub.cancel();
```

## Theme Integration

The error notifications use AppTheme colors:

| Error Type   | Primary Color       | Theme                                       |
| ------------ | ------------------- | ------------------------------------------- |
| network      | #DC2626 (Red)       | Dark red background with red accent         |
| timeout      | #CA A006 (Orange)   | Dark orange background with yellow accent   |
| server_error | #AB B3D9FF (Purple) | Dark purple background with lavender accent |
| generic      | #818CF8 (Indigo)    | Dark indigo background with indigo accent   |

All colors respect the dark theme and include:

- Gradient backgrounds
- Semi-transparent overlays
- Glowing shadows
- High contrast text

## Best Practices

1. **Always Check Before Sending**

   ```dart
   if (!_connectivity.isConnected) {
     showPremiumError(...);
     return;
   }
   ```

2. **Provide Retry Options**

   ```dart
   onRetry: () => _sendMessage(message) // Let user retry
   ```

3. **Specific Error Types**

   ```dart
   try {
     // API call
   } on TimeoutException {
     // Use 'timeout' error type
   } on SocketException {
     // Use 'network' error type
   }
   ```

4. **Clean Up Resources**

   ```dart
   @override
   void dispose() {
     _connectivity.dispose();
     super.dispose();
   }
   ```

5. **Test Connection Manually**
   ```dart
   bool hasInternet = await _connectivity.checkConnectivity();
   if (!hasInternet) {
     print('No internet');
   }
   ```

## File Structure

```
lib/
├── services/
│   └── network_connectivity_service.dart  # Connectivity monitoring
├── widgets/
│   └── premium_error_notification.dart    # Error UI component
├── examples/
│   └── chat_integration_example.dart      # Implementation example
└── assets/
    └── locales/
        ├── en.json  # Error messages for all languages
        ├── es.json
        ├── fr.json
        ├── hi.json
        └── ar.json
```

## Troubleshooting

### Error notification not showing?

1. Ensure `showPremiumError()` is called with correct context
2. Verify the navigation stack has a MaterialApp
3. Check that localization keys exist in all locale files

### Connectivity service not detecting changes?

1. Call `initialize()` in `initState()`
2. Ensure networking permissions are granted
3. Check that `google.com` is accessible in your region

### Messages still sent without network?

1. Check `_connectivity.isConnected` before sending
2. Network status might be cached; force a manual check:
   ```dart
   bool hasInternet = await _connectivity.checkConnectivity();
   ```

### Localization not working?

1. Verify `AppLocalizations.of(context)` is available
2. Check error keys in locale JSON files
3. Ensure locale files are in `pubspec.yaml` assets

## Performance Considerations

- **Connectivity checks**: Runs every 5 seconds (configurable)
- **Stream-based**: Uses broadcast streams for efficient updates
- **Animations**: 500ms duration with smooth curves
- **Memory**: Minimal overhead, properly disposed resources

## Security Notes

- Uses public DNS (google.com) for connectivity checks
- No sensitive data transmitted
- Requests timeout after 5 seconds
- Socket timeouts properly handled

## Future Enhancements

Potential improvements you could add:

- Retry with exponential backoff
- Offline queue for messages
- Bandwidth detection
- Automatic reconnection
- Analytics tracking
- Custom error handlers

---

**Created:** February 2026  
**App:** Nexa Smart AI  
**Languages Supported:** English, Spanish, French, Hindi, Arabic
