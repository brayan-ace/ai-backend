import 'package:flutter/material.dart';

class PremiumSplashScreen extends StatefulWidget {
  final VoidCallback? onAnimationComplete;
  final Duration? navigationDelay;

  const PremiumSplashScreen({
    super.key,
    this.onAnimationComplete,
    this.navigationDelay = const Duration(milliseconds: 200),
  });

  @override
  State<PremiumSplashScreen> createState() => _PremiumSplashScreenState();
}

class _PremiumSplashScreenState extends State<PremiumSplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate after a short delay
    Future.delayed(widget.navigationDelay ?? const Duration(seconds: 1), () {
      if (mounted) {
        widget.onAnimationComplete?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.white,
        ),
      ),
    );
  }
}
