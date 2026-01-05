# App Icon Setup Instructions

## Step 1: Save Your Icon Image

1. Save the blue diamond icon image you shared as `app_icon.png`
2. Place it in: `C:\android\flutter_application_1\myai\assets\images\app_icon.png`
3. **Recommended size**: 1024x1024 pixels (will be automatically resized)

## Step 2: Install Dependencies & Generate Icons

Run these commands in PowerShell:

```powershell
# Install the flutter_launcher_icons package
flutter pub get

# Generate all icon sizes for Android and iOS
flutter pub run flutter_launcher_icons
```

## Step 3: Verify

After running the commands, your app will have:

- ✅ Android icons in all sizes (mipmap-hdpi, xhdpi, xxhdpi, xxxhdpi, mdpi)
- ✅ iOS icons in the AppIcon.appiconset
- ✅ Adaptive icon with dark navy background (#0A0E27)

## Step 4: Rebuild & Test

```powershell
# Clean build
flutter clean

# Run the app to see your new icon
flutter run
```

Your beautiful blue diamond icon will now appear on your device! 🎨

---

**Note**: The icon background color is set to match the dark navy in your icon (#0A0E27).
If you need to adjust it, edit the `adaptive_icon_background` value in `pubspec.yaml`.
