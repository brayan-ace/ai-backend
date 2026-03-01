import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/theme.dart';
import '../utils/theme_provider.dart';
import '../utils/language_provider.dart';
import '../utils/app_localizations.dart';

/// Welcome/Onboarding screen for new users
/// Features animated elements, app branding, and navigation to auth flows
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _floatController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Fade in animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    // Pulse animation for the logo glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Float animation for decorative elements
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // Start fade animation
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, _) {
        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.backgroundGradientStart,
                  AppTheme.backgroundGradientEnd,
                  const Color(0xFF0A1628),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Animated background particles/orbs
                ..._buildBackgroundOrbs(size),

                // Main content
                SafeArea(
                  child: AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          const Spacer(flex: 2),

                          // Animated Logo with glow
                          _buildAnimatedLogo(),

                          const SizedBox(height: 32),

                          // App Name
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                AppTheme.primaryBlue,
                                AppTheme.accentBlueLight,
                                Colors.white,
                              ],
                            ).createShader(bounds),
                            child: const Text(
                              'Nexa Smart AI',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Tagline
                          Text(
                            AppLocalizations.of(
                              context,
                            ).t('onboarding.subtitle'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),

                          const SizedBox(height: 48),

                          // Feature highlights
                          _buildFeatureHighlights(),

                          const SizedBox(height: 32),

                          // Select Language and Theme Section
                          _buildLanguageThemeSelector(),

                          const Spacer(flex: 2),

                          // Get Started Button (Primary)
                          _buildPrimaryButton(
                            label: AppLocalizations.of(
                              context,
                            ).t('onboarding.letsGetStarted'),
                            icon: Icons.rocket_launch_rounded,
                            onPressed: () {
                              Navigator.pushNamed(context, '/signup-choice');
                            },
                          ),

                          const SizedBox(height: 16),

                          // Already have account (Secondary)
                          _buildSecondaryButton(
                            label: AppLocalizations.of(
                              context,
                            ).t('auth.alreadyHaveAccount'),
                            onPressed: () {
                              Navigator.pushNamed(context, '/login');
                            },
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageThemeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => _showLanguageSelectionDialogContent(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryBlue.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.language_rounded,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Select Preferred Language',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppTheme.primaryBlue,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageSelectionDialogContent() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black45,
      builder: (bottomContext) => _buildLanguageSelectionContent(bottomContext),
    );
  }

  Widget _buildLanguageSelectionContent(BuildContext dialogContext) {
    return Consumer2<LanguageProvider, ThemeProvider>(
      builder: (consumerContext, languageProvider, themeProvider, _) {
        final supportedLanguages = languageProvider.supportedLanguageCodes;

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Select Language',
                  style: Theme.of(consumerContext).textTheme.headlineSmall
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 24),
                // Language Options Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 3,
                  ),
                  itemCount: supportedLanguages.length,
                  itemBuilder: (context, index) {
                    final langCode = supportedLanguages[index];
                    final langName = languageProvider.getLanguageName(langCode);
                    final isSelected =
                        languageProvider.currentLanguageCode == langCode;

                    return GestureDetector(
                      onTap: () async {
                        await languageProvider.setLanguage(langCode);
                        if (mounted) {
                          Navigator.pop(dialogContext);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryBlue.withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryBlue
                                : AppTheme.primaryBlue.withOpacity(0.2),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            langName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected
                                  ? AppTheme.primaryBlue
                                  : AppTheme.textSecondary,
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _floatAnimation]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryBlue, AppTheme.primaryBlueDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(
                    _pulseAnimation.value,
                  ),

                  blurRadius: 40,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: AppTheme.accentBlue.withOpacity(
                    _pulseAnimation.value * 0.5,
                  ),
                  blurRadius: 60,
                  spreadRadius: 20,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.psychology_rounded,
                size: 70,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureHighlights() {
    final features = [
      {'icon': Icons.auto_awesome, 'text': 'AI-Powered Learning'},
      {'icon': Icons.school_rounded, 'text': 'Personalized Study Plans'},
      {'icon': Icons.quiz_rounded, 'text': 'Smart Quizzes & Tests'},
    ];

    return Column(
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  feature['icon'] as IconData,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                feature['text'] as String,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppTheme.primaryGradient),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.primaryBlue,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBackgroundOrbs(Size size) {
    return [
      // Top right orb
      AnimatedBuilder(
        animation: _floatAnimation,
        builder: (context, _) {
          return Positioned(
            top: -50 + _floatAnimation.value,
            right: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryBlue.withOpacity(0.15),
                    AppTheme.primaryBlue.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      // Bottom left orb
      AnimatedBuilder(
        animation: _floatAnimation,
        builder: (context, _) {
          return Positioned(
            bottom: 100 - _floatAnimation.value,
            left: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accentBlue.withOpacity(0.1),
                    AppTheme.accentBlue.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      // Center accent
      AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, _) {
          return Positioned(
            top: size.height * 0.3,
            left: size.width * 0.5 - 100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryBlue.withOpacity(
                      _pulseAnimation.value * 0.1,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ];
  }
}
