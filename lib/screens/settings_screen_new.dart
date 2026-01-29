import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/theme.dart';
import '../utils/theme_provider.dart';
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
              'Settings',
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
              _sectionHeader('Account'),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.person,
                    title: 'Profile',
                    subtitle: 'Username: $_username',
                    gradient: AppTheme.accentGradient,
                    onTap: () =>
                        Navigator.pushNamed(context, '/profile-settings'),
                  ),
                ],
              ),

              // Billing Section
              _sectionHeader('Subscription'),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.credit_card,
                    title: 'Billing',
                    subtitle: 'Manage your subscription',
                    gradient: AppTheme.primaryGradient,
                    onTap: () => Navigator.pushNamed(context, '/billing'),
                  ),
                ],
              ),

              // Capabilities Section
              _sectionHeader('Capabilities'),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.settings_suggest,
                    title: 'Capabilities',
                    subtitle: 'App features and abilities',
                    onTap: () => Navigator.pushNamed(context, '/capabilities'),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.notifications_active,
                    title: 'Notification Settings',
                    subtitle: 'Manage push notifications',
                    onTap: () =>
                        Navigator.pushNamed(context, '/notification-settings'),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.school_outlined,
                    title: 'Show Onboarding',
                    subtitle: 'View app walkthrough',
                    onTap: () {
                      _showOnboardingConfirmation();
                    },
                  ),
                ],
              ),

              // Permissions Section
              _sectionHeader('Permissions'),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.security,
                    title: 'Permissions',
                    subtitle: 'App permissions',
                    onTap: () => Navigator.pushNamed(context, '/permissions'),
                  ),
                ],
              ),

              // Appearance Section
              _sectionHeader('Appearance'),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.palette,
                    title: 'Color Mode',
                    subtitle: _colorMode == 'dark' ? 'Dark' : 'Light',
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
                        _colorMode == 'dark' ? 'DARK' : 'LIGHT',
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

              // Speech Language Section
              _sectionHeader('Speech'),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.record_voice_over,
                    title: 'Speech Language',
                    subtitle: 'Voice settings',
                    onTap: () =>
                        Navigator.pushNamed(context, '/speech-language'),
                  ),
                ],
              ),

              // Privacy Section
              _sectionHeader('Privacy'),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.privacy_tip,
                    title: 'Privacy',
                    subtitle: 'Privacy settings',
                    onTap: () => Navigator.pushNamed(context, '/privacy'),
                  ),
                ],
              ),

              // Contact Us Section (visually separated)
              SizedBox(height: AppTheme.spaceLg),
              _sectionHeader('Contact Us'),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.message,
                    title: 'WhatsApp Community',
                    subtitle: 'Join our WhatsApp community',
                    trailing: SocialMediaIcon(platform: 'whatsapp', size: 32),
                    onTap: () => _launchUrl(
                      'https://chat.whatsapp.com/BSwumdCdeLF7txFxw3jGdW',
                    ),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.thumb_up,
                    title: 'Facebook Page',
                    subtitle: 'Follow us on Facebook',
                    trailing: SocialMediaIcon(platform: 'facebook', size: 32),
                    onTap: () => _launchUrl(
                      'https://www.facebook.com/share/17untMVSDD/',
                    ),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.camera_alt,
                    title: 'Instagram Profile',
                    subtitle: 'Follow us on Instagram',
                    trailing: SocialMediaIcon(platform: 'instagram', size: 32),
                    onTap: () => _launchUrl(
                      'https://www.instagram.com/nexasmartai?igsh=YTJ1eGlneGxtZ2Zn',
                    ),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.music_video,
                    title: 'TikTok Page',
                    subtitle: 'Follow us on TikTok',
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

  void _showColorModeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: Text(
            'Color Mode',
            style: AppTheme.headlineMedium.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildColorOption('Light', 'light', Icons.light_mode),
              SizedBox(height: AppTheme.spaceSm),
              _buildColorOption('Dark', 'dark', Icons.dark_mode),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColorOption(String label, String value, IconData icon) {
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
              : LinearGradient(colors: AppTheme.surfaceGradient),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : AppTheme.surfaceElevated,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : AppTheme.textPrimary,
              size: 24,
            ),
            SizedBox(width: AppTheme.spaceMd),
            Text(
              label,
              style: AppTheme.bodyLarge.copyWith(
                color: isSelected ? Colors.black : AppTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.black, size: 20),
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
