import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/theme.dart';
import '../utils/theme_provider.dart';
import '../utils/language_provider.dart';
import '../utils/app_localizations.dart';
import '../services/settings_service.dart';
import '../services/user_profile_service.dart';
import '../services/onboarding_service.dart';
import '../widgets/social_media_icons.dart';

class SettingsScreenNew extends StatefulWidget {
  const SettingsScreenNew({super.key});

  @override
  State<SettingsScreenNew> createState() => _SettingsScreenNewState();
}

class _SettingsScreenNewState extends State<SettingsScreenNew> {
  late SettingsService _settingsService;
  late UserProfileService _userProfileService;
  String _colorMode = 'dark';
  String _username = 'User';

  @override
  void initState() {
    super.initState();
    _settingsService = SettingsService.instance;
    _userProfileService = UserProfileService.instance;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settingsService.init();
    await _userProfileService.init();

    final colorMode = await _settingsService.getColorMode();
    final username = await _userProfileService.getDisplayName();

    setState(() {
      _colorMode = colorMode;
      _username = username;
    });
  }

  Future<void> _setColorMode(String mode) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    await themeProvider.setThemeMode(mode);
    await _settingsService.setColorMode(mode);
    setState(() => _colorMode = mode);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Color mode updated to ${mode == 'dark' ? 'dark' : 'light'}',
          ),
          backgroundColor: AppTheme.primaryBlue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _sectionHeader(String text) => Padding(
    padding: EdgeInsets.fromLTRB(
      AppTheme.spaceMd,
      AppTheme.spaceLg,
      AppTheme.spaceMd,
      AppTheme.spaceSm,
    ),
    child: Text(
      text.toUpperCase(),
      style: AppTheme.labelMediumFromContext(
        context,
      ).copyWith(letterSpacing: 1.5),
    ),
  );

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    List<Color>? gradient,
  }) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient ?? AppTheme.surfaceGradient,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          boxShadow: gradient != null
              ? [
                  BoxShadow(
                    color: gradient[0].withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 22),
      ),
      title: Text(
        title,
        style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
            )
          : null,
      trailing:
          trailing ??
          Icon(Icons.chevron_right, color: AppTheme.textTertiary, size: 20),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppTheme.spaceSm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppTheme.surfaceGradientFromContext(context),
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.surfaceElevatedFromContext(
            context,
          ).withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.surfaceElevated.withValues(alpha: 0.3),
      indent: AppTheme.spaceMd,
      endIndent: AppTheme.spaceMd,
    );
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
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: AppTheme.glassGradientFromContext(context),
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.surfaceElevatedFromContext(
                    context,
                  ).withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
            ),
          ),
          title: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: AppTheme.primaryGradient,
            ).createShader(bounds),
            child: Text(
              AppLocalizations.of(context).t('settings.title'),
              style: AppTheme.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.only(bottom: AppTheme.spaceLg),
            children: [
              // Profile Section
              _sectionHeader(
                AppLocalizations.of(context).t('settings.account'),
              ),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.person,
                    title: AppLocalizations.of(context).t('nav.profile'),
                    subtitle: 'Username: $_username',
                    gradient: AppTheme.accentGradient,
                    onTap: () =>
                        Navigator.pushNamed(context, '/profile-settings'),
                  ),
                ],
              ),

              // Billing Section
              _sectionHeader(
                AppLocalizations.of(context).t('settings.subscription'),
              ),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.credit_card,
                    title: AppLocalizations.of(context).t('settings.billing'),
                    subtitle: AppLocalizations.of(
                      context,
                    ).t('settings.manageSubscription'),
                    gradient: AppTheme.primaryGradient,
                    onTap: () => Navigator.pushNamed(context, '/billing'),
                  ),
                ],
              ),

              // Capabilities Section
              _sectionHeader(
                AppLocalizations.of(context).t('settings.capabilities'),
              ),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.settings_suggest,
                    title: AppLocalizations.of(
                      context,
                    ).t('settings.capabilities'),
                    subtitle: AppLocalizations.of(
                      context,
                    ).t('settings.appFeatures'),
                    onTap: () => Navigator.pushNamed(context, '/capabilities'),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.notifications_active,
                    title: AppLocalizations.of(
                      context,
                    ).t('settings.notificationSettings'),
                    subtitle: AppLocalizations.of(
                      context,
                    ).t('settings.manageNotifications'),
                    onTap: () =>
                        Navigator.pushNamed(context, '/notification-settings'),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.school_outlined,
                    title: AppLocalizations.of(
                      context,
                    ).t('settings.showOnboarding'),
                    subtitle: AppLocalizations.of(
                      context,
                    ).t('settings.viewWalkthrough'),
                    onTap: () {
                      _showOnboardingConfirmation();
                    },
                  ),
                ],
              ),

              // Permissions Section
              _sectionHeader(
                AppLocalizations.of(context).t('settings.permissions'),
              ),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.security,
                    title: AppLocalizations.of(
                      context,
                    ).t('settings.permissions'),
                    subtitle: AppLocalizations.of(
                      context,
                    ).t('settings.appPermissions'),
                    onTap: () => Navigator.pushNamed(context, '/permissions'),
                  ),
                ],
              ),

              // Appearance Section
              _sectionHeader(
                AppLocalizations.of(context).t('settings.appearance'),
              ),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.palette,
                    title: AppLocalizations.of(context).t('settings.colorMode'),
                    subtitle: _colorMode == 'dark'
                        ? AppLocalizations.of(context).t('settings.dark')
                        : AppLocalizations.of(context).t('settings.light'),
                    trailing: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppTheme.primaryGradient,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _colorMode == 'dark'
                            ? AppLocalizations.of(
                                context,
                              ).t('settings.dark').toUpperCase()
                            : AppLocalizations.of(
                                context,
                              ).t('settings.light').toUpperCase(),
                        style: AppTheme.labelSmall.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onTap: () => _showColorModeDialog(),
                  ),
                ],
              ),

              // Language Section
              _sectionHeader(
                AppLocalizations.of(context).t('settings.language'),
              ),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.language,
                    title: AppLocalizations.of(
                      context,
                    ).t('settings.appLanguage'),
                    subtitle: _getLanguageSubtitle(),
                    gradient: AppTheme.accentGradient,
                    onTap: () => _showLanguageDialog(),
                  ),
                ],
              ),

              // Speech Language Section
              _sectionHeader(AppLocalizations.of(context).t('settings.speech')),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.record_voice_over,
                    title: AppLocalizations.of(
                      context,
                    ).t('settings.speechLanguage'),
                    subtitle: AppLocalizations.of(
                      context,
                    ).t('settings.voiceSettings'),
                    onTap: () =>
                        Navigator.pushNamed(context, '/speech-language'),
                  ),
                ],
              ),

              // Privacy Section
              _sectionHeader(
                AppLocalizations.of(context).t('settings.privacy'),
              ),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.privacy_tip,
                    title: AppLocalizations.of(context).t('settings.privacy'),
                    subtitle: AppLocalizations.of(
                      context,
                    ).t('settings.privacySettings'),
                    onTap: () => Navigator.pushNamed(context, '/privacy'),
                  ),
                ],
              ),

              // Contact Us Section (visually separated)
              SizedBox(height: AppTheme.spaceLg),
              _sectionHeader(
                AppLocalizations.of(context).t('settings.contactUs'),
              ),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.message,
                    title: AppLocalizations.of(
                      context,
                    ).t('settings.whatsappCommunity'),
                    subtitle: AppLocalizations.of(
                      context,
                    ).t('settings.joinWhatsapp'),
                    trailing: SocialMediaIcon(platform: 'whatsapp', size: 32),
                    onTap: () => _launchUrl(
                      'https://chat.whatsapp.com/BSwumdCdeLF7txFxw3jGdW',
                    ),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.thumb_up,
                    title: AppLocalizations.of(
                      context,
                    ).t('settings.facebookPage'),
                    subtitle: AppLocalizations.of(
                      context,
                    ).t('settings.followFacebook'),
                    trailing: SocialMediaIcon(platform: 'facebook', size: 32),
                    onTap: () => _launchUrl(
                      'https://www.facebook.com/share/17untMVSDD/',
                    ),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.camera_alt,
                    title: AppLocalizations.of(
                      context,
                    ).t('settings.instagramProfile'),
                    subtitle: AppLocalizations.of(
                      context,
                    ).t('settings.followInstagram'),
                    trailing: SocialMediaIcon(platform: 'instagram', size: 32),
                    onTap: () => _launchUrl(
                      'https://www.instagram.com/nexasmartai?igsh=YTJ1eGlneGxtZ2Zn',
                    ),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.music_video,
                    title: AppLocalizations.of(
                      context,
                    ).t('settings.tiktokPage'),
                    subtitle: AppLocalizations.of(
                      context,
                    ).t('settings.followTiktok'),
                    trailing: SocialMediaIcon(platform: 'tiktok', size: 32),
                    onTap: () => _launchUrl(
                      'https://www.tiktok.com/@nexa.2035?_r=1&_t=ZM-93F28qgfiV2',
                    ),
                  ),
                ],
              ),

              SizedBox(height: AppTheme.spaceLg),
            ],
          ),
        ),
      ),
    );
  }

  String _getLanguageSubtitle() {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    final langCode = languageProvider.currentLanguageCode;
    return LanguageProvider.languageNames[langCode] ?? langCode;
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final languageProvider = Provider.of<LanguageProvider>(
          context,
          listen: false,
        );
        final currentLang = languageProvider.currentLanguageCode;

        return AlertDialog(
          backgroundColor: isDark
              ? AppTheme.surfaceElevated
              : Color(0xFFFFFFFF),
          surfaceTintColor: isDark ? null : Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: BorderSide(
              color: isDark ? AppTheme.surfaceElevated : Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          title: Text(
            AppLocalizations.of(context).t('settings.selectLanguageTitle'),
            style: AppTheme.headlineMedium.copyWith(
              color: isDark ? AppTheme.textPrimary : Color(0xFF000000),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: LanguageProvider.languageNames.entries.map((entry) {
              final langCode = entry.key;
              final langName = entry.value;
              final isSelected = currentLang == langCode;

              return InkWell(
                onTap: () {
                  languageProvider.setLanguage(langCode);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Container(
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  margin: EdgeInsets.only(bottom: AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(colors: AppTheme.primaryGradient)
                        : LinearGradient(
                            colors: isDark
                                ? AppTheme.surfaceGradient
                                : [Color(0xFFF3F4F6), Color(0xFFF9FAFB)],
                          ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryBlue
                          : (isDark
                                ? AppTheme.surfaceElevated
                                : Color(0xFFE5E7EB)),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.language,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                  ? AppTheme.textPrimary
                                  : Color(0xFF1F2937)),
                        size: 24,
                      ),
                      SizedBox(width: AppTheme.spaceMd),
                      Text(
                        langName,
                        style: AppTheme.bodyLarge.copyWith(
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                    ? AppTheme.textPrimary
                                    : Color(0xFF000000)),
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      Spacer(),
                      if (isSelected)
                        Icon(Icons.check_circle, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showColorModeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark
              ? AppTheme.surfaceElevated
              : Color(0xFFFFFFFF),
          surfaceTintColor: isDark ? null : Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: BorderSide(
              color: isDark ? AppTheme.surfaceElevated : Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          title: Text(
            AppLocalizations.of(context).t('settings.colorMode'),
            style: AppTheme.headlineMedium.copyWith(
              color: isDark ? AppTheme.textPrimary : Color(0xFF000000),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildColorOption(
                AppLocalizations.of(context).t('settings.light'),
                'light',
                Icons.light_mode,
                isDark,
              ),
              SizedBox(height: AppTheme.spaceSm),
              _buildColorOption(
                AppLocalizations.of(context).t('settings.dark'),
                'dark',
                Icons.dark_mode,
                isDark,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColorOption(
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _colorMode == value;
    return InkWell(
      onTap: () {
        _setColorMode(value);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: AppTheme.primaryGradient)
              : LinearGradient(
                  colors: isDark
                      ? AppTheme.surfaceGradient
                      : [Color(0xFFF3F4F6), Color(0xFFF9FAFB)],
                ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBlue
                : (isDark ? AppTheme.surfaceElevated : Color(0xFFE5E7EB)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppTheme.textPrimary : Color(0xFF1F2937)),
              size: 24,
            ),
            SizedBox(width: AppTheme.spaceMd),
            Text(
              label,
              style: AppTheme.bodyLarge.copyWith(
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppTheme.textPrimary : Color(0xFF000000)),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch $url'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching link: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showOnboardingConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.school_outlined, color: AppTheme.warning, size: 24),
              SizedBox(width: 12),
              Text(
                'Show Onboarding Guide',
                style: AppTheme.headlineSmall.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            'This will reset your onboarding progress and show you the app introduction guide again. Would you like to continue?',
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await OnboardingService.resetOnboarding();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Onboarding reset! Go to the main screen to see the guide.',
                      ),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Show Guide',
                style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
}
