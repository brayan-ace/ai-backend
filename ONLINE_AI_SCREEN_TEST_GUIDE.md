# Quick Test Guide - Online AI Screen Localization

## What's New

The Online AI Chat Screen now fully supports 5 languages with **instant language switching**. All text changes automatically when you select a different language in Settings.

## Supported Languages

- 🇬🇧 English
- 🇪🇸 Español (Spanish)
- 🇫🇷 Français (French)
- 🇸🇦 العربية (Arabic - RTL enabled)
- 🇮🇳 हिंदी (Hindi)

## How to Test

### Step 1: Open the App

Start the app normally.

### Step 2: Go to Chat Screen

Navigate to the Online AI Chat screen (main chat interface).

### Step 3: Check English Text

Verify these text appear in English:

- Greeting: "What would you like to explore?"
- Feature: "Natural Conversations"
- Feature: "Visual Understanding"
- Feature: "Multiple AI Models"

### Step 4: Switch Language

1. Open the hamburger menu (☰) on the left
2. Tap on "Settings"
3. Tap on "Language"
4. Select "Español" (Spanish)

### Step 5: Verify Spanish Translation

Go back to chat screen. You should see:

- Greeting: "¿Qué te gustaría explorar?"
- Feature: "Conversaciones Naturales"
- Feature: "Comprensión Visual"
- Feature: "Múltiples Modelos de IA"

### Step 6: Test Menu Options

1. Click the **3-dot menu** (⋮) at the top right
2. Options should appear in Spanish:
   - "Marcar Chat" (Star Chat)
   - "Renombrar Chat" (Rename Chat)
   - "Eliminar Chat" (Delete Chat)
   - "Compartir Chat" (Share Chat)

### Step 7: Test Bottom Sheet

1. Click the **+ button** (attachment)
2. Options should appear in Spanish:
   - "Cámara" (Camera)
   - "Fotos" (Photos)
   - "Búsqueda web" (Web search)
   - "Usar estilo" (Use style)
3. Click "Usar estilo" to see mode options:
   - "Normal"
   - "Detallado" (Detailed)

### Step 8: Test Arabic RTL

1. Go back to Settings → Language
2. Select "العربية" (Arabic)
3. Return to chat screen
4. Layout should flip to **right-to-left** (RTL)
5. All text appears in Arabic
6. Example: "ما الذي تود استكشافه؟" (What would you like to explore?)

### Step 9: Test French

1. Switch to "Français"
2. Verify French text appears:
   - "Que souhaitez-vous explorer?"
   - "Conversations Naturelles"
   - "Compréhension Visuelle"

### Step 10: Test Hindi

1. Switch to "हिंदी" (Hindi)
2. Verify Hindi text appears:
   - "आप क्या खोजना चाहते हैं?"
   - "प्राकृतिक बातचीत"
   - "दृश्य समझ"

### Step 11: Test Persistence

1. Close the app completely
2. Reopen the app
3. Your selected language should still be active
4. Verify text is still in the chosen language

## Text Changed

### Greeting Section

- ✅ "What would you like to explore?" → Translated to all 5 languages
- ✅ "Natural Conversations" → Translated
- ✅ "Engage in fluid, intelligent dialogue" → Translated
- ✅ "Visual Understanding" → Translated
- ✅ "Upload images and discuss them" → Translated
- ✅ "Multiple AI Models" → Translated
- ✅ "Choose from various AI personalities" → Translated

### Menu Options

- ✅ "Add to chat" → Translated
- ✅ "Camera" → Translated
- ✅ "Photos" → Translated
- ✅ "Web search" → Translated
- ✅ "Use style" → Translated
- ✅ "Normal" → Translated
- ✅ "Detailed" → Translated
- ✅ "Star Chat" / "Unstar Chat" → Translated
- ✅ "Rename Chat" → Translated
- ✅ "Delete Chat" → Translated
- ✅ "Share Chat" → Translated

### Dialogs

- ✅ "Search the Web?" → Translated
- ✅ "I may not have the latest information..." → Translated
- ✅ "No, thanks" → Translated
- ✅ "Yes, search web" → Translated

### Attachment Section

- ✅ "Image selected" → Translated
- ✅ "Attached to message" → Translated

## Expected Behavior

### Instant Switching

- **No restart needed** - Language changes take effect immediately
- Navigation back to chat screen shows translated text
- Menus and dialogs update on next interaction

### RTL Layout (Arabic)

- UI elements flip to right-to-left
- Text alignment adjusts automatically
- All controls properly positioned

### Persistence

- Selected language saved to device
- Reopening app maintains language choice
- Device language detected on first launch

## Troubleshooting

| Issue                                 | Solution                                                    |
| ------------------------------------- | ----------------------------------------------------------- |
| Text still in English after switching | Hot reload the app (if using dev tools) or restart app      |
| RTL layout not flipping for Arabic    | Ensure Arabic is properly selected in Settings              |
| Missing translations                  | Check that all 5 JSON files in assets/locales/ are present  |
| Language doesn't persist              | Check SharedPreferences and LanguageProvider initialization |

## Files to Verify

```
assets/locales/
├── en.json       (English - 27 new keys added)
├── es.json       (Spanish - 27 keys translated)
├── fr.json       (French - 27 keys translated)
├── ar.json       (Arabic - 27 keys translated)
└── hi.json       (Hindi - 27 keys translated)

lib/screens/
└── online_ai_screen.dart (25+ strings replaced with localization keys)

lib/utils/
├── app_localizations.dart (existing - loads JSON)
├── language_provider.dart (existing - manages language state)
└── localization_extension.dart (existing - shorthand helpers)
```

## Success Criteria

All of the following should be true:

- ✅ All visible text in chat screen changes when language is switched
- ✅ Menu options update instantly
- ✅ Dialog messages are translated
- ✅ Arabic layout flips to RTL
- ✅ Language selection persists between sessions
- ✅ No hardcoded English strings in critical UI paths
- ✅ App doesn't require restart for language changes

---

**Last Updated**: $(date)
**Status**: ✅ Ready for Testing
