import 'package:flutter/material.dart';
import 'dart:math' as math;

class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Animation<double> animation;
  final List<Color> gradientColors;

  WaveformPainter({
    required this.amplitudes,
    required this.animation,
    required this.gradientColors,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final barWidth = size.width / amplitudes.length;
    final gradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: gradientColors,
    );

    for (int i = 0; i < amplitudes.length; i++) {
      // Add slight animation variance to each bar
      final variance =
          math.sin((animation.value * math.pi * 2) + i * 0.5) * 0.1;
      final amplitude = (amplitudes[i] + variance).clamp(0.05, 1.0);

      final barHeight = amplitude * size.height * 0.9;
      final x = i * barWidth + barWidth / 2;
      final y1 = (size.height - barHeight) / 2;
      final y2 = y1 + barHeight;

      paint.shader = gradient.createShader(
        Rect.fromLTWH(x - 2, y1, 4, barHeight),
      );

      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes;
  }
}
