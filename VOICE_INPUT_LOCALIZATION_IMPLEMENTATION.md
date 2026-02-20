# Voice Input Dialog - Localization Integration Guide

## Quick Reference: What to Change

### Files to Modify:

1. `assets/locales/en.json` - Add English translations
2. `assets/locales/es.json` - Add Spanish translations
3. `lib/widgets/streaming_voice_input_dialog.dart` - Replace hardcoded strings

---

## STEP 1: Add Translation Keys to en.json

**Location:** `assets/locales/en.json`

Find the closing `}` of the file and add before it:

```json
  "voiceInput": {
    "dialogTitle": "Voice Input",
    "headerTitle": "Voice Input",
    "cancelButton": "Cancel",
    "stopButton": "Stop Listening",
    "submitButton": "Submit",
    "retryButton": "Retry",
    "closeButton": "Close",
    "vadWaiting": "Waiting for speech...",
    "vadListening": "Listening...",
    "vadPaused": "Processing pause...",
    "vadFinalizing": "Finalizing...",
    "initializing": "Initializing voice input...",
    "errorTitle": "Voice Input Error",
    "micPermissionDenied": "Microphone permission denied",
    "errorMessage": "An error occurred during voice input. Please try again.",
    "transcriptLabel": "You said:",
    "partialTranscript": "Transcribing...",
    "noSpeech": "No speech detected. Please try again.",
    "processingLabel": "Processing your voice...",
    "finalizingLabel": "Finalizing transcript..."
  }
```

---

## STEP 2: Add Translation Keys to es.json

**Location:** `assets/locales/es.json`

Find the closing `}` of the file and add before it:

```json
  "voiceInput": {
    "dialogTitle": "Entrada de Voz",
    "headerTitle": "Entrada de Voz",
    "cancelButton": "Cancelar",
    "stopButton": "Dejar de Escuchar",
    "submitButton": "Enviar",
    "retryButton": "Reintentar",
    "closeButton": "Cerrar",
    "vadWaiting": "Esperando voz...",
    "vadListening": "Escuchando...",
    "vadPaused": "Procesando pausa...",
    "vadFinalizing": "Finalizando...",
    "initializing": "Inicializando entrada de voz...",
    "errorTitle": "Error de Entrada de Voz",
    "micPermissionDenied": "Permiso de micrófono denegado",
    "errorMessage": "Ocurrió un error durante la entrada de voz. Por favor, intenta de nuevo.",
    "transcriptLabel": "Dijiste:",
    "partialTranscript": "Transcribiendo...",
    "noSpeech": "No se detectó voz. Por favor, intenta de nuevo.",
    "processingLabel": "Procesando tu voz...",
    "finalizingLabel": "Finalizando transcripción..."
  }
```

---

## STEP 3: Update streaming_voice_input_dialog.dart

### Changes to \_getVADStateText() method

**OLD CODE (Lines 284-295):**

```dart
String _getVADStateText() {
  switch (_vadState) {
    case VADState.silent:
      return 'Waiting for speech...';
    case VADState.speaking:
      return 'Listening...';
    case VADState.paused:
      return 'Processing pause...';
    case VADState.finalizing:
      return 'Finalizing...';
  }
}
```

**NEW CODE:**

```dart
String _getVADStateText(BuildContext context) {
  final localizations = AppLocalizations.of(context);
  switch (_vadState) {
    case VADState.silent:
      return localizations.t('voiceInput.vadWaiting');
    case VADState.speaking:
      return localizations.t('voiceInput.vadListening');
    case VADState.paused:
      return localizations.t('voiceInput.vadPaused');
    case VADState.finalizing:
      return localizations.t('voiceInput.vadFinalizing');
  }
}
```

---

### Changes to build() method

**OLD CODE (Lines 300-308):**

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(
      'Voice Input',  // ❌ HARDCODED
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    ),
    if (!_errorMessage.isEmpty)
      IconButton(
        icon: const Icon(Icons.close),
        onPressed: _onCancelPressed,
        tooltip: 'Cancel',  // ❌ HARDCODED
      ),
  ],
),
```

**NEW CODE:**

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(
      AppLocalizations.of(context).t('voiceInput.headerTitle'),  // ✅ LOCALIZED
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    ),
    if (!_errorMessage.isEmpty)
      IconButton(
        icon: const Icon(Icons.close),
        onPressed: _onCancelPressed,
        tooltip: AppLocalizations.of(context).t('voiceInput.cancelButton'),  // ✅ LOCALIZED
      ),
  ],
),
```

---

### Changes to Loading State Section

**OLD CODE (Lines 363-371):**

```dart
if (!_isInitialized && _errorMessage.isEmpty)
  Column(
    children: [
      const SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      const SizedBox(height: 12),
      Text(
        'Initializing voice input...',  // ❌ HARDCODED
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
    ],
  ),
```

**NEW CODE:**

```dart
if (!_isInitialized && _errorMessage.isEmpty)
  Column(
    children: [
      const SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      const SizedBox(height: 12),
      Text(
        AppLocalizations.of(context).t('voiceInput.initializing'),  // ✅ LOCALIZED
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
    ],
  ),
```

---

### Changes to Action Buttons Section

**OLD CODE (Lines 397-410):**

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    // Cancel button
    TextButton(
      onPressed: _onCancelPressed,
      child: const Text('Cancel'),  // ❌ HARDCODED
    ),
    // More buttons follow...
```

**NEW CODE:**

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    // Cancel button
    TextButton(
      onPressed: _onCancelPressed,
      child: Text(
        AppLocalizations.of(context).t('voiceInput.cancelButton'),  // ✅ LOCALIZED
      ),
    ),
    // More buttons follow...
```

---

### Changes to \_buildVADIndicator() method

**Find where it displays the VAD state text and update it:**

**OLD CODE:**

```dart
Text(
  _getVADStateText(),  // ❌ Not passing context
  style: TextStyle(
    color: _getVADStateColor(),
    fontWeight: FontWeight.w500,
  ),
),
```

**NEW CODE:**

```dart
Text(
  _getVADStateText(context),  // ✅ Pass context for localization
  style: TextStyle(
    color: _getVADStateColor(),
    fontWeight: FontWeight.w500,
  ),
),
```

---

## STEP 4: Add Import Statement

**At the top of `lib/widgets/streaming_voice_input_dialog.dart`:**

```dart
import '../utils/app_localizations.dart';
```

---

## Complete Updated Methods

### Method 1: \_getVADStateText()

```dart
/// Get localized text description for VAD state
String _getVADStateText(BuildContext context) {
  final localizations = AppLocalizations.of(context);
  switch (_vadState) {
    case VADState.silent:
      return localizations.t('voiceInput.vadWaiting');
    case VADState.speaking:
      return localizations.t('voiceInput.vadListening');
    case VADState.paused:
      return localizations.t('voiceInput.vadPaused');
    case VADState.finalizing:
      return localizations.t('voiceInput.vadFinalizing');
  }
}
```

### Method 2: Updated \_buildVADIndicator() (if it exists)

```dart
Widget _buildVADIndicator(BuildContext context) {
  return Column(
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getVADStateColor().withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _vadState == VADState.speaking ? Icons.mic : Icons.mic_none,
          color: _getVADStateColor(),
          size: 32,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        _getVADStateText(context),  // ✅ LOCALIZED
        style: TextStyle(
          color: _getVADStateColor(),
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}
```

---

## Testing the Implementation

### Test in English:

```bash
# Run app with English locale (system default or app default)
flutter run
# Voice input dialog should show localized English text
```

### Test in Spanish:

```bash
# Change system language to Spanish, or manually set locale
# Device Settings > Language > Español
flutter run
# Voice input dialog should show localized Spanish text
```

### Verify No Hardcoded Strings Remain:

```bash
# Search for hardcoded strings in voice dialog
grep -E 'Text\(|tooltip:' lib/widgets/streaming_voice_input_dialog.dart | \
  grep -v "AppLocalizations\|context\.t\|\.t(" | \
  grep -v "//"
```

---

## Fallback Behavior

If a translation key is missing, the app will:

1. Return the key itself (e.g., "voiceInput.vadWaiting")
2. Not crash or show blank UI
3. Logs nothing (current implementation)

**Recommendation:** Add all keys to both en.json and es.json to avoid this fallback.

---

## Reusable Keys Across the App

Some translation keys are already defined and can be reused:

```dart
// Instead of creating new keys, reuse these:
AppLocalizations.of(context).t('common.cancel')      // Already exists
AppLocalizations.of(context).t('common.ok')          // Already exists
AppLocalizations.of(context).t('common.loading')     // Already exists
AppLocalizations.of(context).t('common.error')       // Already exists
AppLocalizations.of(context).t('common.tryAgain')    // Already exists
```

So your voiceInput section only needs new, voice-specific strings.

---

## Summary of Changes

| File                                | Change Type                        | Lines      |
| ----------------------------------- | ---------------------------------- | ---------- |
| `en.json`                           | Add voiceInput section             | New        |
| `es.json`                           | Add voiceInput section             | New        |
| `streaming_voice_input_dialog.dart` | Import AppLocalizations            | Top        |
| `streaming_voice_input_dialog.dart` | Update \_getVADStateText()         | ~284-295   |
| `streaming_voice_input_dialog.dart` | Update build() - header            | ~300-310   |
| `streaming_voice_input_dialog.dart` | Update build() - loading           | ~363-371   |
| `streaming_voice_input_dialog.dart` | Update build() - buttons           | ~397-410   |
| `streaming_voice_input_dialog.dart` | Update \_buildVADIndicator() calls | Throughout |

**Total Changes:** ~7 locations with ~20 string replacements

---

## Common Issues & Solutions

### Issue 1: AppLocalizations import not found

**Solution:** Add to imports:

```dart
import '../utils/app_localizations.dart';
```

### Issue 2: Method signature error on \_getVADStateText()

**Problem:** Called without context in existing code
**Solution:** Update all calls to pass context:

```dart
_getVADStateText(context)  // Instead of _getVADStateText()
```

### Issue 3: JSON syntax error

**Problem:** Forgot comma between sections
**Solution:** Ensure each section (except the last) ends with a comma:

```json
  "drawer": { ... },      // ← comma here
  "voiceInput": { ... }   // ← no comma (last item)
}
```

### Issue 4: Missing translation keys in Spanish

**Solution:** Ensure every key in en.json has a matching entry in es.json

---

## Best Practices Applied

✅ **Use dot notation for keys:** voiceInput.vadWaiting
✅ **Get localizations in builder/method:** `final loc = AppLocalizations.of(context)`
✅ **Pass context to helper methods:** `_getVADStateText(context)`
✅ **Reuse common keys:** Use `common.cancel` instead of creating `voiceInput.cancel`
✅ **Test both languages:** Verify en and es work correctly
✅ **Add all 5 supported languages:** Or at least en and es
