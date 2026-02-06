# Settings Screen - Visual Structure Diagram

## 📐 Screen Layout

```
┌──────────────────────────────────────────────┐
│           SETTINGS SCREEN (NEW)              │
├──────────────────────────────────────────────┤
│                                              │
│         🎨 PREMIUM HEADER SECTION            │
│      ╔═══════════════════════════════════╗   │
│      ║                                   ║   │
│      ║      ✨  [GRADIENT CIRCLE]  ✨    ║   │
│      ║         (App Logo Icon)           ║   │
│      ║                                   ║   │
│      ║      Nexa Smart AI                ║   │
│      ║  Your AI learning companion       ║   │
│      ║                                   ║   │
│      ╚═══════════════════════════════════╝   │
│                                              │
├──────────────────────────────────────────────┤
│                                              │
│      👤 USER PROFILE CARD SECTION            │
│      ╔═══════════════════════════════════╗   │
│      ║ [AVATAR]  john                    ║   │
│      ║           brayanjordan194@...     ║   │
│      ╚═══════════════════════════════════╝   │
│                                              │
├──────────────────────────────────────────────┤
│                                              │
│      ⭐ ACCESS PLANS / UPGRADE CARD          │
│      ╔═══════════════════════════════════╗   │
│      ║  Unlock Premium          ➜         ║   │
│      ║  Get exclusive access to           ║   │
│      ║  premium learning features         ║   │
│      ╚═══════════════════════════════════╝   │
│                                              │
├──────────────────────────────────────────────┤
│                                              │
│      ⚙️ GENERAL SETTINGS                     │
│      ┌───────────────────────────────────┐   │
│      │ ✏️  Edit Profile                  │   │
│      │     Edit your profile info        │   │
│      ├───────────────────────────────────┤   │
│      │ 🎨 App Theme            [DARK]   │   │
│      │     Change appearance             │   │
│      ├───────────────────────────────────┤   │
│      │ 🔔 Notifications                  │   │
│      │     Manage push notifications     │   │
│      ├───────────────────────────────────┤   │
│      │ 🌍 Language         [English  ▼]  │   │
│      │     Select app language           │   │
│      ├───────────────────────────────────┤   │
│      │ 🚪 Logout                         │   │
│      │     Sign out from your account    │   │
│      └───────────────────────────────────┘   │
│                                              │
│      📦 APP FEATURES                         │
│      ┌───────────────────────────────────┐   │
│      │ ⚙️ Capabilities                   │   │
│      │    Explore features               │   │
│      ├───────────────────────────────────┤   │
│      │ 📚 Show Onboarding                │   │
│      │    View app walkthrough           │   │
│      └───────────────────────────────────┘   │
│                                              │
├──────────────────────────────────────────────┤
│                                              │
│      🤝 CONNECT WITH US                      │
│      ┌───────────────────────────────────┐   │
│      │ 💬 WhatsApp        [ICON]         │   │
│      │    Join our community             │   │
│      ├───────────────────────────────────┤   │
│      │ 👍 Facebook        [ICON]         │   │
│      │    Follow us                      │   │
│      ├───────────────────────────────────┤   │
│      │ 📸 Instagram       [ICON]         │   │
│      │    Follow us                      │   │
│      ├───────────────────────────────────┤   │
│      │ 🎵 TikTok          [ICON]         │   │
│      │    Follow us                      │   │
│      └───────────────────────────────────┘   │
│                                              │
├──────────────────────────────────────────────┤
│                                              │
│      📋 LEGAL & SUPPORT                      │
│      ┌───────────────────────────────────┐   │
│      │ 🔒 Privacy Policy                 │   │
│      │    Read our privacy policy        │   │
│      ├───────────────────────────────────┤   │
│      │ 📄 Terms of Service               │   │
│      │    Review terms & conditions      │   │
│      ├───────────────────────────────────┤   │
│      │ ℹ️ About                          │   │
│      │    App information                │   │
│      └───────────────────────────────────┘   │
│                                              │
├──────────────────────────────────────────────┤
│                (Bottom Padding)              │
└──────────────────────────────────────────────┘
```

---

## 🎨 Component Specifications

### Premium Header

```
Dimensions: Full Width
Height: ~200px
Background: Gradient (Theme-aware)
Content Alignment: Center

Components:
├── Icon Container (120x120)
│   ├── Shape: Circle
│   ├── Background: Primary Gradient
│   ├── Shadow: Glow Effect (blur: 30)
│   └── Icon: Icons.stars_rounded (60px)
├── App Name (Text)
├── Tagline (Text - Tertiary Color)
```

### User Profile Card

```
Dimensions: Full Width - 16px margin
Height: ~100px
Border Radius: 16px
Background: Surface Gradient
Border: 1px Elevated Color
Shadow: Card Shadow

Components:
├── Avatar Container (70x70)
│   ├── Shape: Circle
│   ├── Background: Primary Gradient
│   └── Icon: Icons.person_rounded
├── Content Column
│   ├── Username (Body Large, Bold)
│   └── Email (Body Small, Tertiary)
```

### Access Plans Card

```
Dimensions: Full Width - 16px margin
Height: ~120px
Border Radius: 16px
Background: Primary Gradient
Shadow: Glow Shadow (primary + 50% opacity)

Components:
├── Content Column
│   ├── Title: "Unlock Premium"
│   └── Subtitle: "Get exclusive access..."
└── Right Icon Container
    └── Icon: Icons.arrow_forward_rounded
```

### Settings Cards

```
Dimensions: Full Width - 8px margin
Border Radius: 16px
Background: Surface Gradient
Border: 1px Elevated Color
Shadow: Card Shadow

Each Setting Tile:
├── Leading Icon (44x44)
│   ├── Background: Icon Gradient
│   └── Icon (22px)
├── Title (Body Large)
├── Subtitle (Body Small, Tertiary)
└── Trailing (Icon or Custom Widget)
```

---

## 🌈 Color Scheme

### Light Mode

```
Background: #FAFAFA → #F5F5F5 (gradient)
Surface: #FFFFFF → #FAFAFA (subtle gradient)
Primary: #6200EE (purple)
Primary Alt: #7C5CFF (lighter purple)
Text Primary: #1F2937 (dark gray)
Text Tertiary: #9CA3AF (light gray)
Border: #E5E7EB (very light gray)
```

### Dark Mode

```
Background: Dark Gradient Start → Dark Gradient End
Surface: #2D2D2D → #242424 (subtle gradient)
Primary: #7C5CFF (bright purple)
Text Primary: #E5E7EB (light)
Text Tertiary: #9CA3AF (medium gray)
Border: Elevated Color with 50% opacity
```

---

## 📱 Responsive Behavior

### Small Phones (< 480px)

- Maintain full layout, reduce padding slightly
- Icons remain 44x44 for touch targets
- Cards remain full width - 8px

### Medium Phones (480px - 720px)

- Full layout as shown
- Optimal spacing and readability

### Tablets (> 720px)

- Cards maintain max-width constraints
- Centered container
- Increased horizontal padding

---

## 🔄 Interaction Flows

### Language Selection

```
Tap Language Tile
      ↓
Show Language Dialog
      ↓
┌─────────────────────────────┐
│  SELECT LANGUAGE            │
├─────────────────────────────┤
│ 🌍 English        ✓          │ ← Selected
│ 🌍 Español        ○          │
│ 🌍 Français       ○          │
│ 🌍 العربية        ○          │
│ 🌍 हिंदी          ○          │
└─────────────────────────────┘
      ↓
Selection
      ↓
Dialog Closes + Language Updates Instantly
```

### Theme Toggle

```
Tap App Theme Tile
      ↓
Show Color Mode Dialog
      ↓
┌──────────────────────────────┐
│  COLOR MODE                  │
├──────────────────────────────┤
│ ☀️  Light          ○          │
│ 🌙 Dark           ✓          │ ← Selected
└──────────────────────────────┘
      ↓
Selection
      ↓
Dialog Closes + Theme Updates Immediately
      ↓
SnackBar Confirmation
```

### Logout Flow

```
Tap Logout
      ↓
Show Confirmation Dialog
      ↓
┌──────────────────────────────┐
│ ⚠️  LOGOUT                    │
├──────────────────────────────┤
│ Are you sure?                │
│ You'll need to sign in again │
├──────────────────────────────┤
│ [Cancel] [Logout]            │
└──────────────────────────────┘
      ↓
  Confirmed
      ↓
Sign Out + Navigate to Auth
```

---

## ✨ Animation & Transitions

- **Card Hover**: Subtle elevation increase (Android)
- **Icon Tap**: Brief color flash or scale (0.95x)
- **Dialog Appearance**: Fade in + scale from center
- **Language Selection**: Gradient highlight animation
- **List Scroll**: Smooth with momentum

---

## 📊 Information Hierarchy

```
1. Premium Header (Immediate Brand Identity)
   └─ Establishes premium feel

2. User Profile Card (User Context)
   └─ Shows current user

3. Access Plans (Primary CTA)
   └─ Monetization opportunity

4. General Settings (Most Important)
   └─ Frequently used features
   └─ Profile, Theme, Language, Logout

5. App Features (Secondary)
   └─ Less frequent but important

6. Connect With Us (Engagement)
   └─ Community building

7. Legal & Support (Required)
   └─ Compliance and help
```

---

## 🎯 Design Principles Applied

✅ **Visual Hierarchy**: Clear priority ordering
✅ **Consistency**: Matches app design system
✅ **Accessibility**: High contrast, clear labels
✅ **Usability**: Intuitive organization
✅ **Aesthetics**: Premium, modern, polished
✅ **Performance**: Efficient layout rendering
✅ **Responsiveness**: Works on all devices
