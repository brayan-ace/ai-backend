import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/theme.dart';
import '../utils/theme_provider.dart';
import '../utils/app_localizations.dart';

class FontSelectionScreen extends StatefulWidget {
  const FontSelectionScreen({super.key});

  @override
  State<FontSelectionScreen> createState() => _FontSelectionScreenState();
}

class _FontSelectionScreenState extends State<FontSelectionScreen> {
  late String _selectedFont;

  @override
  void initState() {
    super.initState();
    _loadSelectedFont();
  }

  Future<void> _loadSelectedFont() async {
    final prefs = await SharedPreferences.getInstance();
    final font = prefs.getString('font_family') ?? 'Georgia'; // Default font
    setState(() => _selectedFont = font);
  }

  Future<void> _saveFont(String fontFamily) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_family', fontFamily);

    // Update the theme provider
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    await themeProvider.setFontFamily(fontFamily);

    setState(() => _selectedFont = fontFamily);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.font_download, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${AppLocalizations.of(context).t('settings.fontSelected')} $fontFamily',
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryBlue,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  TextStyle _getPreviewStyle(String fontFamily) {
    switch (fontFamily) {
      case 'Georgia':
        return GoogleFonts.lora(fontSize: 16, fontWeight: FontWeight.normal);
      case 'Open Sans':
        return GoogleFonts.openSans(
          fontSize: 16,
          fontWeight: FontWeight.normal,
        );
      case 'Poppins':
        return GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.normal);
      case 'Playfair Display':
        return GoogleFonts.playfairDisplay(
          fontSize: 16,
          fontWeight: FontWeight.normal,
        );
      case 'Inter':
        return GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.normal);
      case 'Courier Prime':
        return GoogleFonts.courierPrime(
          fontSize: 16,
          fontWeight: FontWeight.normal,
        );
      case 'Roboto Mono':
        return GoogleFonts.robotoMono(
          fontSize: 16,
          fontWeight: FontWeight.normal,
        );
      default: // Roboto
        return GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.normal);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.backgroundGradientStartFromContext(context),
            AppTheme.backgroundGradientEndFromContext(context),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: AppTheme.textPrimaryFromContext(context),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: AppTheme.primaryGradient,
            ).createShader(bounds),
            child: Text(
              AppLocalizations.of(context).t('settings.font'),
              style: AppTheme.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCardFromContext(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.textTertiaryFromContext(
                        context,
                      ).withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  padding: EdgeInsets.all(AppTheme.spaceLg),
                  child: Text(
                    AppLocalizations.of(context).t('settings.fontDescription'),
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondaryFromContext(context),
                    ),
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Font Selection Cards
                Text(
                  AppLocalizations.of(context).t('settings.selectFont'),
                  style: AppTheme.headlineSmall.copyWith(
                    color: AppTheme.textPrimaryFromContext(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppTheme.spaceMd),

                ...AppTheme.availableFonts.map((font) {
                  final isSelected = _selectedFont == font;
                  return Padding(
                    padding: EdgeInsets.only(bottom: AppTheme.spaceMd),
                    child: GestureDetector(
                      onTap: () => _saveFont(font),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCardFromContext(context),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryBlue
                                : AppTheme.textTertiaryFromContext(
                                    context,
                                  ).withValues(alpha: 0.2),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        padding: EdgeInsets.all(AppTheme.spaceMd),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Font name and selection indicator
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  font,
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.textPrimaryFromContext(
                                      context,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: AppTheme.primaryGradient,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    padding: EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: AppTheme.spaceMd),

                            // Preview text in selected font
                            Text(
                              AppLocalizations.of(
                                context,
                              ).t('settings.livePreview'),
                              style: _getPreviewStyle(font).copyWith(
                                color: AppTheme.textSecondaryFromContext(
                                  context,
                                ),
                              ),
                            ),
                            SizedBox(height: AppTheme.spaceSm),

                            // Sample text
                            Text(
                              'The quick brown fox jumps over the lazy dog',
                              style: _getPreviewStyle(font).copyWith(
                                fontSize: 13,
                                color: AppTheme.textTertiaryFromContext(
                                  context,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),

                SizedBox(height: AppTheme.spaceXl),

                // Accessibility tip
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.accentGradient.first.withValues(
                      alpha: 0.08,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppTheme.primaryBlue,
                            size: 20,
                          ),
                          SizedBox(width: AppTheme.spaceMd),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(
                                context,
                              ).t('settings.accessibilityTip'),
                              style: AppTheme.labelMedium.copyWith(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppTheme.spaceMd),
                      Text(
                        AppLocalizations.of(
                          context,
                        ).t('settings.fontAccessibilityInfo'),
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondaryFromContext(context),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppTheme.spaceXl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
