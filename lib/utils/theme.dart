import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Dark Blue Color Palette - Clean & Professional
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color primaryBlueDark = Color(0xFF1976D2);
  static const Color accentBlue = Color(0xFF42A5F5);
  static const Color accentBlueLight = Color(0xFF64B5F6);

  // Surfaces
  static const Color surfaceDark = Color(0xFF0D1117);
  static const Color surfaceCard = Color(0xFF161B22);
  static const Color surfaceElevated = Color(0xFF1F2937);
  static const Color surfaceGlass = Color(0x1A2196F3);

  // Backgrounds
  static const Color backgroundDeep = Color(0xFF0A0E17);
  static const Color backgroundGradientStart = Color(0xFF0D1117);
  static const Color backgroundGradientEnd = Color(0xFF1A1F2E);

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB4BDD4);
  static const Color textTertiary = Color(0xFF6E7891);
  static const Color textGlow = Color(0xFF42A5F5);

  // Semantic colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Gradients
  static const List<Color> primaryGradient = [
    Color(0xFF2196F3),
    Color(0xFF1976D2),
  ];
  static const List<Color> accentGradient = [
    Color(0xFF42A5F5),
    Color(0xFF1976D2),
  ];
  static const List<Color> surfaceGradient = [
    Color(0xFF161B22),
    Color(0xFF1F2937),
  ];
  static const List<Color> glassGradient = [
    Color(0x1AFFFFFF),
    Color(0x0AFFFFFF),
  ];

  // Spacing System
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;
  static const double space2xl = 48.0;
  static const double space3xl = 64.0;

  // Responsive Spacing - Adapt to text scale factor (for accessibility)
  // Example: getScaledSpacing(spaceMd, 1.5) returns 16 * 1.5 = 24
  static double getScaledSpacing(double baseValue, double scaleFactor) {
    return baseValue * scaleFactor;
  }

  // Responsive Icon Sizes - Scale with text size for visual consistency
  // Base sizes: xs=16, sm=20, md=24, lg=32, xl=40
  static double getScaledIconSize(double baseSize, double scaleFactor) {
    final scaled = baseSize * scaleFactor;
    // Cap at reasonable limits to prevent excessive icon sizes
    return scaled > 64
        ? 64
        : scaled < 12
        ? 12
        : scaled;
  }

  // Preset scaled icon sizes
  static double getIconXs(double scaleFactor) =>
      getScaledIconSize(16, scaleFactor);
  static double getIconSm(double scaleFactor) =>
      getScaledIconSize(20, scaleFactor);
  static double getIconMd(double scaleFactor) =>
      getScaledIconSize(24, scaleFactor);
  static double getIconLg(double scaleFactor) =>
      getScaledIconSize(32, scaleFactor);
  static double getIconXl(double scaleFactor) =>
      getScaledIconSize(40, scaleFactor);

  // Font Family Management (for app-wide font selection)
  static String currentFontFamily = 'Roboto';

  // Available fonts for selection
  static const List<String> availableFonts = [
    'Roboto',
    'Georgia',
    'Open Sans',
    'Poppins',
    'Playfair Display',
    'Inter',
    'Courier Prime',
    'Roboto Mono',
  ];

  // Update the current font family (called when user selects new font)
  static void updateFontFamily(String fontFamily) {
    if (availableFonts.contains(fontFamily)) {
      currentFontFamily = fontFamily;
    }
  }

  // Helper to apply font family to a text style
  static TextStyle applyFontFamily(TextStyle baseStyle, String fontFamily) {
    return baseStyle.copyWith(fontFamily: _getFontFamilyName(fontFamily));
  }

  // Map display names to Google Fonts family names
  static String _getFontFamilyName(String displayName) {
    switch (displayName) {
      case 'Roboto':
        return GoogleFonts.roboto().fontFamily ?? 'Roboto';
      case 'Georgia':
        return GoogleFonts.lora().fontFamily ?? 'Lora'; // Georgia-like serif
      case 'Open Sans':
        return GoogleFonts.openSans().fontFamily ?? 'Open Sans';
      case 'Poppins':
        return GoogleFonts.poppins().fontFamily ?? 'Poppins';
      case 'Playfair Display':
        return GoogleFonts.playfairDisplay().fontFamily ?? 'Playfair Display';
      case 'Inter':
        return GoogleFonts.inter().fontFamily ?? 'Inter';
      case 'Courier Prime':
        return GoogleFonts.courierPrime().fontFamily ?? 'Courier Prime';
      case 'Roboto Mono':
        return GoogleFonts.robotoMono().fontFamily ?? 'Roboto Mono';
      default:
        return GoogleFonts.roboto().fontFamily ?? 'Roboto';
    }
  }

  // Get Google Fonts TextTheme for the current font family
  static TextTheme getTextTheme(String fontFamily) {
    final baseTheme = switch (fontFamily) {
      'Georgia' => GoogleFonts.loraTextTheme(),
      'Open Sans' => GoogleFonts.openSansTextTheme(),
      'Poppins' => GoogleFonts.poppinsTextTheme(),
      'Playfair Display' => GoogleFonts.playfairDisplayTextTheme(),
      'Inter' => GoogleFonts.interTextTheme(),
      'Courier Prime' => GoogleFonts.courierPrimeTextTheme(),
      'Roboto Mono' => GoogleFonts.robotoMonoTextTheme(),
      _ => GoogleFonts.robotoTextTheme(), // Default to Roboto
    };
    return baseTheme;
  }

  // Border Radius
  static const double radiusSm = 12.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 24.0;
  static const double radius2xl = 32.0;
  static const double radiusFull = 999.0;

  // Shadows & Glows
  static List<BoxShadow> get glowShadow => [
    BoxShadow(
      color: primaryBlue.withOpacity(0.15),
      blurRadius: 16,
      spreadRadius: 0,
      offset: Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get accentGlow => [
    BoxShadow(
      color: accentBlue.withOpacity(0.2),
      blurRadius: 20,
      spreadRadius: 0,
      offset: Offset(0, 3),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: primaryBlue.withOpacity(0.08),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 16,
      offset: Offset(0, 12),
    ),
  ];

  // Typography
  static const String fontFamily = 'SF Pro Display';

  static TextStyle get displayLarge => TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static TextStyle get displayMedium => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.3,
    height: 1.25,
  );

  static TextStyle get displaySmall => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static TextStyle get headlineLarge => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0,
    height: 1.3,
  );

  static TextStyle get headlineMedium => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0,
    height: 1.3,
  );

  static TextStyle get headlineSmall => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0,
    height: 1.3,
  );

  static TextStyle get bodyLarge => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static TextStyle get bodyMedium => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static TextStyle get bodySmall => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: textTertiary,
    letterSpacing: 0,
    height: 1.4,
  );

  static TextStyle get labelLarge => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: 0.2,
    height: 1.2,
  );

  static TextStyle get labelMedium => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.3,
    height: 1.2,
  );

  static TextStyle get labelSmall => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textTertiary,
    letterSpacing: 0.3,
    height: 1.2,
  );

  // Dynamic Typography Methods (use these instead of static getters for theme-aware colors)
  static TextStyle displayLargeFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: isDark
          ? textPrimary
          : Color(0xFF1F2937), // Dark text for light mode
      letterSpacing: -0.5,
      height: 1.2,
    );
  }

  static TextStyle displayMediumFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: isDark ? textPrimary : Color(0xFF1F2937),
      letterSpacing: -0.3,
      height: 1.25,
    );
  }

  static TextStyle displaySmallFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      color: isDark ? textPrimary : Color(0xFF1F2937),
      letterSpacing: -0.2,
      height: 1.3,
    );
  }

  static TextStyle headlineLargeFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: isDark ? textPrimary : Color(0xFF1F2937),
      letterSpacing: 0,
      height: 1.3,
    );
  }

  static TextStyle headlineMediumFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: isDark ? textPrimary : Color(0xFF1F2937),
      letterSpacing: 0,
      height: 1.3,
    );
  }

  static TextStyle headlineSmallFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: isDark ? textPrimary : Color(0xFF1F2937),
      letterSpacing: 0,
      height: 1.3,
    );
  }

  static TextStyle bodyLargeFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: isDark
          ? textSecondary
          : Color(0xFF374151), // Dark gray for light mode
      letterSpacing: 0.1,
      height: 1.5,
    );
  }

  static TextStyle bodyMediumFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: isDark ? textSecondary : Color(0xFF374151),
      letterSpacing: 0.1,
      height: 1.5,
    );
  }

  static TextStyle bodySmallFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.normal,
      color: isDark
          ? textTertiary
          : Color(0xFF6B7280), // Medium gray for light mode
      letterSpacing: 0,
      height: 1.4,
    );
  }

  static TextStyle labelLargeFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: isDark ? textPrimary : Color(0xFF1F2937),
      letterSpacing: 0.2,
      height: 1.2,
    );
  }

  static TextStyle labelMediumFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: isDark ? textSecondary : Color(0xFF374151),
      letterSpacing: 0.3,
      height: 1.2,
    );
  }

  static TextStyle labelSmallFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: isDark ? textTertiary : Color(0xFF6B7280),
      letterSpacing: 0.3,
      height: 1.2,
    );
  }

  // Dynamic Color Methods (use these instead of static constants for theme-aware colors)
  static Color textPrimaryFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? textPrimary : Color(0xFF1F2937); // Dark text for light mode
  }

  static Color textSecondaryFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? textSecondary
        : Color(0xFF374151); // Dark gray for light mode
  }

  static Color textTertiaryFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? textTertiary
        : Color(0xFF6B7280); // Medium gray for light mode
  }

  static Color surfaceCardFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? surfaceCard : Color(0xFFFFFFFF); // White for light mode
  }

  static Color surfaceElevatedFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? surfaceElevated
        : Color(0xFFF9FAFB); // Light gray for light mode
  }

  static Color backgroundGradientStartFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? backgroundGradientStart
        : Color(0xFFFFFFFF); // White for light mode
  }

  static Color backgroundGradientEndFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? backgroundGradientEnd
        : Color(0xFFFFFFFF); // White for light mode
  }

  static List<Color> surfaceGradientFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? surfaceGradient
        : [
            Color(0xFFFFFFFF),
            Color(0xFFF9FAFB),
          ]; // White gradient for light mode
  }

  static List<Color> glassGradientFromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? glassGradient
        : [
            Color(0xFFFFFFFF).withOpacity(0.1),
            Color(0xFFFFFFFF).withOpacity(0.05),
          ]; // Light glass for light mode
  }

  // Theme Data
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: primaryBlue,
      secondary: accentBlue,
      tertiary: accentBlueLight,
      surface: surfaceCard,
      background: backgroundDeep,
      error: error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimary,
      onBackground: textPrimary,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: backgroundDeep,
    textTheme: getTextTheme(
      currentFontFamily,
    ).apply(bodyColor: textSecondary, displayColor: textPrimary),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceCard,
      contentPadding: EdgeInsets.symmetric(
        horizontal: spaceMd,
        vertical: spaceMd,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        borderSide: BorderSide(color: surfaceElevated, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        borderSide: BorderSide(color: surfaceElevated, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        borderSide: BorderSide(color: primaryBlue, width: 2),
      ),
      hintStyle: TextStyle(color: textTertiary, fontSize: 15),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: spaceXl, vertical: spaceMd),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
    ),
    dividerColor: surfaceElevated,
    shadowColor: Colors.black.withOpacity(0.5),
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: primaryBlueDark,
      secondary: primaryBlue,
      tertiary: accentBlue,
      surface: Color(0xFFFFFFFF), // White card surfaces
      background: Color(0xFFFFFFFF), // Pure white background
      error: error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF1F2937), // Dark text on surfaces
      onBackground: Color(0xFF1F2937), // Dark text on background
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: Color(0xFFFFFFFF), // Pure white scaffold
    textTheme: getTextTheme(
      currentFontFamily,
    ).apply(bodyColor: Color(0xFF374151), displayColor: Color(0xFF1F2937)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFF9FAFB), // Very light input background
      contentPadding: EdgeInsets.symmetric(
        horizontal: spaceMd,
        vertical: spaceMd,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        borderSide: BorderSide(color: primaryBlueDark, width: 2),
      ),
      hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
      labelStyle: TextStyle(color: Color(0xFF374151)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: spaceXl, vertical: spaceMd),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        backgroundColor: primaryBlueDark,
        foregroundColor: Colors.white,
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Color(0xFFFFFFFF), // White cards
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
    ),
    dividerColor: Color(0xFFE5E7EB),
    shadowColor: Colors.black.withOpacity(0.1),
  );
}
