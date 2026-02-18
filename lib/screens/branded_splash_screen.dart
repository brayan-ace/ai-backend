import 'package:flutter/material.dart';

class BrandedSplashScreen extends StatefulWidget {
  final VoidCallback? onAnimationComplete;
  final Duration? displayDuration;

  const BrandedSplashScreen({
    super.key,
    this.onAnimationComplete,
    this.displayDuration = const Duration(seconds: 3),
  });

  @override
  State<BrandedSplashScreen> createState() => _BrandedSplashScreenState();
}

class _BrandedSplashScreenState extends State<BrandedSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _textOpacity;
  late Animation<double> _textScale;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Text fade in animation
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInCubic),
      ),
    );

    // Subtle scale animation for the text
    _textScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    // Start animation
    _controller.forward();

    // Navigate after display duration
    Future.delayed(widget.displayDuration ?? const Duration(seconds: 3), () {
      if (mounted) {
        widget.onAnimationComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_textOpacity, _textScale]),
              builder: (context, child) {
                return Opacity(
                  opacity: _textOpacity.value,
                  child: Transform.scale(scale: _textScale.value, child: child),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main title
                    Text(
                      'Nexa Smart AI',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E88E5),
                            letterSpacing: 0.5,
                          ),
                    ),
                    const SizedBox(height: 16),
                    // Subtitle
                    Text(
                      'Your Ultimate Studying AI',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 18,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
