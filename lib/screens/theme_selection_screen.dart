import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme.dart';
import '../utils/theme_provider.dart';
import '../utils/app_localizations.dart';
import '../services/settings_service.dart';

class ThemeSelectionScreen extends StatefulWidget {
  const ThemeSelectionScreen({super.key});

  @override
  State<ThemeSelectionScreen> createState() => _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends State<ThemeSelectionScreen>
    with SingleTickerProviderStateMixin {
  late String _selectedTheme;
  late SettingsService _settingsService;
  late AnimationController _animationController;
  late Animation<double> _iconAnimation;

  @override
  void initState() {
    super.initState();
    _settingsService = SettingsService.instance;
    _selectedTheme = 'dark';
    _loadSettings();

    // Initialize animation controller for smooth transitions
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _iconAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  Future<void> _loadSettings() async {
    final colorMode = await _settingsService.getColorMode();
    setState(() => _selectedTheme = colorMode);
  }

  void _toggleTheme(String newTheme) {
    if (_selectedTheme != newTheme) {
      _animationController.forward(from: 0);
      setState(() => _selectedTheme = newTheme);
      _applyTheme(newTheme);
    }
  }

  Future<void> _applyTheme(String theme) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    await themeProvider.setThemeMode(theme);
    await _settingsService.setColorMode(theme);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                theme == 'dark' ? Icons.dark_mode : Icons.light_mode,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Theme changed to ${theme == 'dark' ? 'Dark' : 'Light'} mode',
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              Icons.arrow_back_ios_rounded,
              color: AppTheme.textPrimaryFromContext(context),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            AppLocalizations.of(context).t('appTheme'),
            style: AppTheme.headlineSmall.copyWith(
              color: AppTheme.textPrimaryFromContext(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceLg,
                        vertical: AppTheme.spaceMd,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animated Icon (Moon/Sun)
                          AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: _selectedTheme == 'dark' ? 0 : 1,
                                  end: _selectedTheme == 'dark' ? 0 : 1,
                                ),
                                duration: Duration(milliseconds: 800),
                                curve: Curves.easeInOutCubic,
                                builder: (context, value, child) {
                                  return Container(
                                    width: 160,
                                    height: 160,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppTheme.primaryBlue.withValues(
                                            alpha: 0.2,
                                          ),
                                          AppTheme.primaryBlue.withValues(
                                            alpha: 0.05,
                                          ),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryBlue
                                              .withValues(alpha: 0.3),
                                          blurRadius: 40,
                                          spreadRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: Transform.rotate(
                                      angle: value * 3.14159,
                                      child: AnimatedSwitcher(
                                        duration: Duration(milliseconds: 500),
                                        transitionBuilder: (child, animation) {
                                          return ScaleTransition(
                                            scale: animation,
                                            child: child,
                                          );
                                        },
                                        child: _selectedTheme == 'dark'
                                            ? Icon(
                                                Icons.dark_mode_rounded,
                                                key: ValueKey('moon'),
                                                size: 80,
                                                color: Colors.amber[300],
                                              )
                                            : Icon(
                                                Icons.light_mode_rounded,
                                                key: ValueKey('sun'),
                                                size: 80,
                                                color: Colors.orange[300],
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          SizedBox(height: AppTheme.spaceLg * 2),

                          // Title Text
                          Text(
                            _selectedTheme == 'dark'
                                ? AppLocalizations.of(
                                    context,
                                  ).t('settings.dark')
                                : AppLocalizations.of(
                                    context,
                                  ).t('settings.light'),
                            style: AppTheme.headlineSmall.copyWith(
                              color: AppTheme.textPrimaryFromContext(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: AppTheme.spaceSm),

                          // Description Text
                          Text(
                            _selectedTheme == 'dark'
                                ? 'Easy on the eyes, perfect for night time'
                                : 'Bright and clean, ideal for daytime',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textTertiaryFromContext(context),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: AppTheme.spaceLg * 2),

                          // Toggle Switch Container
                          Container(
                            padding: EdgeInsets.all(AppTheme.spaceLg),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppTheme.surfaceGradientFromContext(
                                  context,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusLg,
                              ),
                              border: Border.all(
                                color: AppTheme.surfaceElevatedFromContext(
                                  context,
                                ).withValues(alpha: 0.5),
                                width: 1,
                              ),
                              boxShadow: AppTheme.cardShadow,
                            ),
                            child: Column(
                              children: [
                                // Light Mode Option
                                _buildThemeOption(
                                  context,
                                  isSelected: _selectedTheme == 'light',
                                  icon: Icons.light_mode_rounded,
                                  iconColor: Colors.orange[300]!,
                                  label: AppLocalizations.of(
                                    context,
                                  ).t('settings.light'),
                                  description: 'Bright theme',
                                  onTap: () => _toggleTheme('light'),
                                ),
                                SizedBox(height: AppTheme.spaceMd),
                                Container(
                                  height: 1,
                                  color: AppTheme.surfaceElevatedFromContext(
                                    context,
                                  ).withValues(alpha: 0.3),
                                ),
                                SizedBox(height: AppTheme.spaceMd),
                                // Dark Mode Option
                                _buildThemeOption(
                                  context,
                                  isSelected: _selectedTheme == 'dark',
                                  icon: Icons.dark_mode_rounded,
                                  iconColor: Colors.amber[300]!,
                                  label: AppLocalizations.of(
                                    context,
                                  ).t('settings.dark'),
                                  description: 'Dark theme',
                                  onTap: () => _toggleTheme('dark'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required bool isSelected,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: AppTheme.spaceMd,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected
                    ? LinearGradient(colors: AppTheme.primaryGradient)
                    : LinearGradient(
                        colors: [
                          iconColor.withValues(alpha: 0.2),
                          iconColor.withValues(alpha: 0.1),
                        ],
                      ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : iconColor,
                size: 28,
              ),
            ),
            SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textPrimaryFromContext(context),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textTertiaryFromContext(context),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: AppTheme.primaryGradient),
                ),
                child: Icon(Icons.check_rounded, color: Colors.white, size: 20),
              )
            else
              Icon(
                Icons.circle_outlined,
                color: AppTheme.textTertiaryFromContext(context),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
