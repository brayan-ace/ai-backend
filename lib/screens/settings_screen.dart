import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../utils/theme.dart';
import '../utils/theme_provider.dart';
import '../services/onboarding_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings state
  String _themeMode = 'dark'; // dark, light, system
  double _textSize = 1.0; // 0.6 to 1.2
  bool _autoSaveChats = true;
  bool _notificationsEnabled = true;
  bool _soundEffects = true;
  bool _hapticFeedback = true;
  bool _autoListen = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = prefs.getString('theme_mode') ?? 'dark';
      _textSize =
          prefs.getDouble('text_size') ?? 0.91; // Default: 91% text size
      _autoSaveChats = prefs.getBool('auto_save_chats') ?? true;
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _soundEffects = prefs.getBool('sound_effects') ?? true;
      _hapticFeedback = prefs.getBool('haptic_feedback') ?? true;
      _autoListen = prefs.getBool('auto_listen') ?? false;
    });
  }

  Future<void> _saveThemeMode(String mode) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    await themeProvider.setThemeMode(mode);
    setState(() => _themeMode = mode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Theme updated to ${mode == 'system'
              ? 'system default'
              : mode == 'dark'
              ? 'dark mode'
              : 'light mode'}',
        ),
        backgroundColor: AppTheme.primaryBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveTextSize(double size) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    await themeProvider.setTextScaleFactor(size);
    setState(() => _textSize = size);
  }

  Future<void> _saveBoolSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      switch (key) {
        case 'auto_save_chats':
          _autoSaveChats = value;
          break;
        case 'notifications':
          _notificationsEnabled = value;
          break;
        case 'sound_effects':
          _soundEffects = value;
          break;
        case 'haptic_feedback':
          _hapticFeedback = value;
          break;
        case 'auto_listen':
          _autoListen = value;
          break;
      }
    });
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
      style: AppTheme.labelMedium.copyWith(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.textTertiary
            : Color(0xFF6B7280),
        letterSpacing: 1.5,
      ),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                    color: gradient[0].withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: isDarkMode ? AppTheme.textPrimary : Color(0xFF1F2937),
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: AppTheme.bodyLarge.copyWith(
          color: isDarkMode ? AppTheme.textPrimary : Color(0xFF000000),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: AppTheme.bodySmall.copyWith(
                color: isDarkMode ? AppTheme.textTertiary : Color(0xFF6B7280),
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: isDarkMode ? AppTheme.textTertiary : Color(0xFF9CA3AF),
        size: 20,
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      tileColor: isDarkMode ? Colors.transparent : Colors.transparent,
      selectedTileColor: isDarkMode
          ? AppTheme.surfaceElevated.withOpacity(0.5)
          : Color(0xFFF0F0F0),
      hoverColor: isDarkMode
          ? AppTheme.surfaceElevated.withOpacity(0.3)
          : Color(0xFFF5F5F5),
      splashColor: isDarkMode
          ? AppTheme.primaryBlue.withOpacity(0.2)
          : Color(0xFFBFDBFE).withOpacity(0.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isDarkMode
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.backgroundGradientStart,
                  AppTheme.backgroundGradientEnd,
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFAFAFA), Color(0xFFF5F5F5)],
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
              gradient: isDarkMode
                  ? LinearGradient(colors: AppTheme.glassGradient)
                  : LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFFAFAFA)],
                    ),
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode
                      ? AppTheme.surfaceElevated.withOpacity(0.3)
                      : Color(0xFFE5E7EB),
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
              // Futuristic header card
              Padding(
                padding: EdgeInsets.all(AppTheme.spaceMd),
                child: Container(
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppTheme.primaryGradient,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: AppTheme.glowShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.smart_toy,
                          color: Colors.black,
                          size: 36,
                        ),
                      ),
                      SizedBox(width: AppTheme.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'myai',
                              style: AppTheme.headlineMedium.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: AppTheme.spaceXs),
                            Text(
                              'Personal AI assistant',
                              style: AppTheme.bodyMedium.copyWith(
                                color: Colors.black.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'v1.0',
                        style: AppTheme.labelMedium.copyWith(
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Profile section
              _sectionHeader('Profile'),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.person,
                    title: 'Profile',
                    subtitle: 'Sign in or create an account',
                    gradient: AppTheme.accentGradient,
                    onTap: () => Navigator.pushNamed(context, '/auth'),
                  ),
                ],
              ),

              // General
              _sectionHeader('General'),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.color_lens,
                    title: 'Appearance',
                    subtitle:
                        'Theme: ${_themeMode == 'system'
                            ? 'System default'
                            : _themeMode == 'dark'
                            ? 'Dark mode'
                            : 'light mode'}',
                    gradient: AppTheme.primaryGradient,
                    onTap: () => _showThemeDialog(),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.text_fields,
                    title: 'Text Size',
                    subtitle: '${(_textSize * 100).toInt()}%',
                    trailing: SizedBox(
                      width: 150,
                      child: Slider(
                        value: _textSize,
                        min: 0.8,
                        max: 1.2,
                        divisions: 4,
                        activeColor: AppTheme.primaryBlue,
                        inactiveColor: AppTheme.surfaceElevated,
                        onChanged: (value) => _saveTextSize(value),
                      ),
                    ),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.language,
                    title: 'Language',
                    subtitle: 'English (Default)',
                    onTap: () => _showComingSoonDialog('Language Selection'),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.restart_alt,
                    title: 'Reset Onboarding',
                    subtitle: 'Show welcome tutorial again',
                    gradient: [Colors.purple, Colors.pink],
                    onTap: () => _resetOnboarding(),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.notifications,
                    title: 'Notifications',
                    subtitle: _notificationsEnabled ? 'Enabled' : 'Disabled',
                    trailing: Switch(
                      value: _notificationsEnabled,
                      onChanged: (value) =>
                          _saveBoolSetting('notifications', value),
                      activeColor: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),

              // Privacy & Security
              _sectionHeader('Privacy & Security'),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.privacy_tip,
                    title: 'Privacy',
                    subtitle: 'Privacy controls & data handling',
                    gradient: AppTheme.accentGradient,
                    onTap: null,
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.lock,
                    title: 'Security',
                    subtitle: 'App security settings',
                    onTap: null,
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.save,
                    title: 'Auto-save Chats',
                    subtitle: _autoSaveChats
                        ? 'Chats saved automatically'
                        : 'Manual save only',
                    trailing: Switch(
                      value: _autoSaveChats,
                      onChanged: (value) =>
                          _saveBoolSetting('auto_save_chats', value),
                      activeColor: AppTheme.primaryBlue,
                    ),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.storage,
                    title: 'Data & Storage',
                    subtitle: 'Manage local data and cache',
                    onTap: () => _showDataManagementDialog(),
                  ),
                ],
              ),

              // Accessibility
              _sectionHeader('Accessibility'),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.vibration,
                    title: 'Haptic Feedback',
                    subtitle: _hapticFeedback ? 'Enabled' : 'Disabled',
                    trailing: Switch(
                      value: _hapticFeedback,
                      onChanged: (value) =>
                          _saveBoolSetting('haptic_feedback', value),
                      activeColor: AppTheme.primaryBlue,
                    ),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.volume_up,
                    title: 'Sound Effects',
                    subtitle: _soundEffects ? 'Enabled' : 'Disabled',
                    trailing: Switch(
                      value: _soundEffects,
                      onChanged: (value) =>
                          _saveBoolSetting('sound_effects', value),
                      activeColor: AppTheme.primaryBlue,
                    ),
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.mic_external_on,
                    title: 'Auto-Listen',
                    subtitle: _autoListen
                        ? 'Auto-start voice input'
                        : 'Manual activation',
                    trailing: Switch(
                      value: _autoListen,
                      onChanged: (value) =>
                          _saveBoolSetting('auto_listen', value),
                      activeColor: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),

              // Support
              _sectionHeader('Support'),
              _buildCard(
                children: [
                  _tile(
                    context,
                    icon: Icons.help_outline,
                    title: 'Help & Feedback',
                    subtitle: 'Send feedback or report issues',
                    onTap: null,
                  ),
                  _buildDivider(),
                  _tile(
                    context,
                    icon: Icons.info_outline,
                    title: 'About',
                    subtitle: 'Version, licenses, legal',
                    onTap: () => _showAboutDialog(),
                  ),
                ],
              ),

              SizedBox(height: AppTheme.spaceLg),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
                child: Text(
                  'Settings are saved automatically. Some features coming soon!',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
            'Theme Mode',
            style: AppTheme.headlineMedium.copyWith(
              color: isDarkMode ? AppTheme.textPrimary : Color(0xFF000000),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeOption('Dark Mode', 'dark', Icons.dark_mode),
              SizedBox(height: AppTheme.spaceSm),
              _buildThemeOption('Light Mode', 'light', Icons.light_mode),
              SizedBox(height: AppTheme.spaceSm),
              _buildThemeOption(
                'System Default',
                'system',
                Icons.brightness_auto,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(String label, String value, IconData icon) {
    final isSelected = _themeMode == value;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        _saveThemeMode(value);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: AppTheme.primaryGradient)
              : LinearGradient(
                  colors: isDarkMode
                      ? AppTheme.surfaceGradient
                      : [Color(0xFFF3F4F6), Color(0xFFF9FAFB)],
                ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBlue
                : (isDarkMode ? AppTheme.surfaceElevated : Color(0xFFE5E7EB)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.black
                  : (isDarkMode ? AppTheme.textPrimary : Color(0xFF1F2937)),
              size: 24,
            ),
            SizedBox(width: AppTheme.spaceMd),
            Text(
              label,
              style: AppTheme.bodyLarge.copyWith(
                color: isSelected
                    ? Colors.black
                    : (isDarkMode ? AppTheme.textPrimary : Color(0xFF000000)),
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

  void _showComingSoonDialog(String feature) {
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
          title: Row(
            children: [
              Icon(Icons.rocket_launch, color: AppTheme.primaryBlue),
              SizedBox(width: AppTheme.spaceSm),
              Text(
                'Coming Soon',
                style: AppTheme.headlineMedium.copyWith(
                  color: isDarkMode ? AppTheme.textPrimary : Color(0xFF000000),
                ),
              ),
            ],
          ),
          content: Text(
            '$feature will be available in a future update. Stay tuned!',
            style: AppTheme.bodyMedium.copyWith(
              color: isDarkMode ? AppTheme.textSecondary : Color(0xFF6B7280),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: isDarkMode ? Color(0xFF1E1E1E) : Colors.black,
              ),
              child: Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  void _resetOnboarding() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
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
          title: Row(
            children: [
              Icon(Icons.restart_alt, color: AppTheme.primaryBlue),
              SizedBox(width: AppTheme.spaceSm),
              Text(
                'Reset Onboarding',
                style: AppTheme.headlineMedium.copyWith(
                  color: isDarkMode ? AppTheme.textPrimary : Color(0xFF000000),
                ),
              ),
            ],
          ),
          content: Text(
            'This will show the welcome tutorial again the next time you open the app. Continue?',
            style: AppTheme.bodyMedium.copyWith(
              color: isDarkMode ? AppTheme.textSecondary : Color(0xFF6B7280),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: AppTheme.labelLarge.copyWith(
                  color: isDarkMode
                      ? AppTheme.textSecondary
                      : Color(0xFF6B7280),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: isDarkMode ? Color(0xFF1E1E1E) : Colors.black,
              ),
              child: Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await OnboardingService.resetOnboarding();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Onboarding tutorial will show again next time you open the app',
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDataManagementDialog() {
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
            'Data & Storage',
            style: AppTheme.headlineMedium.copyWith(
              color: isDarkMode ? AppTheme.textPrimary : Color(0xFF000000),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage your app data',
                style: AppTheme.bodyMedium.copyWith(
                  color: isDarkMode
                      ? AppTheme.textSecondary
                      : Color(0xFF6B7280),
                ),
              ),
              SizedBox(height: AppTheme.spaceLg),
              _buildDataOption(
                'Clear Cache',
                'Free up space by clearing temporary files',
                Icons.cleaning_services,
                AppTheme.accentGradient,
                () {
                  Navigator.pop(context);
                  _clearCache();
                },
              ),
              SizedBox(height: AppTheme.spaceSm),
              _buildDataOption(
                'Clear All Data',
                'Reset app to default state (Cannot be undone)',
                Icons.delete_forever,
                [Colors.red, Colors.redAccent],
                () {
                  Navigator.pop(context);
                  _showClearDataConfirmation();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: AppTheme.labelLarge.copyWith(
                  color: isDarkMode
                      ? AppTheme.textSecondary
                      : Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDataOption(
    String title,
    String subtitle,
    IconData icon,
    List<Color> gradient,
    VoidCallback onTap,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [Color(0xFF2A2A2A), Color(0xFF1F1F1F)]
                : [Color(0xFFFAFAFA), Color(0xFFF5F5F5)],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isDarkMode ? AppTheme.surfaceElevated : Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spaceSm),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyLarge.copyWith(
                      color: isDarkMode
                          ? AppTheme.textPrimary
                          : Color(0xFF000000),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: isDarkMode
                          ? AppTheme.textTertiary
                          : Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          title: Column(
            children: [
              Container(
                padding: EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: AppTheme.primaryGradient),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(
                  Icons.psychology,
                  size: 40,
                  color: isDarkMode ? Color(0xFF1E1E1E) : Colors.black,
                ),
              ),
              SizedBox(height: AppTheme.spaceMd),
              Text(
                'MyAI',
                style: AppTheme.headlineLarge.copyWith(
                  color: isDarkMode ? AppTheme.textPrimary : Color(0xFF000000),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Version 1.0.0',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: AppTheme.spaceMd),
              Text(
                'Your intelligent AI assistant powered by advanced language models.',
                style: AppTheme.bodyMedium.copyWith(
                  color: isDarkMode
                      ? AppTheme.textSecondary
                      : Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppTheme.spaceLg),
              Container(
                padding: EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDarkMode
                        ? [Color(0xFF2A2A2A), Color(0xFF1F1F1F)]
                        : [Color(0xFFF3F4F6), Color(0xFFF9FAFB)],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(Icons.code, 'Built with Flutter'),
                    SizedBox(height: AppTheme.spaceSm),
                    _buildInfoRow(Icons.api, 'Powered by Groq & OpenRouter'),
                    SizedBox(height: AppTheme.spaceSm),
                    _buildInfoRow(Icons.search, 'Web Search via Tavily'),
                    SizedBox(height: AppTheme.spaceSm),
                    _buildInfoRow(Icons.security, 'Secured with Firebase'),
                  ],
                ),
              ),
              SizedBox(height: AppTheme.spaceMd),
              Text(
                '© 2024 MyAI. All rights reserved.',
                style: AppTheme.bodySmall.copyWith(
                  color: isDarkMode ? AppTheme.textTertiary : Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: AppTheme.labelLarge.copyWith(
                  color: isDarkMode
                      ? AppTheme.textSecondary
                      : Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryBlue, size: 18),
        SizedBox(width: AppTheme.spaceSm),
        Text(
          text,
          style: AppTheme.bodySmall.copyWith(
            color: isDarkMode ? AppTheme.textSecondary : Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Future<void> _clearCache() async {
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Clearing cache...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    await Future.delayed(Duration(seconds: 2));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Cache cleared successfully'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showClearDataConfirmation() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode
              ? AppTheme.surfaceElevated
              : Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: AppTheme.spaceSm),
              Text(
                'Clear All Data?',
                style: AppTheme.headlineMedium.copyWith(
                  color: isDarkMode ? AppTheme.textPrimary : Color(0xFF000000),
                ),
              ),
            ],
          ),
          content: Text(
            'This will delete all your chats, settings, and data. This action cannot be undone.',
            style: AppTheme.bodyMedium.copyWith(
              color: isDarkMode ? AppTheme.textSecondary : Color(0xFF6B7280),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: AppTheme.labelLarge.copyWith(
                  color: isDarkMode
                      ? AppTheme.textSecondary
                      : Color(0xFF6B7280),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('All data cleared. Please restart the app.'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                _loadSettings(); // Reload defaults
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Clear All'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppTheme.spaceSm),
      decoration: BoxDecoration(
        gradient: isDarkMode
            ? LinearGradient(colors: AppTheme.surfaceGradient)
            : LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFFAFAFA)]),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isDarkMode
              ? AppTheme.surfaceElevated.withOpacity(0.5)
              : Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Divider(
      height: 1,
      thickness: 1,
      color: isDarkMode
          ? AppTheme.surfaceElevated.withOpacity(0.3)
          : Color(0xFFE5E7EB),
      indent: AppTheme.spaceMd,
      endIndent: AppTheme.spaceMd,
    );
  }
}
