import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import 'dart:async';
import '../services/user_profile_service.dart';
import '../services/study_activity_service.dart';
import '../screens/welcome_screen.dart';
import '../screens/email_verification_screen.dart';
import '../screens/main_tabs.dart';
import '../utils/theme.dart';

/// AuthGate - Centralized authentication state management
///
/// This widget sits at the root of the app and handles:
/// - Checking authentication state on app launch
/// - Showing appropriate screen based on auth state
/// - No UI flickering with proper loading states
/// - Initializing user profile service
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with TickerProviderStateMixin {
  bool _isInitialized = false;
  bool _showSplash = true;
  bool _appOpenRecorded =
      false; // Track if we've recorded app open for this session
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _spinnerController;
  late AnimationController _pulseController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Spinner rotation animation (continuous)
    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Pulse animation for spinner scale
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Glow animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _initializeApp();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _spinnerController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // Minimal delay - dismiss native splash almost instantly (~100ms)
    // Initialize services in background without blocking splash
    await Future.delayed(const Duration(milliseconds: 100));

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
      _fadeController.forward();

      // Initialize services in parallel while Flutter splash shows
      unawaited(
        Future.wait([
          UserProfileService.instance.init(),
          StudyActivityService().initialize(),
        ]),
      );

      // Show Flutter splash for 2.5 seconds
      await Future.delayed(const Duration(milliseconds: 2500));
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    }
  }

  /// Record app open for streak tracking
  /// Runs asynchronously without blocking UI
  void _recordAppOpenStreakAsync() {
    Future(() async {
      try {
        final appOpenData = await StudyActivityService().recordAppOpen();
        print(
          '[AuthGate] Streak recorded on app open: ${appOpenData.currentStreak}',
        );

        // Optionally trigger streak increment notifications
        if (appOpenData.streakIncremented) {
          print(
            '[AuthGate] 🔥 Streak incremented to ${appOpenData.currentStreak}!',
          );
        }
      } catch (e) {
        print('[AuthGate] Error recording app open: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show splash screen while initializing
    if (!_isInitialized || _showSplash) {
      return _buildSplashScreen();
    }

    // Listen to auth state changes
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still loading auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        // Check if user is logged in
        final user = snapshot.data;

        // Set current user for account-specific streak tracking
        if (user != null) {
          StudyActivityService.instance.setCurrentUser(user.uid);

          // Record app open to increment streak on new day (only once per session)
          if (!_appOpenRecorded) {
            _appOpenRecorded = true;
            _recordAppOpenStreakAsync();
          }
        } else {
          StudyActivityService.instance.setCurrentUser(null);
        }

        if (user != null) {
          // User is logged in - check if email is verified
          if (!user.emailVerified) {
            // Email not verified - show verification screen
            final displayName = user.displayName ?? 'User';
            return FadeTransition(
              opacity: _fadeAnimation,
              child: EmailVerificationScreen(
                email: user.email ?? '',
                username: displayName,
              ),
            );
          }

          // Email verified - go to main app
          return FadeTransition(
            opacity: _fadeAnimation,
            child: const MainTabs(),
          );
        } else {
          // User is not logged in - check if onboarding was completed
          return FutureBuilder<bool>(
            future: UserProfileService.instance.isOnboardingComplete(),
            builder: (context, onboardingSnapshot) {
              if (onboardingSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return _buildLoadingScreen();
              }

              final onboardingComplete = onboardingSnapshot.data ?? false;

              if (onboardingComplete) {
                // User has seen onboarding before but logged out
                // Go directly to main app (they can login from there)
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: const MainTabs(),
                );
              } else {
                // New user - show welcome/onboarding
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: const WelcomeScreen(),
                );
              }
            },
          );
        }
      },
    );
  }

  Widget _buildSplashScreen() {
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated App Name
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (context, opacity, child) {
                return Opacity(opacity: opacity, child: child);
              },
              child: Column(
                children: [
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
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The Ultimate Studying AI',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            // Enhanced Interactive Spinner
            _buildAnimatedSpinner(),
            const SizedBox(height: 24),
            // Loading text
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.6 + (_pulseController.value * 0.4),
                  child: const Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedSpinner() {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer rotating ring
          AnimatedBuilder(
            animation: _spinnerController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _spinnerController.value * 2 * 3.14159,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          ),
          // Middle rotating ring (faster, opposite direction)
          AnimatedBuilder(
            animation: _spinnerController,
            builder: (context, child) {
              return Transform.rotate(
                angle: -_spinnerController.value * 2.5 * 3.14159,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accentBlueLight.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          ),
          // Inner pulsing circle with glow
          AnimatedBuilder(
            animation: Listenable.merge([_pulseController, _glowController]),
            builder: (context, child) {
              final pulseScale = 1.0 + (_pulseController.value * 0.3);
              final glowOpacity = 0.4 + (_glowController.value * 0.3);

              return Stack(
                alignment: Alignment.center,
                children: [
                  // Glow effect
                  Container(
                    width: 50 * pulseScale,
                    height: 50 * pulseScale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withOpacity(glowOpacity),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                        BoxShadow(
                          color: AppTheme.accentBlueLight.withOpacity(
                            glowOpacity * 0.7,
                          ),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  // Core circle
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white,
                          AppTheme.primaryBlue,
                          AppTheme.accentBlueLight,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withOpacity(0.6),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  // Center dot
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.8),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          // Top accent dot (orbiting)
          AnimatedBuilder(
            animation: _spinnerController,
            builder: (context, child) {
              final angle = _spinnerController.value * 2 * math.pi;
              final offsetX = 30 * math.cos(angle);
              final offsetY = 30 * math.sin(angle);

              return Transform.translate(
                offset: Offset(offsetX, offsetY),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accentBlueLight,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentBlueLight.withOpacity(0.8),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.backgroundGradientStart,
              AppTheme.backgroundGradientEnd,
            ],
          ),
        ),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
          ),
        ),
      ),
    );
  }
}
