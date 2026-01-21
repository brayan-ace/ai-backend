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

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _spotlightController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _spotlightAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _spotlightController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      _spotlightController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _spotlightController.dispose();
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
    _spotlightController.reset();
    _spotlightController.forward();
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
                  // Step indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.steps.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: index == _currentStep ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == _currentStep
                              ? AppTheme.primaryBlue
                              : AppTheme.textTertiary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Content card
                  AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceCard,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.surfaceElevated.withOpacity(
                                  0.3,
                                ),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Illustration or icon
                                if (step.illustration != null) ...[
                                  step.illustration!,
                                  const SizedBox(height: 20),
                                ],

                                // Title
                                Text(
                                  step.title,
                                  style: AppTheme.headlineMedium.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 24,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 12),

                                // Description
                                Text(
                                  step.description,
                                  style: AppTheme.bodyLarge.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 32),

                                // Navigation buttons
                                Row(
                                  children: [
                                    // Previous button (only show if not first step)
                                    if (_currentStep > 0)
                                      Expanded(
                                        child: TextButton(
                                          onPressed: _previousStep,
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                          child: Text(
                                            'Previous',
                                            style: AppTheme.bodyLarge.copyWith(
                                              color: AppTheme.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),

                                    if (_currentStep > 0)
                                      const SizedBox(width: 12),

                                    // Skip button
                                    Expanded(
                                      child: TextButton(
                                        onPressed: _skipOnboarding,
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
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

                                    // Next/Finish button
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _nextStep,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryBlue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          isLastStep
                                              ? 'Start Learning'
                                              : 'Next',
                                          style: AppTheme.bodyLarge.copyWith(
                                            fontWeight: FontWeight.w600,
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
                      );
                    },
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

/// Custom painter for spotlight effect
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
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..blendMode = BlendMode.srcOver;

    // Create a path for the spotlight
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Calculate spotlight position
    Offset spotlightCenter;
    double spotlightRadius = this.size * animation;

    if (targetKey?.currentContext != null) {
      // Use target widget position
      final RenderBox renderBox =
          targetKey!.currentContext!.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      final widgetSize = renderBox.size;
      spotlightCenter =
          position + Offset(widgetSize.width / 2, widgetSize.height / 2);
      spotlightRadius = (widgetSize.width + widgetSize.height) / 2 + 20;
    } else if (manualPosition != null) {
      // Use manual position
      spotlightCenter = manualPosition!;
      if (manualWidth != null && manualHeight != null) {
        spotlightRadius = (manualWidth! + manualHeight!) / 2 + 20;
      }
    } else {
      // Default centered
      spotlightCenter = Offset(size.width / 2, size.height / 2);
    }

    // Create spotlight cutout
    final spotlightPath = Path()
      ..addOval(
        Rect.fromCircle(
          center: spotlightCenter,
          radius: spotlightRadius * animation,
        ),
      );

    // Combine paths for spotlight effect
    final spotlightEffect = Path.combine(
      PathOperation.difference,
      path,
      spotlightPath,
    );

    canvas.drawPath(spotlightEffect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
