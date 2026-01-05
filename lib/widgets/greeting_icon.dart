import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Widget that displays the appropriate greeting icon based on time of day
class GreetingIcon extends StatelessWidget {
  final String timeOfDay;
  final double size;

  const GreetingIcon({Key? key, required this.timeOfDay, this.size = 80})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.primaryGradient,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.5, size * 0.5),
          painter: _GreetingIconPainter(),
        ),
      ),
    );
  }
}

/// Custom painter for the greeting icon (diamond/star pattern like Claude)
class _GreetingIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width / 2.5;

    // Draw concentric diamond shapes (Claude-style)
    for (int i = 0; i < 3; i++) {
      final currentRadius = radius * (1 - i * 0.25);
      final path = Path();

      // Top point
      path.moveTo(centerX, centerY - currentRadius);
      // Right point
      path.lineTo(centerX + currentRadius, centerY);
      // Bottom point
      path.lineTo(centerX, centerY + currentRadius);
      // Left point
      path.lineTo(centerX - currentRadius, centerY);
      // Close path
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
