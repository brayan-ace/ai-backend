# 🧪 Localization Testing Guide - Step by Step

## 🚀 How to Test the Implementation

### Prerequisites

- Flutter SDK installed
- Android emulator or physical device
- App code ready to run

---

## ⚡ Quick Test (5 minutes)

### Step 1: Run the App

```bash
cd /path/to/Nexa\ Smart\ AI
flutter run
```

### Step 2: Navigate to Settings

```
1. Open the app (should load in English by default)
2. Tap the Hamburger Menu (☰) in the drawer
3. Tap on the Settings icon (gear icon)
4. OR Navigate to main screen and tap Settings in bottom nav
```

### Step 3: Open Language Selection

```
1. In Settings screen, scroll to "Appearance" section
2. Look for "Language" option below "Color Mode"
3. Tap on "App Language"
4. A dialog should appear with 5 languages
```

### Step 4: Test Language Switching

```
For each language:
  1. Tap the language
  2. Dialog closes
  3. Observe the entire UI updates instantly ✨
  4. Check drawer, buttons, headings all change
  5. No app restart needed!

Test order:
  1. English → Español
  2. Español → Français
  3. Français → العربية (CHECK RTL!)
  4. العربية → हिंदी
  5. हिंदी → English
```

### Step 5: Verify Home Screen Updates

```
After each language change, go to Home screen:
- Drawer should show localized:
  ✓ "Welcome"
  ✓ "Study Plans" / "Mis Planes de Estudio" / "Mes Plans d'Étude"
  ✓ "Chats" / "Chats" / "Chats"
  ✓ "Workspaces" / "Espacios de Trabajo" / "Espaces de Travail"
- Main content should show localized action chips
```

### Step 6: Test Persistence

```
1. Change language to Spanish
2. Close app completely (swipe up to close)
3. Reopen app
4. App should be in Spanish ✓
5. Repeat with Arabic, French, Hindi
```

---

## 🧩 Detailed Test Scenarios

### Scenario 1: Language Switching (No Restart)

**Expected Behavior:** Entire UI updates instantly without app restart

```
Before:
  - Screen: Settings
  - Language: English
  - Text: "Color Mode"

Action: Select Spanish

After:
  - Screen: Settings (NO CHANGE IN PAGE)
  - Language: Spanish
  - Text: "Modo de Color" (UPDATED!)
  - All other labels updated
  - No flutter hot restart shown in console
```

**Verification Checklist:**

- [ ] Dialog closes after selection
- [ ] All text updates immediately
- [ ] Bottom navigation updates
- [ ] Drawer content updates
- [ ] No loading screen
- [ ] No app restart

---

### Scenario 2: RTL Layout (Arabic)

**Expected Behavior:** All layout reverses when Arabic selected

```
Before (English):
  └─ Settings Header [⚙️]
  └─ Account
     └─ [Person Icon] Profile ➜

After (Arabic):
  ➜ [Account Icon]
  └─ [Profile] حساب ➜ الملف الشخصي
  └─ Settings Header Header [⚙️]
```

**Verification Checklist:**

- [ ] All buttons/icons move to opposite side
- [ ] Text flows right-to-left
- [ ] Navigation drawer slides from right
- [ ] Checkmark appears on correct language
- [ ] No layout breaks
- [ ] All text remains readable

---

### Scenario 3: Device Language Detection

**Test on First Launch:**

```bash
# Method 1: Uninstall app completely
flutter install --uninstall-only
flutter run

# Method 2: Clear app data
adb shell pm clear com.example.myai  # Replace with your package name
flutter run
```

**With Device in Spanish:**

```
1. Set device language to Spanish
2. Run app for first time
3. App should display in Spanish ✓
4. Check device Settings → System → Languages
5. App language should match device
```

**With Device in Arabic:**

```
1. Set device language to Arabic
2. Run app for first time
3. App should display in Arabic ✓
4. App should have RTL layout ✓
5. Verify all text flows right-to-left
```

**With Device in Unsupported Language (e.g., Chinese):**

```
1. Set device language to Chinese
2. Run app for first time
3. App should display in English ✓ (default fallback)
```

---

### Scenario 4: Persistence Across Sessions

**Test Persistence:**

```
Session 1:
  1. Launch app (English)
  2. Go to Settings → Language
  3. Select Arabic
  4. Verify RTL layout

Session 2:
  1. Close app completely
  2. Reopen app
  3. Should still be Arabic ✓
  4. Should still have RTL layout ✓

Session 3:
  1. Go to Settings → Language
  2. Select French
  3. Close app

Session 4:
  1. Reopen app
  2. Should still be French ✓
```

**Verification Checklist:**

- [ ] Language persists after close/open
- [ ] RTL persists with Arabic
- [ ] SharedPreferences working
- [ ] Language remembered across 5+ sessions

---

### Scenario 5: All Screens Respond to Language

**Test Coverage:**

```
Settings Screen:
  - [ ] Title updates
  - [ ] Section headers update (Account, Appearance, Language)
  - [ ] Menu item labels update
  - [ ] Dialog options update

Home Screen - Drawer:
  - [ ] Welcome text updates
  - [ ] Section titles update (Study Plans, Chats, Workspaces)
  - [ ] Menu items update (My Study Plans, All Chats, Starred, Archived)
  - [ ] Empty state message updates

Home Screen - Main Content:
  - [ ] Heading updates ("What can I help with?" → Localized)
  - [ ] Subtitle updates
  - [ ] Action chip labels update (all 7 chips)
  - [ ] Search hint updates

Bottom Navigation:
  - [ ] All nav labels update
```

---

## 🔍 What to Check in Console

### Successful Language Change (Look for these):

```
[✓] Locale set to: es (Spanish)
[✓] Provider notified listeners
[✓] All widgets rebuilt
[✓] No errors in console
[✓] No hot restart messages
```

### Signs of Problems:

```
[✗] "Undefined name 'AppLocalizations'" → Import missing
[✗] "Missing translation key" → Key not in JSON
[✗] "Provider not found" → LanguageProvider not initialized
[✗] Layout doesn't update → Provider issue
[✗] App crashes → JSON parsing error
```

---

## 🎨 Visual Checklist - Home Screen

### Before: English

```
┌─────────────────────────────┐
│ ☰              Settings ⚙️  │ ← Drawer Header
├─────────────────────────────┤
│ STUDY PLANS                 │
│ 📚 My Study Plans           │
│                             │
│ CHATS                       │
│ 💬 All chats                │
│ ⭐ Starred                  │
│ 📦 Archived                 │
├─────────────────────────────┤
│ What can I help with?       │ ← Main Content
│ Quick starters...           │
│ [💬] Talk to a friend       │
│ [🔍] Discover the app       │
│ [🤖] Talk to your agents    │
└─────────────────────────────┘
```

### After: Español

```
┌─────────────────────────────┐
│ ☰         Configuración ⚙️  │ ← Changed!
├─────────────────────────────┤
│ PLANES DE ESTUDIO           │ ← Changed!
│ 📚 Mis Planes de Estudio    │ ← Changed!
│                             │
│ CHATS                       │ (Same word)
│ 💬 Todos los chats          │ ← Changed!
│ ⭐ Destacados               │ ← Changed!
│ 📦 Archivados               │ ← Changed!
├─────────────────────────────┤
│ ¿Con qué puedo ayudarte?    │ ← Changed!
│ Iniciadores rápidos...      │ ← Changed!
│ [💬] Hablar con un amigo    │ ← Changed!
│ [🔍] Descubrir la aplicación│ ← Changed!
│ [🤖] Habla con tus agentes  │ ← Changed!
└─────────────────────────────┘
```

### After: العربية (Arabic - RTL)

```
┌──────────────────────────────────┐
│  ⚙️ الإعدادات              ☰      │ ← RTL!
├──────────────────────────────────┤
│                   خطط الدراسة     │ ← RTL!
│            خطط الدراسة الخاصة بي 📚 │ ← RTL!
│                                  │
│                      الدردشات     │ ← RTL!
│                  جميع الدردشات 💬 │ ← RTL!
│                    المفضلة ⭐     │ ← RTL!
│                   المؤرشفة 📦     │ ← RTL!
├──────────────────────────────────┤
│       كيف يمكنني مساعدتك؟        │ ← RTL + Right Align!
│     المحركات السريعة...          │ ← RTL!
│    تحدث مع صديق 💬               │ ← RTL!
│    اكتشف التطبيق 🔍              │ ← RTL!
│    تحدث مع وكلائك 🤖             │ ← RTL!
└──────────────────────────────────┘
```

---

## 📱 Testing on Physical Device

### Prerequisites:

```bash
# Connect Android device
adb devices

# Verify device shows up
# Output: YOUR_DEVICE_ID  device
```

### Run on Device:

```bash
flutter run -d YOUR_DEVICE_ID
```

### Specific Tests on Device:

```
1. Change language to Arabic
2. Rotate screen (portrait ↔ landscape)
3. Verify RTL works in both orientations
4. Test with on-screen keyboard
5. Test with system gestures (Android back gesture)
```

---

## 🎯 Test Results Template

### ✅ Test Summary

**Date:** **\_\_\_**
**Device:** **\_\_\_** (Emulator/Physical)
**OS:** **\_\_\_** (Android/iOS/Other)

#### Language Switching Tests

- [ ] English → Spanish: PASS / FAIL
- [ ] Spanish → French: PASS / FAIL
- [ ] French → Arabic (RTL): PASS / FAIL
- [ ] Arabic → Hindi: PASS / FAIL
- [ ] Hindi → English: PASS / FAIL
- [ ] No restarts needed: YES / NO

#### RTL Layout (Arabic) Tests

- [ ] Layout mirrored: PASS / FAIL
- [ ] Text RTL: PASS / FAIL
- [ ] Icons mirrored: PASS / FAIL
- [ ] Navigation works: PASS / FAIL
- [ ] Buttons positioned correctly: PASS / FAIL

#### Persistence Tests

- [ ] Spanish persists after close/open: PASS / FAIL
- [ ] Arabic persists (with RTL): PASS / FAIL
- [ ] Multiple sessions: PASS / FAIL

#### Device Language Tests

- [ ] Device Spanish → App Spanish: PASS / FAIL
- [ ] Device Arabic → App Arabic + RTL: PASS / FAIL
- [ ] Device Chinese → App English (fallback): PASS / FAIL

#### UI Update Tests

- [ ] Home drawer updates: PASS / FAIL
- [ ] Home content updates: PASS / FAIL
- [ ] Settings title updates: PASS / FAIL
- [ ] Settings sections update: PASS / FAIL
- [ ] Bottom nav updates: PASS / FAIL

#### Overall Result

**Status:** ✅ PASS / ⚠️ FAIL / 🔧 NEEDS FIXING

**Notes:**

```
_________________________________
_________________________________
_________________________________
```

---

## 🐛 Debugging

### If language doesn't switch:

```dart
// Add this to see what's happening
print('Current language: ${Provider.of<LanguageProvider>(context).currentLanguageCode}');
```

### If RTL doesn't work:

```dart
// Check in console
print('Is RTL: ${Provider.of<LanguageProvider>(context).isRTL}');
// Should print: Is RTL: true (for Arabic)
```

### If persistence doesn't work:

```dart
// Check SharedPreferences
adb shell
run-as com.example.myai
cat shared_prefs/com.example.myai_preferences.xml
```

### Clear all data (for fresh testing):

```bash
adb shell pm clear com.example.myai
flutter run
```

---

## ✨ Expected Behavior Summary

| Feature                   | Expected                    | Status |
| ------------------------- | --------------------------- | ------ |
| Language Selection Dialog | Opens with 5 languages      | ✅     |
| Native Language Names     | Displayed correctly         | ✅     |
| Instant UI Update         | No restart needed           | ✅     |
| RTL Layout (Arabic)       | Auto-enabled for Arabic     | ✅     |
| Persistence               | Language saved & restored   | ✅     |
| Device Language Detection | Respected on first launch   | ✅     |
| All Languages Work        | 5 languages functional      | ✅     |
| No Errors                 | Zero crashes/console errors | ✅     |

---

## 🎓 Learning Outcomes

After testing, you'll have verified:

1. ✅ Multi-language support works
2. ✅ Instant language switching without restart
3. ✅ RTL layout for Arabic
4. ✅ Persistent user preference
5. ✅ Device language respect
6. ✅ Production-ready implementation

---

## 📞 Troubleshooting

**Q: Language doesn't update?**
A: Verify Provider is in MultiProvider in main.dart, and you're using `Provider.of<LanguageProvider>(context)` inside build method.

**Q: RTL not working in Arabic?**
A: Check `Directionality` widget in main.dart builder. Should be wrapping child with `textDirection: TextDirection.rtl`.

**Q: Translation shows key name?**
A: Add translation to JSON file for all 5 languages. Key should be in exact nested path.

**Q: App crashes on language change?**
A: Check JSON files for parsing errors. Use online JSON validator.

**Q: Language doesn't persist?**
A: Verify SharedPreferences initialization in LanguageProvider. Check that `_prefs.setString()` is called.

---

**Ready to Test?** 🚀

```bash
flutter run
# Navigate to Settings → Language → Select a different language
# Watch the magic happen! ✨
```

---

**Last Updated:** February 3, 2026
**Version:** 1.0
**Status:** ✅ Ready to Test
