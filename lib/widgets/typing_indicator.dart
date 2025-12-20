import 'package:flutter/material.dart';
import '../utils/theme.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spaceMd),
      margin: EdgeInsets.symmetric(
        vertical: AppTheme.spaceXs,
        horizontal: AppTheme.spaceSm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppTheme.surfaceGradient),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.surfaceElevated.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(0),
          SizedBox(width: 6),
          _buildDot(1),
          SizedBox(width: 6),
          _buildDot(2),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final delay = index * 0.2;
        final value = (_controller.value - delay) % 1.0;
        final scale = value < 0.5
            ? 1.0 + (value * 0.6)
            : 1.3 - ((value - 0.5) * 0.6);
        final opacity = value < 0.5 ? 0.4 + (value * 1.2) : 1.0 - (value * 0.6);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: AppTheme.primaryGradient),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(opacity * 0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
