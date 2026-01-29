import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../services/settings_service.dart';

class CapabilitiesScreen extends StatefulWidget {
  const CapabilitiesScreen({super.key});

  @override
  State<CapabilitiesScreen> createState() => _CapabilitiesScreenState();
}

class _CapabilitiesScreenState extends State<CapabilitiesScreen> {
  late SettingsService _settingsService;
  bool _webSearchEnabled = true;
  bool _quizArtifactEnabled = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _settingsService = SettingsService.instance;
    _loadCapabilities();
  }

  Future<void> _loadCapabilities() async {
    await _settingsService.init();

    final webSearch = await _settingsService.getWebSearchCapability();
    final quizArtifact = await _settingsService.getQuizArtifactCapability();

    setState(() {
      _webSearchEnabled = webSearch;
      _quizArtifactEnabled = quizArtifact;
    });
  }

  Future<void> _toggleWebSearch(bool value) async {
    setState(() => _isLoading = true);

    try {
      await _settingsService.setWebSearchCapability(value);
      setState(() {
        _webSearchEnabled = value;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Web Search ${value ? 'enabled' : 'disabled'}'),
          backgroundColor: AppTheme.primaryBlue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update Web Search setting'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleQuizArtifact(bool value) async {
    setState(() => _isLoading = true);

    try {
      await _settingsService.setQuizArtifactCapability(value);
      setState(() {
        _quizArtifactEnabled = value;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quiz Artifact ${value ? 'enabled' : 'disabled'}'),
          backgroundColor: AppTheme.primaryBlue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update Quiz Artifact setting'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildSectionHeader(String text) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.spaceMd,
        AppTheme.spaceLg,
        AppTheme.spaceMd,
        AppTheme.spaceSm,
      ),
      child: Text(
        text.toUpperCase(),
        style: AppTheme.labelMedium.copyWith(
          color: isDarkMode ? AppTheme.textTertiary : Color(0xFF6B7280),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppTheme.spaceSm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? AppTheme.surfaceGradient
              : [Color(0xFFFAFAFA), Color(0xFFF5F5F5)],
        ),
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

  Widget _capabilityTile({
    required IconData icon,
    required String title,
    required String description,
    required bool isEnabled,
    required ValueChanged<bool> onChanged,
    List<Color>? gradient,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.all(AppTheme.spaceMd),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
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
              color: isDarkMode ? AppTheme.textPrimary : Colors.black,
              size: 24,
            ),
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppTheme.spaceXs),
                Text(
                  description,
                  style: AppTheme.bodySmall.copyWith(
                    color: isDarkMode
                        ? AppTheme.textTertiary
                        : Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: _isLoading ? null : onChanged,
            activeColor: AppTheme.primaryBlue,
            inactiveThumbColor: isDarkMode
                ? AppTheme.surfaceElevated
                : Color(0xFFCBD5E1),
            inactiveTrackColor: isDarkMode
                ? AppTheme.surfaceElevated.withOpacity(0.5)
                : Color(0xFFE2E8F0),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  AppTheme.backgroundGradientStart,
                  AppTheme.backgroundGradientEnd,
                ]
              : [Color(0xFFFAFAFA), Color(0xFFF5F5F5)],
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
                colors: isDarkMode
                    ? AppTheme.glassGradient
                    : [Color(0xFFFFFFFF), Color(0xFFFAFAFA)],
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
              'Capabilities',
              style: AppTheme.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Header Info
              Padding(
                padding: EdgeInsets.all(AppTheme.spaceMd),
                child: Container(
                  padding: EdgeInsets.all(AppTheme.spaceLg),
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
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.settings_suggest,
                          color: Colors.black,
                          size: 30,
                        ),
                      ),
                      SizedBox(width: AppTheme.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Capabilities',
                              style: AppTheme.headlineMedium.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: AppTheme.spaceXs),
                            Text(
                              'Control which AI features are available',
                              style: AppTheme.bodyMedium.copyWith(
                                color: Colors.black.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(bottom: AppTheme.spaceLg),
                  children: [
                    // Capabilities Section
                    _buildSectionHeader('Features'),
                    _buildCard(
                      children: [
                        _capabilityTile(
                          icon: Icons.search,
                          title: 'Web Search',
                          description:
                              'Allow AI to search the web for current information',
                          isEnabled: _webSearchEnabled,
                          onChanged: _toggleWebSearch,
                          gradient: AppTheme.accentGradient,
                        ),
                        _buildDivider(),
                        _capabilityTile(
                          icon: Icons.quiz,
                          title: 'Quiz Artifact',
                          description:
                              'Generate quizzes and learning materials',
                          isEnabled: _quizArtifactEnabled,
                          onChanged: _toggleQuizArtifact,
                          gradient: AppTheme.primaryGradient,
                        ),
                      ],
                    ),

                    // Info Section
                    _buildSectionHeader('Information'),
                    _buildCard(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(AppTheme.spaceMd),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Builder(
                                builder: (context) {
                                  final isDarkMode =
                                      Theme.of(context).brightness ==
                                      Brightness.dark;
                                  return Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: AppTheme.primaryBlue,
                                        size: 20,
                                      ),
                                      SizedBox(width: AppTheme.spaceSm),
                                      Text(
                                        'How Capabilities Work',
                                        style: AppTheme.labelLarge.copyWith(
                                          color: isDarkMode
                                              ? AppTheme.textSecondary
                                              : Color(0xFF4B5563),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              SizedBox(height: AppTheme.spaceMd),
                              Builder(
                                builder: (context) {
                                  final isDarkMode =
                                      Theme.of(context).brightness ==
                                      Brightness.dark;
                                  return Text(
                                    '• When enabled, capabilities are available to the AI immediately\n'
                                    '• Changes are saved automatically and persist across app restarts\n'
                                    '• Some features may require additional permissions or setup',
                                    style: AppTheme.bodySmall.copyWith(
                                      color: isDarkMode
                                          ? AppTheme.textTertiary
                                          : Color(0xFF6B7280),
                                      height: 1.5,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: AppTheme.spaceLg),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
