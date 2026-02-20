# Voice Input Dialog Localization - Quick Reference Card

## 📍 TL;DR - Key Facts

| Item                      | Answer                                                   |
| ------------------------- | -------------------------------------------------------- |
| **Localization Class**    | `AppLocalizations` (lib/utils/app_localizations.dart)    |
| **How to Use**            | `AppLocalizations.of(context).t('key.path')`             |
| **File Format**           | JSON with dot notation keys (assets/locales/{lang}.json) |
| **Supported Languages**   | en, es, fr, ar, hi                                       |
| **Active Languages**      | English (en) & Spanish (es) with full translations       |
| **Key Pattern**           | voiceInput.dialogTitle, voiceInput.vadListening, etc.    |
| **Fallback**              | Returns key itself if translation missing (no crash)     |
| **Pluralization**         | Not supported (no special syntax in this implementation) |
| **Variable Substitution** | Use `.replaceAll('{var}', value)` after .t()             |

---

## 🎯 Voice Input Hardcoded Strings to Replace

```
1. Line ~300: "Voice Input"              → voiceInput.dialogTitle
2. Line ~308: "Cancel"                   → voiceInput.cancelButton
3. Line ~284: "Waiting for speech..."    → voiceInput.vadWaiting
4. Line ~285: "Listening..."             → voiceInput.vadListening
5. Line ~286: "Processing pause..."      → voiceInput.vadPaused
6. Line ~287: "Finalizing..."            → voiceInput.vadFinalizing
7. Line ~371: "Initializing voice input" → voiceInput.initializing
8. Any other buttons/messages            → voiceInput.* pattern
```

---

## 📋 Complete JSON Keys for Voice Input

### English (assets/locales/en.json)

```json
"voiceInput": {
  "dialogTitle": "Voice Input",
  "cancelButton": "Cancel",
  "stopButton": "Stop Listening",
  "submitButton": "Submit",
  "vadWaiting": "Waiting for speech...",
  "vadListening": "Listening...",
  "vadPaused": "Processing pause...",
  "vadFinalizing": "Finalizing...",
  "initializing": "Initializing voice input...",
  "errorMessage": "An error occurred during voice input."
}
```

### Spanish (assets/locales/es.json)

```json
"voiceInput": {
  "dialogTitle": "Entrada de Voz",
  "cancelButton": "Cancelar",
  "stopButton": "Dejar de Escuchar",
  "submitButton": "Enviar",
  "vadWaiting": "Esperando voz...",
  "vadListening": "Escuchando...",
  "vadPaused": "Procesando pausa...",
  "vadFinalizing": "Finalizando...",
  "initializing": "Inicializando entrada de voz...",
  "errorMessage": "Ocurrió un error durante la entrada de voz."
}
```

---

## 🔧 Code Changes Required

### 1️⃣ Add Import (at top of file)

```dart
import '../utils/app_localizations.dart';
```

### 2️⃣ Update \_getVADStateText() Method

```dart
// OLD
String _getVADStateText() {
  switch (_vadState) {
    case VADState.silent: return 'Waiting for speech...';
    case VADState.speaking: return 'Listening...';
    // ...
  }
}

// NEW
String _getVADStateText(BuildContext context) {
  final loc = AppLocalizations.of(context);
  switch (_vadState) {
    case VADState.silent: return loc.t('voiceInput.vadWaiting');
    case VADState.speaking: return loc.t('voiceInput.vadListening');
    // ...
  }
}
```

### 3️⃣ Update Dialog Header Title

```dart
// OLD
Text('Voice Input', ...)

// NEW
Text(AppLocalizations.of(context).t('voiceInput.dialogTitle'), ...)
```

### 4️⃣ Update Action Buttons

```dart
// OLD
TextButton(child: Text('Cancel'), ...)

// NEW
TextButton(
  child: Text(AppLocalizations.of(context).t('voiceInput.cancelButton')),
  ...
)
```

### 5️⃣ Update Loading State

```dart
// OLD
Text('Initializing voice input...', ...)

// NEW
Text(AppLocalizations.of(context).t('voiceInput.initializing'), ...)
```

---

## 📁 File Locations

```
Project Root
├── assets/locales/
│   ├── en.json          ← Add voiceInput section here
│   └── es.json          ← Add voiceInput section here
├── lib/
│   ├── utils/
│   │   ├── app_localizations.dart       ← Main class (read-only)
│   │   └── localization_extension.dart  ← BuildContext extension
│   └── widgets/
│       └── streaming_voice_input_dialog.dart  ← Update this file
└── pubspec.yaml         ← Already has flutter_localizations dependency
```

---

## ✨ Common Usage Patterns

### In State Build Method:

```dart
Widget build(BuildContext context) {
  final loc = AppLocalizations.of(context);
  return Text(loc.t('voiceInput.dialogTitle'));
}
```

### In Dialog Builder:

```dart
showDialog(
  context: context,
  builder: (context) {
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(loc.t('voiceInput.dialogTitle')),
      actions: [
        TextButton(
          child: Text(loc.t('voiceInput.cancelButton')),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  },
);
```

### In Helper Method (with BuildContext param):

```dart
String getMessage(BuildContext context) {
  return AppLocalizations.of(context).t('voiceInput.initializing');
}
```

### With String Substitution:

```dart
Text(
  AppLocalizations.of(context)
    .t('messages.greeting')
    .replaceAll('{name}', userName)
)
```

---

## ✅ Validation Checklist

- [ ] Added voiceInput section to assets/locales/en.json
- [ ] Added voiceInput section to assets/locales/es.json
- [ ] Imported AppLocalizations in streaming_voice_input_dialog.dart
- [ ] Updated \_getVADStateText() to accept BuildContext parameter
- [ ] Updated all dialog title Text widgets to use localization
- [ ] Updated all button labels to use localization
- [ ] Updated loading state message to use localization
- [ ] Updated all calls to \_getVADStateText(context) with context parameter
- [ ] Removed all hardcoded English strings from widget
- [ ] Tested in English locale
- [ ] Tested in Spanish locale
- [ ] Verified no console errors about missing keys

---

## 🔍 How Localization Works (Simplified)

```
User Language: Spanish
    ↓
AppLocalizations.of(context).t('voiceInput.dialogTitle')
    ↓
Localizations framework detects es_ES locale
    ↓
Loads assets/locales/es.json
    ↓
Finds voiceInput.dialogTitle = "Entrada de Voz"
    ↓
Returns "Entrada de Voz" to widget
    ↓
Dialog displays Spanish title ✅
```

---

## ⚠️ Common Mistakes to Avoid

1. ❌ **Don't call `.t()` outside of a widget with BuildContext**

   ```dart
   // DON'T: This crashes - no context outside widget tree
   const String TITLE = AppLocalizations.of().t('key');

   // DO: Get it inside widget
   Text(AppLocalizations.of(context).t('key'))
   ```

2. ❌ **Don't forget to pass BuildContext to helper methods**

   ```dart
   // DON'T: _getVADStateText() returns hardcoded strings
   String _getVADStateText() { ... }

   // DO: Pass context as parameter
   String _getVADStateText(BuildContext context) { ... }
   ```

3. ❌ **Don't use different key names in en.json vs es.json**

   ```dart
   // DON'T: Key exists in English but not Spanish
   en.json: "voiceInput": { "dialogue": "..." }
   es.json: "voiceInput": { // missing "dialogue" }

   // DO: Match keys exactly
   en.json and es.json: both have same key structure
   ```

4. ❌ **Don't forget JSON syntax (commas, quotes)**

   ```json
   // DON'T: Missing comma between sections
   "app": { ... }
   "voiceInput": { ... }

   // DO: Comma between sections
   "app": { ... },
   "voiceInput": { ... }
   ```

---

## 🚀 Quick Start (3 Steps)

### Step 1: Add keys to JSON files (2 minutes)

- Open assets/locales/en.json
- Scroll to bottom, add voiceInput section
- Repeat for es.json

### Step 2: Update streaming_voice_input_dialog.dart (5 minutes)

- Add import: `import '../utils/app_localizations.dart';`
- Replace 3-4 hardcoded strings with `.t()` calls
- Update \_getVADStateText() to accept BuildContext

### Step 3: Test (2 minutes)

- Run app with English locale - check translations work
- Change system language to Spanish - verify Spanish shows
- Done! ✅

**Total Time: ~10 minutes**

---

## 📖 Reference Examples in Codebase

### Dialog with Localization (study_plan_chat_screen.dart):

```dart
showDialog(
  context: context,
  builder: (context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).t('studyBotChat.botName')),
      actions: [
        TextButton(
          child: Text(AppLocalizations.of(context).t('common.cancel')),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  },
);
```

### Reusable Keys (already in json, don't redefine):

```dart
AppLocalizations.of(context).t('common.cancel')    // Existing
AppLocalizations.of(context).t('common.ok')        // Existing
AppLocalizations.of(context).t('common.loading')   // Existing
AppLocalizations.of(context).t('common.error')     // Existing
```

---

## 🔗 Related Files for Reference

- **Main Localization Class:** lib/utils/app_localizations.dart
- **Extension Helper:** lib/utils/localization_extension.dart
- **Good Example:** lib/screens/study_plan_chat_screen.dart (~2700 uses of .t())
- **Dialog Example:** lib/screens/settings_screen.dart (~15 dialog implementations)
- **Translations:** assets/locales/{en,es}.json

---

## Summary

**What:** Add multi-language support to voice input dialog  
**How:** Use existing AppLocalizations system  
**Where:** Replace hardcoded strings with `.t('key')` calls  
**When:** Now - before releasing to Spanish-speaking users  
**Why:** Better UX, consistency with rest of app, professional appearance
