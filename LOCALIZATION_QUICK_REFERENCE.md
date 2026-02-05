# 🌍 Localization Quick Reference Card

## 🚀 Quick Start

### Import in any screen:

```dart
import '../utils/app_localizations.dart';
```

### Use translations:

```dart
// Method 1: Full path
Text(AppLocalizations.of(context).t('drawer.welcome'))

// Method 2: Using extension (after importing localization_extension.dart)
Text(context.tr('drawer.welcome'))
```

---

## 📚 Common Translation Keys

### **Navigation**

| Key            | Usage        |
| -------------- | ------------ |
| `nav.home`     | Home tab     |
| `nav.chat`     | Chat tab     |
| `nav.settings` | Settings tab |
| `nav.profile`  | Profile tab  |

### **Common Actions**

| Key              | Usage                  |
| ---------------- | ---------------------- |
| `common.cancel`  | Cancel button          |
| `common.save`    | Save button            |
| `common.ok`      | OK button              |
| `common.back`    | Back button            |
| `common.delete`  | Delete button          |
| `common.loading` | Loading indicator text |

### **Settings Section**

| Key                   | Usage        |
| --------------------- | ------------ |
| `settings.title`      | "Settings"   |
| `settings.language`   | "Language"   |
| `settings.appearance` | "Appearance" |
| `settings.colorMode`  | "Color Mode" |
| `settings.dark`       | "Dark"       |
| `settings.light`      | "Light"      |

### **Drawer/Menu**

| Key                   | Usage               |
| --------------------- | ------------------- |
| `drawer.welcome`      | "Welcome" greeting  |
| `drawer.studyPlans`   | Study Plans section |
| `drawer.myStudyPlans` | My Study Plans menu |
| `drawer.chats`        | Chats section       |
| `drawer.allChats`     | All chats menu      |
| `drawer.workspaces`   | Workspaces section  |

### **Home Screen**

| Key                  | Usage        |
| -------------------- | ------------ |
| `home.welcomeTitle`  | Main heading |
| `home.quickStarters` | Subtitle     |
| `home.talkToFriend`  | Action chip  |
| `home.discoverApp`   | Action chip  |
| `home.search`        | Search hint  |

### **Errors**

| Key                         | Usage               |
| --------------------------- | ------------------- |
| `errors.somethingWentWrong` | Generic error       |
| `errors.networkError`       | Network issue       |
| `errors.invalidEmail`       | Invalid email       |
| `errors.passwordTooShort`   | Password validation |
| `errors.serverError`        | Server error        |

### **Gamification**

| Key                         | Usage             |
| --------------------------- | ----------------- |
| `streak.dailyStreak`        | "Daily Streak 🔥" |
| `streak.daysInARow`         | "days in a row"   |
| `streak.keepTheStreakAlive` | Motivation text   |

---

## 🎯 Language Codes & Names

| Code | Name    | Display  | RTL?    |
| ---- | ------- | -------- | ------- |
| `en` | English | English  | No      |
| `es` | Spanish | Español  | No      |
| `fr` | French  | Français | No      |
| `ar` | Arabic  | العربية  | **Yes** |
| `hi` | Hindi   | हिंदी    | No      |

---

## 🔧 Implementation Workflow

### 1️⃣ Add String to JSON

Edit `assets/locales/en.json`:

```json
{
  "mySection": {
    "myKey": "My Text"
  }
}
```

### 2️⃣ Add to Other Languages

Update `assets/locales/es.json`, `fr.json`, `ar.json`, `hi.json` with translations.

### 3️⃣ Use in Code

```dart
Text(AppLocalizations.of(context).t('mySection.myKey'))
```

---

## 🧪 Testing Checklist

- [ ] Switch language in Settings
- [ ] Verify text updates instantly (no restart)
- [ ] Test Arabic for RTL layout
- [ ] Close/reopen app to verify persistence
- [ ] Test device language on first launch
- [ ] Verify all 5 languages work
- [ ] Check for missing translations (they appear as keys)

---

## 📍 Where to Make Changes

### Add new string:

1. `assets/locales/en.json` - Add key and English text
2. `assets/locales/es.json` - Add Spanish translation
3. `assets/locales/fr.json` - Add French translation
4. `assets/locales/ar.json` - Add Arabic translation
5. `assets/locales/hi.json` - Add Hindi translation

### Use in screen:

```dart
// Step 1: Import
import '../utils/app_localizations.dart';

// Step 2: Replace hard-coded string
Text(AppLocalizations.of(context).t('section.key'))
```

---

## ⚡ Key Features

| Feature                   | Status               |
| ------------------------- | -------------------- |
| 5 Languages               | ✅ Implemented       |
| Instant Switching         | ✅ Working           |
| RTL Support (Arabic)      | ✅ Enabled           |
| Device Language Detection | ✅ Active            |
| Persistent Storage        | ✅ SharedPreferences |
| Native Language Names     | ✅ Displayed         |
| Zero Restart Needed       | ✅ Provider-based    |
| No AI Chat Interference   | ✅ Independent       |

---

## 🎨 Supported Languages

### ✅ English (en)

- Default language
- Full English translations available

### ✅ Español (es)

- Complete Spanish translations
- Mexican Spanish terminology

### ✅ Français (fr)

- Complete French translations
- European French

### ✅ العربية (ar)

- Complete Arabic translations
- **Automatic RTL layout**
- Bidirectional text support

### ✅ हिंदी (hi)

- Complete Hindi translations
- Devanagari script support

---

## 🚨 Common Issues & Solutions

| Issue                         | Solution                                                        |
| ----------------------------- | --------------------------------------------------------------- |
| String not translating        | Check JSON key path spelling                                    |
| Missing translation shows key | Add translation to all 5 JSON files                             |
| RTL layout wrong              | Only Arabic has RTL; verify language code                       |
| Language doesn't persist      | Check SharedPreferences initialization                          |
| Text not updating             | Ensure using `AppLocalizations.of(context)` inside build method |
| Can't find localization       | Add `import '../utils/app_localizations.dart'`                  |

---

## 📱 Testing on Device

```bash
# Run app
flutter run

# Navigate to Settings
# Tap Settings → Language
# Select Spanish/French/Arabic/Hindi
# Verify UI updates instantly
# Close and reopen to verify persistence
```

---

## 📖 Full Documentation

- **Implementation Guide:** `LOCALIZATION_IMPLEMENTATION_GUIDE.md`
- **Complete Summary:** `LOCALIZATION_SUMMARY.md`
- **Source Code:**
  - `lib/utils/app_localizations.dart`
  - `lib/utils/language_provider.dart`
  - `lib/main.dart` (Integration)

---

## 💡 Pro Tips

1. **Use nested keys** - `section.subsection.key` for organization
2. **Copy-paste translations** - Use Google Translate as starting point
3. **Test every language** - Some languages need more UI space
4. **Use native names** - Display "Español" not "Spanish"
5. **No hardcoding** - Always use translation keys
6. **Test RTL separately** - Use device set to Arabic locale

---

## 🎯 Next Screens to Localize

1. **Auth screens** (Login, Signup, Welcome)
2. **Study screens** (Study Plans, Bot Processing)
3. **Chat screens** (Online AI, Chat History)
4. **Paywall/Premium**
5. **Error dialogs** (Already translated in JSON)

See `LOCALIZATION_IMPLEMENTATION_GUIDE.md` for detailed instructions per screen.

---

**Last Updated:** February 3, 2026 | **Version:** 1.0 | **Status:** ✅ Ready to Use
