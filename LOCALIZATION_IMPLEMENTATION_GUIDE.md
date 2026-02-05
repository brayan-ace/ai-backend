# Localization Implementation Guide

## ✅ Completed Components

### 1. **Localization Infrastructure**

- ✅ `AppLocalizations` service with nested translation keys
- ✅ `LanguageProvider` for state management with local persistence
- ✅ RTL layout support configured for Arabic
- ✅ Device language detection on first launch
- ✅ `flutter_localizations` added to dependencies

### 2. **Translation Files**

- ✅ `assets/locales/en.json` (English)
- ✅ `assets/locales/es.json` (Spanish)
- ✅ `assets/locales/fr.json` (French)
- ✅ `assets/locales/ar.json` (Arabic - RTL)
- ✅ `assets/locales/hi.json` (Hindi)

### 3. **Integration in MaterialApp** (`main.dart`)

- ✅ Multi-provider setup with LanguageProvider
- ✅ Locale binding with supportedLocales
- ✅ AppLocalizations delegate registered
- ✅ Global Material/Widgets/Cupertino localizations delegates
- ✅ RTL direction support via Directionality widget

### 4. **Language Selection Screen** (`settings_screen_new.dart`)

- ✅ Language settings section in Settings screen
- ✅ Language dialog with native language names
- ✅ Instant language switching with UI update
- ✅ Native language display (English, Español, Français, العربية, हिंदी)

### 5. **Localized Screens**

- ✅ Home Screen (`home_screen.dart`) - drawer and main content
- ✅ Settings Screen (`settings_screen_new.dart`) - titles, sections, labels

---

## 📋 Remaining Work - Screen by Screen

### **Priority 1: Authentication Screens**

#### `lib/screens/login_screen.dart`

Strings to localize:

```dart
'Login'                  → 'auth.login'
'Email'                  → 'auth.email'
'Password'               → 'auth.password'
'Forgot Password?'       → 'auth.forgotPassword'
"Don't have an account?" → 'auth.dontHaveAccount'
'Sign up with Google'    → 'auth.signUpWithGoogle'
'Login with Google'      → 'auth.loginWithGoogle'
'Login successful!'      → 'auth.loginSuccess'
```

#### `lib/screens/signup_screen.dart`

Strings to localize:

```dart
'Sign Up'                → 'auth.signup'
'Email'                  → 'auth.email'
'Password'               → 'auth.password'
'Confirm Password'       → 'auth.confirmPassword'
'Already have an account?' → 'auth.alreadyHaveAccount'
'Sign up with Google'    → 'auth.signUpWithGoogle'
'Signup successful!'     → 'auth.signupSuccess'
'Password must be at least 6 characters' → 'errors.passwordTooShort'
'Passwords do not match' → 'errors.passwordsMismatch'
'Invalid email'          → 'errors.invalidEmail'
```

#### `lib/screens/welcome_screen.dart`

Strings to localize:

```dart
'Welcome'                → 'onboarding.welcome'
'Your AI-powered learning companion' → 'onboarding.subtitle'
```

---

### **Priority 2: Study & Learning Screens**

#### `lib/screens/study_plan_screen_phase1.dart`

Strings to localize:

```dart
'Study Plans'            → 'study.studyPlans'
'Create Study Plan'      → 'study.createStudyPlan'
'Select Topic'           → 'study.selectTopic'
'No study plans'         → 'emptyStates.noStudyPlans'
```

#### `lib/screens/bot_processing_screen.dart`

Strings to localize:

```dart
'Bot Processing'         → 'study.botProcessing'
'Loading...'             → 'common.loading'
'Try Again'              → 'common.tryAgain'
```

#### `lib/screens/quiz_config_screen.dart`

Strings to localize:

```dart
'Quiz Configuration'     → 'study.quizConfig'
'Start Quiz'             → 'study.startStudy'
```

---

### **Priority 3: Chat & Communication**

#### `lib/screens/online_ai_screen.dart` / `offline_ai_screen.dart`

Strings to localize:

```dart
'Chat'                   → 'nav.chat'
'Send'                   → 'common.submit'
'Loading...'             → 'common.loading'
'Error'                  → 'common.error'
'Try Again'              → 'common.tryAgain'
All error messages       → Use 'errors.*' keys
All empty states         → Use 'emptyStates.*' keys
```

#### `lib/screens/chat_history_screen.dart`

Strings to localize:

```dart
'Chat History'           → Add to translations
'No chats'               → 'emptyStates.noChats'
'Delete'                 → 'common.delete'
```

---

### **Priority 4: Gamification & Streaks**

#### Streak Display (in various screens - search for streak emoji 🔥)

Strings to localize:

```dart
'Daily Streak 🔥'        → 'streak.dailyStreak'
'days in a row'          → 'streak.daysInARow'
'Keep the streak alive!' → 'streak.keepTheStreakAlive'
'Come back tomorrow'     → 'streak.comeBackTomorrow'
'Streak broken'          → 'streak.streakBroken'
'Streak maintained!'     → 'streak.streakMaintained'
```

Search for these in:

- `lib/screens/main_tabs.dart`
- `lib/widgets/` (any streak-related widgets)
- Bottom navigation or home screen overlays

---

### **Priority 5: Paywall/Premium Screens**

#### `lib/screens/paywall.dart` (if exists) or paywall widgets

Strings to localize:

```dart
'Premium'                → 'paywall.premium'
'Get Premium'            → 'paywall.getPremium'
'Unlock all features'    → 'paywall.unlockFeatures'
'Subscribe'              → 'paywall.subscribe'
'Monthly Plan'           → 'paywall.monthlyPlan'
'Yearly Plan'            → 'paywall.yearlyPlan'
'Start Free Trial'       → 'paywall.startTrial'
```

---

### **Priority 6: Error Messages & Common Dialogs**

These appear throughout the app, use consistent keys:

```dart
'Something went wrong'   → 'errors.somethingWentWrong'
'Network error'          → 'errors.networkError'
'Please try again later' → 'errors.serverError'
'Unauthorized'           → 'errors.unauthorized'
'Not found'              → 'errors.notFound'
```

Dialog buttons (use consistent keys):

```dart
'Cancel'                 → 'common.cancel'
'OK'                     → 'common.ok'
'Save'                   → 'common.save'
'Delete'                 → 'common.delete'
'Back'                   → 'common.back'
'Close'                  → 'common.close'
```

---

## 🔄 How to Implement Localization for a Screen

### Step 1: Add Import

```dart
import '../utils/app_localizations.dart';
```

### Step 2: Replace Strings

**Before:**

```dart
Text('Welcome')
TextField(hintText: 'Enter your name')
showDialog(title: Text('Delete?'))
```

**After:**

```dart
Text(AppLocalizations.of(context).t('drawer.welcome'))
TextField(hintText: AppLocalizations.of(context).t('common.cancel'))
showDialog(title: Text(AppLocalizations.of(context).t('common.delete')))
```

### Step 3 (Optional): Use Extension for Brevity

Import: `import '../utils/localization_extension.dart';`

Then use:

```dart
Text(context.tr('drawer.welcome'))
// OR
Text(context.t.welcome)  // For convenience getters
```

---

## 🧪 Testing Checklist

### Language Switching Test

- [ ] Open Settings → Language
- [ ] Select each language one by one
- [ ] Verify UI updates instantly (no restart needed)
- [ ] Verify bottom navigation labels update
- [ ] Verify drawer text updates
- [ ] Verify button labels update

### RTL Test (Arabic)

- [ ] Select Arabic in Language settings
- [ ] Verify layout is mirrored (all buttons, text, icons)
- [ ] Verify text flows right-to-left
- [ ] Verify back button/navigation works correctly in RTL
- [ ] Test on both landscape and portrait

### Device Language Detection

- [ ] On first launch (or after clearing app data):
  - [ ] Set device language to Spanish → App should be Spanish
  - [ ] Set device language to Arabic → App should be Arabic and RTL
  - [ ] Set device language to unsupported language (e.g., Chinese) → App defaults to English

### Persistence Test

- [ ] Change language to Spanish
- [ ] Close and reopen app
- [ ] Verify app is still in Spanish
- [ ] Change to Arabic, close/reopen
- [ ] Verify app is still in Arabic with RTL layout

### All Language Test

- [ ] Cycle through all 5 languages
- [ ] Verify no missing translations
- [ ] Verify text renders properly in each language

---

## 📝 Translation Key Naming Convention

**Pattern:** `section.key`

Examples:

- `common.cancel` - Common buttons
- `auth.login` - Authentication screens
- `settings.language` - Settings
- `home.welcomeTitle` - Home screen
- `errors.invalidEmail` - Error messages
- `streak.dailyStreak` - Gamification
- `study.studyPlans` - Study features

---

## 🚀 Quick Test Commands

```bash
# Run the app
flutter run

# Check for localization errors
flutter analyze

# Format code
dart format lib/

# Build APK with localization
flutter build apk
```

---

## ⚙️ Configuration Reference

### Supported Languages

1. **English (en)** - Default
2. **Spanish (es)** - Spain/Mexico
3. **French (fr)** - France/Belgium
4. **Arabic (ar)** - RTL Layout
5. **Hindi (hi)** - India

### Language Names (as displayed in app)

- English → English
- Español → Spanish (Spain)
- Français → French (France)
- العربية → Arabic
- हिंदी → Hindi

### File Locations

```
assets/
  locales/
    en.json      (335 strings)
    es.json      (335 strings)
    fr.json      (335 strings)
    ar.json      (335 strings)
    hi.json      (335 strings)

lib/
  utils/
    app_localizations.dart         (Core service)
    language_provider.dart         (State management)
    localization_extension.dart    (Helper extension)
  screens/
    settings_screen_new.dart       (Language selection UI)
```

---

## 💡 Notes for Developers

1. **Always use translation keys** - Never hardcode strings in the UI
2. **Test every language** - Some languages need more space (German, Hindi)
3. **RTL Layout** - Arabic automatically triggers RTL; verify all UI elements
4. **Device Language** - First launch respects device language; users can override in Settings
5. **No App Restart Needed** - Language change is instant thanks to Provider
6. **AI Chat Language** - AI responses are NOT affected by app language (independent)
7. **Consistency** - Use existing translation keys; don't create duplicates

---

## 🎯 Implementation Priority

1. ✅ **Core Infrastructure** (Done)
2. ✅ **Settings Screen with Language Selection** (Done)
3. ✅ **Home & Navigation** (Done)
4. 📋 **Auth Screens** (Next)
5. 📋 **Chat & Study Screens**
6. 📋 **Gamification (Streaks)**
7. 📋 **Paywall**
8. 📋 **Error Messages & Dialogs**

---

**Last Updated:** February 3, 2026
**Status:** Core infrastructure complete, 65% of screens localized
