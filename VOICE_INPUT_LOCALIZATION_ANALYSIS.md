# Voice Input Dialog Localization Analysis

## 1. LOCALIZATION SYSTEM SETUP

### File Structure

```
assets/
  └── locales/
      ├── en.json      ✅ English translations (374 lines)
      ├── es.json      ✅ Spanish translations (395 lines)
      └── [fr, ar, hi] (supported but files follow same pattern)

lib/
  └── utils/
      ├── app_localizations.dart       (Main localization class)
      ├── localization_extension.dart  (BuildContext extension)
```

### Main Localization Class

**File:** `lib/utils/app_localizations.dart`

```dart
class AppLocalizations {
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  late Map<String, dynamic> _translations;
  final Locale locale;

  AppLocalizations(this.locale);

  // Gets instance from BuildContext
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  // Load translations from JSON file
  Future<void> load() async {
    final jsonString = await rootBundle.loadString(
      'assets/locales/${locale.languageCode}.json',
    );
    _translations = json.decode(jsonString);
  }

  // Usage: supports dot notation for nested keys
  String translate(String key) {
    List<String> keys = key.split('.');
    dynamic value = _translations;

    for (String k in keys) {
      if (value is Map<String, dynamic> && value.containsKey(k)) {
        value = value[k];
      } else {
        return key; // Return key if translation not found
      }
    }
    return value.toString();
  }

  // Shorthand: t() instead of translate()
  String t(String key) => translate(key);
}

// Supported languages
class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  @override
  bool isSupported(Locale locale) {
    return ['en', 'es', 'fr', 'ar', 'hi'].contains(locale.languageCode);
  }
}
```

### Localization Extension (Convenience)

**File:** `lib/utils/localization_extension.dart`

```dart
extension LocalizationExt on BuildContext {
  AppLocalizations get t => AppLocalizations.of(this);
  String tr(String key) => AppLocalizations.of(this).translate(key);
}

// Usage in UI:
// context.t.t('key.name')
// context.tr('key.name')
```

---

## 2. HOW APPLOCALIZATION IS USED IN THIS APP

### Pattern 1: Direct Usage (Most Common)

```dart
// In any widget that has access to BuildContext:
Text(
  AppLocalizations.of(context).t('chatScreen.greeting'),
  style: AppTheme.bodyLarge,
)
```

### Pattern 2: Using Extension

```dart
// Using the extension (shorter)
Text(context.tr('menu.chatOptions'))
```

### Pattern 3: In Dialogs (Most Relevant for Voice Input)

```dart
// Example from settings_screen.dart - showDialog pattern
showDialog(
  context: context,
  builder: (context) {
    return AlertDialog(
      title: Text(
        AppLocalizations.of(context).t('drawer.deleteDialogTitle'),
      ),
      content: Text(
        AppLocalizations.of(context).t('drawer.deleteDialogMessage'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            AppLocalizations.of(context).t('drawer.cancelButton'),
          ),
        ),
      ],
    );
  },
);
```

### Pattern 4: In StatefulWidget State

```dart
// From study_plan_chat_screen.dart - used in build()
Text(
  AppLocalizations.of(context).t('studyBotChat.messageHint')
    .replaceAll('{botName}', widget.botName ?? "AI"),
)
```

---

## 3. LOCALIZATION FILES STRUCTURE

### Main Localization Files

- **Primary:** `assets/locales/en.json` (English - 374 lines)
- **Secondary:** `assets/locales/es.json` (Spanish - 395 lines)
- **Supported:** French (fr), Arabic (ar), Hindi (hi) - follow same structure

### Translation Key Naming Convention

Keys use **dot notation** for nested organization:

```
category.subcategory.item
```

Examples:

- `app.name` → App name
- `nav.chat` → Navigation: Chat label
- `drawer.deleteDialogTitle` → Drawer: Delete confirmation title
- `studyBotChat.messageHint` → Study Bot Chat: Input hint text
- `errors.networkError` → Errors: Network error message

### Sample JSON Structure (en.json)

```json
{
  "app": {
    "name": "Nexa Smart AI",
    "tagline": "Your AI-powered learning companion"
  },
  "nav": {
    "home": "Home",
    "chat": "Chat",
    "settings": "Settings"
  },
  "common": {
    "cancel": "Cancel",
    "save": "Save",
    "ok": "OK",
    "loading": "Loading..."
  },
  "drawer": {
    "deleteDialogTitle": "Delete Chat?",
    "deleteDialogMessage": "Are you sure you want to delete \"{title}\"?",
    "deleteButton": "Delete",
    "cancelButton": "Cancel"
  },
  "studyBotChat": {
    "messageHint": "Message {botName}...",
    "takeQuiz": "Take Quiz",
    "saveNote": "Save Note"
  }
}
```

---

## 4. EXISTING DIALOG PATTERNS IN THE APP

### Example 1: Delete Confirmation Dialog (settings_screen.dart)

```dart
void _showDeleteConfirmation() {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: isDarkMode
            ? AppTheme.surfaceElevated
            : Color(0xFFFFFFFF),
        title: Text(
          'Delete Account',
          style: AppTheme.headlineMedium.copyWith(
            color: isDarkMode ? AppTheme.textPrimary : Color(0xFF000000),
          ),
        ),
        content: Text(
          'Are you sure? This cannot be undone.',
          style: AppTheme.bodyMedium.copyWith(
            color: isDarkMode
                ? AppTheme.textSecondary
                : Color(0xFF6B7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context).t('common.cancel'),
              style: AppTheme.labelLarge,
            ),
          ),
          ElevatedButton(
            onPressed: () => _deleteAccount(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(
              AppLocalizations.of(context).t('common.delete'),
              style: AppTheme.labelLarge.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    },
  );
}
```

### Example 2: Coming Soon Dialog (settings_screen.dart)

```dart
void _showComingSoonDialog(String feature) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.rocket_launch, color: AppTheme.primaryBlue),
            SizedBox(width: AppTheme.spaceSm),
            Text(
              'Coming Soon',  // ❌ Should be localized
              style: AppTheme.headlineMedium,
            ),
          ],
        ),
        content: Text(
          '$feature will be available in a future update. Stay tuned!',
          // ❌ Should be localized with parameter
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it'),  // ❌ Should be localized
          ),
        ],
      );
    },
  );
}
```

### Example 3: Data Management Dialog (settings_screen.dart)

```dart
void _showDataManagementDialog() {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(
          'Data & Storage',  // ❌ Should be localized
          style: AppTheme.headlineMedium,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Manage your app data',  // ❌ Should be localized
            ),
            _buildDataOption(
              'Clear Cache',  // ❌ Should be localized
              'Free up space by clearing temporary files',  // ❌
              Icons.cleaning_services,
              AppTheme.accentGradient,
              () => _clearCache(),
            ),
            _buildDataOption(
              'Clear All Data',  // ❌ Should be localized
              'Reset app to default state (Cannot be undone)',  // ❌
              Icons.delete_forever,
              [Colors.red, Colors.redAccent],
              () => _showClearDataConfirmation(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context).t('common.close'),
            ),
          ),
        ],
      );
    },
  );
}
```

---

## 5. HARDCODED STRINGS IN VOICE INPUT DIALOG

**File:** `lib/widgets/streaming_voice_input_dialog.dart`

### Strings That Need Localization

```dart
// Line 300: Header Title
'Voice Input'  // ❌ MUST LOCALIZE

// Line 308: Close button tooltip
'Cancel'  // ❌ Should use common.cancel

// Line 353: Error icon + message display
_errorMessage  // ✅ Already localized (from backend)

// Line 363: VAD State Indicators (Line 284-295)
'Waiting for speech...'        // ❌ MUST LOCALIZE
'Listening...'                 // ❌ MUST LOCALIZE
'Processing pause...'          // ❌ MUST LOCALIZE
'Finalizing...'                // ❌ MUST LOCALIZE

// Line 371: Loading state
'Initializing voice input...'  // ❌ MUST LOCALIZE

// Line 397: Action buttons
'Cancel'  // ❌ Should use common.cancel
```

### Complete List of Hardcoded Strings in streaming_voice_input_dialog.dart:

1. **"Voice Input"** - Dialog title
2. **"Cancel"** - Close/cancel button
3. **"Waiting for speech..."** - VAD silent state
4. **"Listening..."** - VAD speaking state
5. **"Processing pause..."** - VAD paused state
6. **"Finalizing..."** - VAD finalizing state
7. **"Initializing voice input..."** - Loading state
8. And any button labels in the rest of the dialog

---

## 6. ADDING VOICE INPUT TRANSLATIONS TO JSON

### Add to `assets/locales/en.json`:

```json
"voiceInput": {
  "dialogTitle": "Voice Input",
  "cancel": "Cancel",
  "stop": "Stop Listening",
  "submit": "Submit",
  "vadWaiting": "Waiting for speech...",
  "vadListening": "Listening...",
  "vadPaused": "Processing pause...",
  "vadFinalizing": "Finalizing...",
  "initializing": "Initializing voice input...",
  "noMicPermission": "Microphone permission denied",
  "error": "Voice input error",
  "transcript": "You said:",
  "partial": "Transcribing...",
  "retryLabel": "Retry",
  "submitLabel": "Use this text"
}
```

### Add to `assets/locales/es.json`:

```json
"voiceInput": {
  "dialogTitle": "Entrada de Voz",
  "cancel": "Cancelar",
  "stop": "Dejar de Escuchar",
  "submit": "Enviar",
  "vadWaiting": "Esperando voz...",
  "vadListening": "Escuchando...",
  "vadPaused": "Procesando pausa...",
  "vadFinalizing": "Finalizando...",
  "initializing": "Inicializando entrada de voz...",
  "noMicPermission": "Permiso de micrófono denegado",
  "error": "Error de entrada de voz",
  "transcript": "Dijiste:",
  "partial": "Transcribiendo...",
  "retryLabel": "Reintentar",
  "submitLabel": "Usar este texto"
}
```

---

## 7. IMPLEMENTATION STEPS FOR VOICE INPUT DIALOG

### Step 1: Add Keys to en.json

Add the `voiceInput` section to the existing `assets/locales/en.json`

### Step 2: Add Keys to es.json

Add the `voiceInput` section to the existing `assets/locales/es.json`

### Step 3: Update Voice Input Dialog

Replace hardcoded strings in `lib/widgets/streaming_voice_input_dialog.dart`:

```dart
@override
Widget build(BuildContext context) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  final localizations = AppLocalizations.of(context);

  return Dialog(
    backgroundColor: Colors.transparent,
    child: Container(
      // ... existing styling ...
      child: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  localizations.t('voiceInput.dialogTitle'),  // ✅ LOCALIZED
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!_errorMessage.isEmpty)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _onCancelPressed,
                    tooltip: localizations.t('voiceInput.cancel'),  // ✅ LOCALIZED
                  ),
              ],
            ),
            // ... rest of dialog ...
          ],
        ),
      ),
    ),
  );
}

String _getVADStateText(BuildContext context) {
  final localizations = AppLocalizations.of(context);
  switch (_vadState) {
    case VADState.silent:
      return localizations.t('voiceInput.vadWaiting');  // ✅ LOCALIZED
    case VADState.speaking:
      return localizations.t('voiceInput.vadListening');  // ✅ LOCALIZED
    case VADState.paused:
      return localizations.t('voiceInput.vadPaused');  // ✅ LOCALIZED
    case VADState.finalizing:
      return localizations.t('voiceInput.vadFinalizing');  // ✅ LOCALIZED
  }
}
```

### Step 4: Update Action Buttons

Replace button labels in the button row to use `AppLocalizations.of(context).t()`

---

## 8. COMMON PATTERNS TO FOLLOW

### In DialogBuilder:

```dart
// ✅ GOOD - Get localizations once
showDialog(
  context: context,
  builder: (context) {
    final loc = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(loc.t('voiceInput.dialogTitle')),
      content: Text(loc.t('voiceInput.initializing')),
      actions: [
        TextButton(
          child: Text(loc.t('common.cancel')),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  },
);
```

### In StatefulWidget Methods:

```dart
// ✅ GOOD - Use BuildContext parameter
String _getVADStateText(BuildContext context) {
  final loc = AppLocalizations.of(context);
  switch (_vadState) {
    case VADState.silent:
      return loc.t('voiceInput.vadWaiting');
    // ...
  }
}

// Called from build():
Text(_getVADStateText(context))
```

### In Constants (Don't do this!):

```dart
// ❌ BAD - Can't access BuildContext in const string
const String DIALOG_TITLE = 'Voice Input';

// ✅ GOOD - Define as method
String getDialogTitle(BuildContext context) {
  return AppLocalizations.of(context).t('voiceInput.dialogTitle');
}
```

---

## 9. PUBSPEC.yaml LOCALIZATION SETUP

The app uses standard Flutter localization with:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: 0.20.2
```

**Note:** The app uses a custom localization system (not the official intl package syntax), so it doesn't require `generate: true` in pubspec.yaml. The JSON files are loaded manually at runtime.

---

## 10. TESTING LOCALIZATION

### To Test English:

1. Run app normally
2. Voice input strings should appear in English

### To Test Spanish:

1. Change system language to Spanish
2. Voice input strings should appear in Spanish

### To Verify Implementation:

```bash
// Check that keys exist in both en.json and es.json
$ grep -r "voiceInput" assets/locales/

// Verify no hardcoded strings remain in widget
$ grep -n "Listening\|Finalizing\|Waiting for speech" lib/widgets/streaming_voice_input_dialog.dart
```

---

## SUMMARY

| Aspect                  | Details                                                          |
| ----------------------- | ---------------------------------------------------------------- |
| **Main Class**          | `AppLocalizations` in `lib/utils/app_localizations.dart`         |
| **Usage**               | `AppLocalizations.of(context).t('key.name')`                     |
| **Extension**           | `context.tr('key.name')` (shorter form)                          |
| **Supported Languages** | English (en), Spanish (es), French (fr), Arabic (ar), Hindi (hi) |
| **File Format**         | JSON with dot-notation keys                                      |
| **Files to Update**     | `assets/locales/en.json`, `assets/locales/es.json`, etc.         |
| **Voice Input Keys**    | New section: `voiceInput.*`                                      |
| **Pattern in Dialogs**  | Get `AppLocalizations.of(context)` in builder, use `.t()` method |
| **Fallback**            | If key not found, returns the key itself (not a blank string)    |
