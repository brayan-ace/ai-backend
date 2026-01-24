import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../services/onboarding_service.dart';

/// Data class for onboarding steps
class OnboardingStep {
  final String title;
  final String description;
  final Widget? illustration;
  final GlobalKey? targetKey;
  final Offset? manualPosition;
  final double? manualWidth;
  final double? manualHeight;
  final Alignment spotlightAlignment;
  final double spotlightSize;

  const OnboardingStep({
    required this.title,
    required this.description,
    this.illustration,
    this.targetKey,
    this.manualPosition,
    this.manualWidth,
    this.manualHeight,
    this.spotlightAlignment = Alignment.center,
    this.spotlightSize = 200.0,
  });
}

/// Onboarding overlay widget with spotlight effect
class OnboardingOverlay extends StatefulWidget {
  final List<OnboardingStep> steps;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const OnboardingOverlay({
    Key? key,
    required this.steps,
    required this.onComplete,
    required this.onSkip,
  }) : super(key: key);

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _spotlightController;
  late Animation<double> _spotlightAnimation;
  late AnimationController _contentController;
  late Animation<Offset> _contentSlideAnimation;
  late Animation<double> _contentFadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _spotlightController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _spotlightAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _spotlightController, curve: Curves.elasticOut),
    );

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _contentSlideAnimation =
        Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _contentController,
            curve: Curves.easeOutCubic,
          ),
        );
    _contentFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _spotlightController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _contentController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _spotlightController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() {
        _currentStep++;
        OnboardingService.saveCurrentStep(_currentStep);
      });
      _animateTransition();
    } else {
      _completeOnboarding();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        OnboardingService.saveCurrentStep(_currentStep);
      });
      _animateTransition();
    }
  }

  void _skipOnboarding() {
    OnboardingService.skipOnboarding();
    widget.onSkip();
  }

  void _completeOnboarding() {
    OnboardingService.completeOnboarding();
    widget.onComplete();
  }

  void _animateTransition() {
    _contentController.reverse().then((_) {
      _spotlightController.reset();
      _spotlightController.forward();
      _contentController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final isLastStep = _currentStep == widget.steps.length - 1;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Semi-transparent background
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Container(
                color: Colors.black.withOpacity(0.7 * _fadeAnimation.value),
              );
            },
          ),

          // Spotlight effect
          AnimatedBuilder(
            animation: _spotlightAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: SpotlightPainter(
                  targetKey: step.targetKey,
                  manualPosition: step.manualPosition,
                  manualWidth: step.manualWidth,
                  manualHeight: step.manualHeight,
                  alignment: step.spotlightAlignment,
                  size: step.spotlightSize,
                  animation: _spotlightAnimation.value,
                ),
                child: Container(),
              );
            },
          ),

          // Content overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Step indicator with enhanced animation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.steps.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: index == _currentStep ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: index == _currentStep
                              ? LinearGradient(colors: AppTheme.primaryGradient)
                              : null,
                          color: index == _currentStep
                              ? null
                              : AppTheme.textTertiary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: index == _currentStep
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primaryBlue.withOpacity(
                                      0.4,
                                    ),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Content card with premium animations
                  SlideTransition(
                    position: _contentSlideAnimation,
                    child: FadeTransition(
                      opacity: _contentFadeAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.surfaceCard,
                              AppTheme.surfaceCard.withValues(alpha: 0.95),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppTheme.surfaceElevated.withOpacity(0.4),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 32,
                              offset: const Offset(0, 16),
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: AppTheme.primaryBlue.withOpacity(0.1),
                              blurRadius: 64,
                              offset: const Offset(0, 8),
                              spreadRadius: -8,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Illustration with enhanced animation
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutBack,
                              child: step.illustration != null
                                  ? TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: const Duration(
                                        milliseconds: 800,
                                      ),
                                      curve: Curves.elasticOut,
                                      builder: (context, value, child) {
                                        return Transform.scale(
                                          scale: value,
                                          child: child,
                                        );
                                      },
                                      child: step.illustration!,
                                    )
                                  : null,
                            ),
                            if (step.illustration != null)
                              const SizedBox(height: 24),

                            // Title with gradient text effect
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  AppTheme.textPrimary,
                                  AppTheme.primaryBlue.withValues(alpha: 0.8),
                                ],
                              ).createShader(bounds),
                              child: Text(
                                step.title,
                                style: AppTheme.headlineMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 26,
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Description with improved typography
                            Text(
                              step.description,
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.textSecondary,
                                fontSize: 17,
                                height: 1.6,
                                letterSpacing: 0.2,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 36),

                            // Enhanced navigation buttons
                            Row(
                              children: [
                                // Previous button (only show if not first step)
                                if (_currentStep > 0)
                                  Expanded(
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      child: TextButton(
                                        onPressed: _previousStep,
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                            horizontal: 20,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            side: BorderSide(
                                              color: AppTheme.surfaceElevated
                                                  .withOpacity(0.5),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.arrow_back,
                                              size: 18,
                                              color: AppTheme.textSecondary,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Previous',
                                              style: AppTheme.bodyLarge
                                                  .copyWith(
                                                    color:
                                                        AppTheme.textSecondary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                if (_currentStep > 0) const SizedBox(width: 12),

                                // Skip button
                                Expanded(
                                  child: TextButton(
                                    onPressed: _skipOnboarding,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 20,
                                      ),
                                    ),
                                    child: Text(
                                      'Skip',
                                      style: AppTheme.bodyLarge.copyWith(
                                        color: AppTheme.textTertiary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // Next/Finish button with premium gradient
                                Expanded(
                                  flex: 2,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isLastStep
                                            ? [
                                                AppTheme.success,
                                                AppTheme.success.withValues(
                                                  alpha: 0.8,
                                                ),
                                              ]
                                            : AppTheme.primaryGradient,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              (isLastStep
                                                      ? AppTheme.success
                                                      : AppTheme.primaryBlue)
                                                  .withOpacity(0.4),
                                          blurRadius: 16,
                                          offset: Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _nextStep,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                          horizontal: 24,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            isLastStep
                                                ? 'Start Learning'
                                                : 'Next',
                                            style: AppTheme.bodyLarge.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          if (!isLastStep) ...[
                                            SizedBox(width: 8),
                                            Icon(Icons.arrow_forward, size: 18),
                                          ] else ...[
                                            SizedBox(width: 8),
                                            Icon(Icons.celebration, size: 18),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for spotlight effect with premium enhancements
class SpotlightPainter extends CustomPainter {
  final GlobalKey? targetKey;
  final Offset? manualPosition;
  final double? manualWidth;
  final double? manualHeight;
  final Alignment alignment;
  final double size;
  final double animation;

  SpotlightPainter({
    this.targetKey,
    this.manualPosition,
    this.manualWidth,
    this.manualHeight,
    required this.alignment,
    required this.size,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // Enhanced background with gradient overlay
    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.black.withValues(alpha: 0.85 * animation),
          Colors.black.withValues(alpha: 0.75 * animation),
        ],
      ).createShader(Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      backgroundPaint,
    );

    // Calculate spotlight position
    Offset spotlightCenter;
    double spotlightRadius = size * animation;

    if (targetKey?.currentContext != null) {
      // Use target widget position
      final RenderBox renderBox =
          targetKey!.currentContext!.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      final widgetSize = renderBox.size;
      spotlightCenter =
          position + Offset(widgetSize.width / 2, widgetSize.height / 2);
      spotlightRadius = (widgetSize.width + widgetSize.height) / 2 + 40;
    } else if (manualPosition != null) {
      // Use manual position
      spotlightCenter = manualPosition!;
      if (manualWidth != null && manualHeight != null) {
        spotlightRadius = (manualWidth! + manualHeight!) / 2 + 40;
      }
    } else {
      // Default centered
      spotlightCenter = Offset(canvasSize.width / 2, canvasSize.height / 2);
    }

    // Create premium spotlight with soft edges
    final spotlightPath = Path()
      ..addOval(
        Rect.fromCircle(
          center: spotlightCenter,
          radius: spotlightRadius * animation,
        ),
      );

    // Add subtle glow effect
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: spotlightRadius / canvasSize.width,
        colors: [
          AppTheme.primaryBlue.withValues(alpha: 0.3 * animation),
          AppTheme.accentBlue.withValues(alpha: 0.2 * animation),
          Colors.transparent,
        ],
        stops: [0.0, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height));

    canvas.drawCircle(
      spotlightCenter,
      spotlightRadius * 1.2 * animation,
      glowPaint,
    );

    // Create spotlight cutout with smooth edges
    final spotlightEffect = Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height)),
      spotlightPath,
    );

    final spotlightPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.8 * animation)
      ..blendMode = BlendMode.srcOver;

    canvas.drawPath(spotlightEffect, spotlightPaint);

    // Add subtle border around spotlight
    final borderPaint = Paint()
      ..color = AppTheme.primaryBlue.withValues(alpha: 0.4 * animation)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0);

    canvas.drawCircle(
      spotlightCenter,
      spotlightRadius * animation,
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
