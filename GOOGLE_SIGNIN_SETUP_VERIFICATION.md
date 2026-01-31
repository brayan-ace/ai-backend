# Google Sign-In Setup Verification Checklist

Use this checklist to verify your Google Sign-In is configured correctly.

## ✅ Pre-Implementation Checklist

- [ ] Flutter project created with Firebase support
- [ ] `google_sign_in: ^6.2.1` in pubspec.yaml
- [ ] `firebase_auth: ^5.0.0` in pubspec.yaml
- [ ] Firebase project created at console.firebase.google.com

---

## ✅ Step 1: Get Android SHA-1 Fingerprint

```bash
cd android
./gradlew signingReport
```

Look for:

```
SHA1: AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12
```

- [ ] SHA1 fingerprint copied
- [ ] SHA1 is 40 characters (after removing colons)
- [ ] Saved this value

---

## ✅ Step 2: Register Android App in Firebase

### 2.1 Go to Firebase Console

- [ ] Visit https://console.firebase.google.com
- [ ] Select your project (or create new)

### 2.2 Add Android App

- [ ] Click "Add App" → "Android"
- [ ] Enter Android package name: `com.example.myai` (or your app's package)
- [ ] Enter App nickname (optional): e.g., "My AI Android"

**To find your package name:**

```bash
grep "package=" android/app/src/main/AndroidManifest.xml
# Example: package="com.example.myai"
```

### 2.3 Add SHA-1 Fingerprint

- [ ] In Firebase Console → Project Settings → Your apps → Android
- [ ] Paste your SHA1 from Step 1
- [ ] Click Save

---

## ✅ Step 3: Download google-services.json

### 3.1 Get the file

- [ ] In Firebase Console → Android app settings
- [ ] Click "Download google-services.json"
- [ ] Save to: `android/app/google-services.json`

### 3.2 Verify placement

```bash
# Should exist at this path:
ls -la android/app/google-services.json
```

- [ ] File exists at `android/app/google-services.json`
- [ ] File size > 1KB (not empty)

---

## ✅ Step 4: Configure Android Build Files

### 4.1 Check `android/build.gradle` (top-level)

Should have:

```gradle
buildscript {
    dependencies {
        // Other dependencies...
        classpath 'com.google.gms:google-services:4.3.15' // or newer
    }
}
```

- [ ] Google Services plugin dependency added

### 4.2 Check `android/app/build.gradle`

Should have:

```gradle
apply plugin: 'com.android.application'
apply plugin: 'com.google.gms.google-services'  // ADD THIS LINE

android {
    // ... rest of config
}

dependencies {
    // Firebase is pulled from google-services.json
}
```

- [ ] `apply plugin: 'com.google.gms.google-services'` is present
- [ ] It's AFTER `apply plugin: 'com.android.application'`

### 4.3 Check `android/app/src/main/AndroidManifest.xml`

Should have:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

- [ ] INTERNET permission added

---

## ✅ Step 5: Enable Google Authentication in Firebase

### 5.1 Go to Authentication

- [ ] Firebase Console → Authentication → Get Started (if needed)
- [ ] Click on "Sign-in method" tab

### 5.2 Enable Google Provider

- [ ] Find "Google" in the list
- [ ] Click the toggle to **Enable**
- [ ] You may be asked for a "Support email" - use your email
- [ ] Click Save

- [ ] Google provider is ENABLED (green toggle)

---

## ✅ Step 6: Rebuild Flutter App

```bash
# Clean previous build
flutter clean

# Get dependencies
flutter pub get

# Rebuild app
flutter run -v
```

- [ ] `flutter clean` completed without errors
- [ ] `flutter pub get` completed without errors
- [ ] App builds without errors
- [ ] App installs on device/emulator

---

## ✅ Step 7: Test Sign-In

### 7.1 First-Time Sign-In

1. Open the app
2. Tap "Continue with Google" button
3. Select a Google account

**Expected Behavior:**

- [ ] Google Sign-In dialog appears
- [ ] User sees "Nexa Smart AI wants to:" permission screen (consent)
- [ ] After approval, app shows "Signing in..." spinner
- [ ] User is logged in and sees main app screen
- [ ] **NO red error screen or crash** ✅

### 7.2 Second Sign-In (Same Account)

1. Sign out (Settings → Logout)
2. Tap "Continue with Google" button

**Expected Behavior:**

- [ ] Google Sign-In dialog appears
- [ ] **Consent screen does NOT appear** (this is normal!)
- [ ] After account selection, app shows "Signing in..." spinner
- [ ] User is logged in
- [ ] **NO red error screen or crash** ✅

### 7.3 Cancel Sign-In

1. Tap "Continue with Google"
2. Tap Cancel/Back without selecting account

**Expected Behavior:**

- [ ] Error message shows: "Sign-in was cancelled. Please try again."
- [ ] User can retry without crashing
- [ ] **NO red error screen** ✅

---

## ✅ Step 8: Verify Logging

In terminal, run:

```bash
flutter run -v
# Or in another terminal:
adb logcat | grep GoogleAuth
```

**Expected Log Output:**

```
[GoogleAuth] 🚀 Attempt 1/2: Starting Google Sign-In...
[GoogleAuth] ✅ Google account selected
[GoogleAuth] 🔑 Google authentication tokens obtained
[GoogleAuth] ✅ User authenticated successfully
```

- [ ] Logs show successful authentication flow
- [ ] No error messages in logs
- [ ] No exceptions or crashes logged

---

## ⚠️ Troubleshooting

### Issue: "Google Sign-In is not enabled in Firebase"

**Log:** `[GoogleAuth] ⚠️ Google sign-in not enabled in Firebase`

**Fix:**

1. [ ] Go to Firebase Console → Authentication
2. [ ] Click "Sign-in method" tab
3. [ ] Find Google and enable the toggle
4. [ ] Save

### Issue: "Firebase credential sign-in failed"

**Log:** `[GoogleAuth] ❌ Firebase credential sign-in failed: invalid-credential`

**Fix:**

1. [ ] Verify SHA-1 fingerprint in Firebase Console matches device
2. [ ] Run `./gradlew signingReport` again to get current SHA-1
3. [ ] Check Firebase Console → Project Settings → Your apps → Android
4. [ ] Update the SHA certificate fingerprints
5. [ ] Rebuild app: `flutter clean && flutter run`

### Issue: App crashes on startup

**Symptoms:** Red error screen immediately when app opens

**Fix:**

1. [ ] Check `android/app/google-services.json` exists
2. [ ] Verify file size > 1KB (not empty)
3. [ ] Check `android/app/build.gradle` has Google Services plugin
4. [ ] Run `flutter clean && flutter pub get`
5. [ ] Rebuild: `flutter run`

### Issue: "Network error" on sign-in

**Log:** `Network error. Please check your internet connection.`

**Fix:**

1. [ ] Check WiFi/internet connection on device
2. [ ] Try again
3. [ ] If still fails, check Firebase service status

---

## ✅ Final Verification

- [ ] App rebuilds without errors
- [ ] First-time sign-in works with consent screen
- [ ] Second sign-in works without consent screen
- [ ] Cancelling sign-in shows error gracefully
- [ ] Logs show successful authentication
- [ ] No crashes, no red error screens
- [ ] User profile loads correctly after sign-in

---

## 📋 File Checklist

Verify these files exist and are configured:

- [ ] `android/app/google-services.json` - Download from Firebase
- [ ] `android/build.gradle` - Has Google Services classpath
- [ ] `android/app/build.gradle` - Has Google Services plugin applied
- [ ] `android/app/src/main/AndroidManifest.xml` - Has INTERNET permission
- [ ] `lib/services/auth/google_auth_service.dart` - Updated version
- [ ] `lib/widgets/google_sign_in_button.dart` - Updated version
- [ ] `pubspec.yaml` - Has google_sign_in and firebase_auth

---

## 🎓 Notes

**About the Consent Screen:**

- First sign-in: Consent screen WILL appear ✅
- Subsequent logins: Consent screen will NOT appear (normal) ✅
- This is Google's default behavior, not a bug

**About Crashes:**

- With the fix: App NEVER crashes (try-catch everywhere) ✅
- All errors shown gracefully to user ✅
- Detailed logs help troubleshoot issues ✅

**About Testing:**

- Use real Google account for testing (not test credentials)
- Test on both emulator and real device
- Test with different Google accounts if possible

---

## 📞 If Problems Persist

1. Check logs: `adb logcat | grep -E "GoogleAuth|Error|Exception"`
2. Verify all checklist items are completed
3. Review GOOGLE_SIGNIN_CRASH_FIX_GUIDE.md for detailed explanation
4. Check Firebase Console for any configuration issues
