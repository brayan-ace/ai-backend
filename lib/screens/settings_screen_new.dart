import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/theme.dart';
import '../utils/theme_provider.dart';
import 'theme_selection_screen.dart';
import 'language_selection_screen.dart';
import '../utils/language_provider.dart';
import '../utils/app_localizations.dart';
import '../services/settings_service.dart';
import '../services/user_profile_service.dart';
import '../services/push_notification_service.dart';
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
  late PushNotificationService _notificationService;
  String _colorMode = 'dark';
  String _username = 'User';
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _settingsService = SettingsService.instance;
    _userProfileService = UserProfileService.instance;
    _notificationService = PushNotificationService();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settingsService.init();
    await _userProfileService.init();

    final colorMode = await _settingsService.getColorMode();
    final username = await _userProfileService.getDisplayName();
    final notificationsEnabled = await _notificationService
        .getNotificationsEnabled();

    setState(() {
      _colorMode = colorMode;
      _username = username;
      _notificationsEnabled = notificationsEnabled;
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

  /// Toggle notifications on/off with robust error handling and reinitialization
  Future<void> _toggleNotifications(bool enabled) async {
    try {
      setState(() => _notificationsEnabled = enabled);

      if (enabled) {
        // When enabling, ensure notification service is fully initialized
        // This is critical for proper scheduling
        print('[Settings] Initializing notification service...');
        await _notificationService.initialize();

        // Wait a moment for initialization to complete
        await Future.delayed(Duration(milliseconds: 300));

        // Now save the enabled state
        await _notificationService.setNotificationsEnabled(true);
        print('[Settings] Notification service re-initialized and enabled');
      } else {
        // Disable notifications
        await _notificationService.setNotificationsEnabled(false);
        print('[Settings] Notifications disabled');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  enabled
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  enabled ? 'Notifications enabled' : 'Notifications disabled',
                ),
              ],
            ),
            backgroundColor: enabled ? AppTheme.success : AppTheme.textTertiary,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      print(
        '[Settings] Notifications ${enabled ? 'enabled' : 'disabled'} successfully',
      );
    } catch (e) {
      // Revert state on error
      setState(() => _notificationsEnabled = !enabled);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Failed to update notifications: $e')),
              ],
            ),
            backgroundColor: AppTheme.error,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      print('[Settings] Error toggling notifications: $e');
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
    final iconColor = gradient != null
        ? Colors.white
        : AppTheme.textPrimaryFromContext(context);
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient ?? AppTheme.surfaceGradientFromContext(context),
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
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: AppTheme.bodyLarge.copyWith(
          color: AppTheme.textPrimaryFromContext(context),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textTertiaryFromContext(context),
              ),
            )
          : null,
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right,
            color: AppTheme.textTertiaryFromContext(context),
            size: 20,
          ),
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
      color: AppTheme.surfaceElevatedFromContext(
        context,
      ).withValues(alpha: 0.3),
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
        extendBodyBehindAppBar: false,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
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
              // Premium Header with App Logo
              _buildPremiumHeader(context),

              // User Profile Card
              _buildUserProfileCard(context),

              // Access Plans / Subscription Card (Prominent)
              _buildAccessPlansCard(context),

              // GENERAL SETTINGS Section
              _sectionHeader(
                AppLocalizations.of(context).t('settings.general'),
              ),
              _buildCard(
                children: [
                  // Edit Profile
                  _tile(
                    context,
                    icon: Icons.person,
                    title: AppLocalizations.of(context).t('nav.profile'),
                    subtitle: 'Manage your account',
                    gradient: AppTheme.accentGradient,
                    onTap: () =>
                        Navigator.pushNamed(context, '/profile-settings'),
                  ),
                  _buildDivider(),
                  // App Theme
                  _tile(
                    context,
                    icon: Icons.palette,
                    title: AppLocalizations.of(context).t('Theme'),
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
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ThemeSelectionScreen(),
                      ),
                    ),
                  ),
                  _buildDivider(),
                  // Notifications Toggle
                  _tile(
                    context,
                    icon: Icons.notifications_active,
                    title: AppLocalizations.of(context).t('notifications'),
                    subtitle: _notificationsEnabled
                        ? 'Notifications are enabled'
                        : 'Notifications are disabled',
                    trailing: Switch(
                      value: _notificationsEnabled,
                      onChanged: _toggleNotifications,
                      activeColor: AppTheme.primaryBlue,
                      inactiveThumbColor: AppTheme.textTertiary,
                    ),
                  ),
                  _buildDivider(),
                  // Language Selection
                  _tile(
                    context,
                    icon: Icons.language,
                    title: AppLocalizations.of(context).t('settings.language'),
                    subtitle: _getLanguageSubtitle(),
                    gradient: AppTheme.accentGradient,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LanguageSelectionScreen(),
                      ),
                    ),
                  ),
                  _buildDivider(),
                  // Logout
                  _tile(
                    context,
                    icon: Icons.logout,
                    title: AppLocalizations.of(context).t('settings.logout'),
                    subtitle: 'Securely sign out',
                    onTap: () => _showLogoutConfirmation(),
                  ),
                ],
              ),

              // App Features
              _sectionHeader(
                AppLocalizations.of(context).t('settings.appFeatures'),
              ),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.settings_suggest,
                    title: AppLocalizations.of(
                      context,
                    ).t('settings.capabilities'),
                    subtitle: 'Discover all features',
                    onTap: () => Navigator.pushNamed(context, '/capabilities'),
                  ),
                ],
              ),

              // CONNECT WITH US Section
              SizedBox(height: AppTheme.spaceLg),
              _sectionHeader(
                AppLocalizations.of(context).t('settings.connectWithUs'),
              ),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.message,
                    title: AppLocalizations.of(context).t('settings.whatsapp'),
                    subtitle: 'Join our community',
                    trailing: SocialMediaIcon(platform: 'whatsapp', size: 32),
                    onTap: () => _launchUrl(
                      'https://chat.whatsapp.com/BSwumdCdeLF7txFxw3jGdW',
                    ),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.thumb_up,
                    title: AppLocalizations.of(context).t('settings.facebook'),
                    subtitle: 'Follow us',
                    trailing: SocialMediaIcon(platform: 'facebook', size: 32),
                    onTap: () => _launchUrl(
                      'https://www.facebook.com/share/17untMVSDD/',
                    ),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.camera_alt,
                    title: AppLocalizations.of(context).t('settings.instagram'),
                    subtitle: 'Follow us',
                    trailing: SocialMediaIcon(platform: 'instagram', size: 32),
                    onTap: () => _launchUrl(
                      'https://www.instagram.com/nexasmartai?igsh=YTJ1eGlneGxtZ2Zn',
                    ),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.music_video,
                    title: AppLocalizations.of(context).t('settings.tiktok'),
                    subtitle: 'Follow us',
                    trailing: SocialMediaIcon(platform: 'tiktok', size: 32),
                    onTap: () => _launchUrl(
                      'https://www.tiktok.com/@nexa.2035?_r=1&_t=ZM-93F28qgfiV2',
                    ),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.language,
                    title: 'Visit Website',
                    subtitle: 'Explore our website',
                    onTap: () =>
                        _launchUrl('https://lucky-granita-36fd10.netlify.app/'),
                  ),
                ],
              ),

              // LEGAL & SUPPORT Section
              SizedBox(height: AppTheme.spaceLg),
              _sectionHeader(
                AppLocalizations.of(context).t('settings.legalAndSupport'),
              ),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.privacy_tip,
                    title: AppLocalizations.of(
                      context,
                    ).t('settings.privacyPolicy'),
                    onTap: () => _launchUrl(
                      'https://lucky-granita-36fd10.netlify.app/privacy',
                    ),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.description,
                    title: AppLocalizations.of(
                      context,
                    ).t('settings.termsOfService'),
                    onTap: () => _launchUrl(
                      'https://lucky-granita-36fd10.netlify.app/terms',
                    ),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.info_outline,
                    title: AppLocalizations.of(context).t('settings.about'),
                    onTap: () => _showAboutDialog(),
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

  /// Premium header with app logo
  Widget _buildPremiumHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppTheme.primaryGradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(8),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/app_icon.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SizedBox(height: AppTheme.spaceMd),
          Text(
            'Nexa Smart AI',
            style: AppTheme.headlineSmall.copyWith(
              color: AppTheme.textPrimaryFromContext(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppTheme.spaceXs),
          Text(
            AppLocalizations.of(context).t('settings.personalAIAssistant'),
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textTertiaryFromContext(context),
            ),
          ),
        ],
      ),
    );
  }

  /// User profile card showing name and email
  Widget _buildUserProfileCard(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      child: Container(
        padding: EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: AppTheme.primaryGradient),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: Icon(Icons.person_rounded, color: Colors.white, size: 35),
            ),
            SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _username,
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textPrimaryFromContext(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppTheme.spaceXs),
                  Text(
                    FirebaseAuth.instance.currentUser?.email ??
                        'user@example.com',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textTertiaryFromContext(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Access plans card - visually prominent
  Widget _buildAccessPlansCard(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/billing'),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: EdgeInsets.all(AppTheme.spaceLg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppTheme.primaryGradient,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).t('settings.upgradeNow'),
                      style: AppTheme.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: AppTheme.spaceXs),
                    Text(
                      AppLocalizations.of(
                        context,
                      ).t('settings.unlockPremiumFeatures'),
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppTheme.spaceMd),
              Container(
                padding: EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show logout confirmation
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceCardFromContext(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red, size: 24),
              SizedBox(width: 12),
              Text(
                AppLocalizations.of(context).t('settings.logout'),
                style: AppTheme.headlineSmall.copyWith(
                  color: AppTheme.textPrimaryFromContext(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            AppLocalizations.of(context).t('settings.logoutConfirm'),
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondaryFromContext(context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context).t('settings.cancel'),
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.textSecondaryFromContext(context),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _handleLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                AppLocalizations.of(context).t('settings.logout'),
                style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Handle logout
  Future<void> _handleLogout() async {
    // You can implement logout logic here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).t('settings.logoutSuccess')),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show about dialog
  void _showAboutDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode
              ? AppTheme.surfaceElevated
              : Color(0xFFFFFFFF),
          surfaceTintColor: isDarkMode ? null : Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: BorderSide(
              color: isDarkMode ? AppTheme.surfaceElevated : Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          title: Text(
            AppLocalizations.of(context).t('settings.aboutApp'),
            style: AppTheme.headlineMedium.copyWith(
              color: isDarkMode ? AppTheme.textPrimary : Color(0xFF000000),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nexa Smart AI',
                  style: AppTheme.bodyLarge.copyWith(
                    color: isDarkMode
                        ? AppTheme.textPrimary
                        : Color(0xFF000000),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: AppTheme.spaceSm),
                Text(
                  'Version 1.0.0',
                  style: AppTheme.bodyMedium.copyWith(
                    color: isDarkMode
                        ? AppTheme.textSecondary
                        : Color(0xFF6B7280),
                  ),
                ),
                SizedBox(height: AppTheme.spaceMd),
                Text(
                  AppLocalizations.of(context).t('settings.appDescription'),
                  style: AppTheme.bodyMedium.copyWith(
                    color: isDarkMode
                        ? AppTheme.textSecondary
                        : Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context).t('settings.close'),
                style: AppTheme.bodyLarge.copyWith(color: AppTheme.primaryBlue),
              ),
            ),
          ],
        );
      },
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
          backgroundColor: AppTheme.surfaceCardFromContext(context),
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
                  color: AppTheme.textPrimaryFromContext(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            'This will reset your onboarding progress and show you the app introduction guide again. Would you like to continue?',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondaryFromContext(context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.textSecondaryFromContext(context),
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
