import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import 'dart:math' as math;
import '../utils/theme.dart';

/// Premium Chart Widget
/// Displays beautiful, animated charts for analytics
class PremiumChartWidget extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final ChartType type;
  final Color? primaryColor;
  final double? height;

  const PremiumChartWidget({
    super.key,
    required this.data,
    required this.type,
    this.primaryColor,
    this.height,
  });

  @override
  State<PremiumChartWidget> createState() => _PremiumChartWidgetState();
}

class _PremiumChartWidgetState extends State<PremiumChartWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.type) {
      case ChartType.line:
        return _buildLineChart();
      case ChartType.bar:
        return _buildBarChart();
      case ChartType.pie:
        return _buildPieChart();
      default:
        return Container();
    }
  }

  Widget _buildLineChart() {
    if (widget.data.isEmpty) return _buildEmptyState();

    return CustomPaint(
      size: Size.infinite,
      painter: LineChartPainter(
        data: widget.data,
        animation: _animation,
        primaryColor: widget.primaryColor ?? AppTheme.primaryBlue,
      ),
      child: Container(),
    );
  }

  Widget _buildBarChart() {
    if (widget.data.isEmpty) return _buildEmptyState();

    return CustomPaint(
      size: Size.infinite,
      painter: BarChartPainter(
        data: widget.data,
        animation: _animation,
        primaryColor: widget.primaryColor ?? AppTheme.primaryBlue,
      ),
      child: Container(),
    );
  }

  Widget _buildPieChart() {
    if (widget.data.isEmpty) return _buildEmptyState();

    return CustomPaint(
      size: Size.infinite,
      painter: PieChartPainter(data: widget.data, animation: _animation),
      child: Container(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: widget.height ?? 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_chart_outlined,
              size: 48,
              color: AppTheme.textTertiary,
            ),
            SizedBox(height: AppTheme.spaceSm),
            Text(
              'No data available',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

enum ChartType { line, bar, pie }

class LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final Animation<double> animation;
  final Color primaryColor;

  LineChartPainter({
    required this.data,
    required this.animation,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = primaryColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final pointPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2;

    if (data.isEmpty) return;

    // Calculate dimensions
    final padding = 40.0;
    final chartWidth = size.width - 2 * padding;
    final chartHeight = size.height - 2 * padding;

    // Find min and max values
    final values = data.map((d) => (d['value'] as num).toDouble()).toList();
    final minValue = values.isNotEmpty ? values.reduce(math.min) : 0.0;
    final maxValue = values.isNotEmpty ? values.reduce(math.max) : 1.0;
    final valueRange = maxValue - minValue;

    // Draw grid lines
    _drawGrid(canvas, size, padding);

    // Draw axes
    _drawAxes(canvas, size, padding);

    // Calculate points
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = padding + (i / (data.length - 1)) * chartWidth;
      final normalizedValue =
          ((data[i]['value'] as double) - minValue) /
          (valueRange == 0 ? 1 : valueRange);
      final y = padding + chartHeight * (1 - normalizedValue * animation.value);
      points.add(Offset(x, y));
    }

    // Draw filled area
    if (points.isNotEmpty) {
      final fillPath = Path()
        ..addPolygon([
          Offset(padding, size.height - padding),
          ...points,
          Offset(size.width - padding, size.height - padding),
        ], false);
      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw line
    if (points.length > 1) {
      final path = Path()..addPolygon(points, false);
      canvas.drawPath(path, paint);
    }

    // Draw points
    for (final point in points) {
      canvas.drawCircle(point, 6, pointPaint);
      canvas.drawCircle(point, 4, Paint()..color = Colors.white);
    }

    // Draw labels
    _drawLineChartLabels(canvas, size, padding, minValue, maxValue);
  }

  void _drawGrid(Canvas canvas, Size size, double padding) {
    final gridPaint = Paint()
      ..color = AppTheme.surfaceElevated.withOpacity(0.3)
      ..strokeWidth = 1;

    // Horizontal grid lines
    for (int i = 0; i <= 5; i++) {
      final y = padding + (i / 5) * (size.height - 2 * padding);
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    // Vertical grid lines
    for (int i = 0; i < data.length; i++) {
      final x = padding + (i / (data.length - 1)) * (size.width - 2 * padding);
      canvas.drawLine(
        Offset(x, padding),
        Offset(x, size.height - padding),
        gridPaint,
      );
    }
  }

  void _drawAxes(Canvas canvas, Size size, double padding) {
    final axisPaint = Paint()
      ..color = AppTheme.textSecondary
      ..strokeWidth = 2;

    // X-axis
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      axisPaint,
    );

    // Y-axis
    canvas.drawLine(
      Offset(padding, padding),
      Offset(padding, size.height - padding),
      axisPaint,
    );
  }

  void _drawLineChartLabels(
    Canvas canvas,
    Size size,
    double padding,
    double minValue,
    double maxValue,
  ) {
    final textStyle = AppTheme.bodySmall.copyWith(
      color: AppTheme.textSecondary,
    );

    // Y-axis labels
    for (int i = 0; i <= 5; i++) {
      final value = minValue + (maxValue - minValue) * (1 - i / 5);
      final y = padding + (i / 5) * (size.height - 2 * padding);
      final textPainter = TextPainter(
        text: TextSpan(text: value.round().toString(), style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(padding - 30, y - 10));
    }

    // X-axis labels
    for (int i = 0; i < data.length; i++) {
      final x = padding + (i / (data.length - 1)) * (size.width - 2 * padding);
      final textPainter = TextPainter(
        text: TextSpan(text: data[i]['day'] as String, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - 15, size.height - padding + 10));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final Animation<double> animation;
  final Color primaryColor;

  BarChartPainter({
    required this.data,
    required this.animation,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final padding = 40.0;
    final chartWidth = size.width - 2 * padding;
    final chartHeight = size.height - 2 * padding;
    final barWidth = chartWidth / data.length * 0.6;
    final spacing = chartWidth / data.length * 0.4;

    // Find max value for scaling
    final maxValue = data
        .map((d) => (d['value'] as num).toDouble())
        .reduce(math.max);

    // Draw bars
    for (int i = 0; i < data.length; i++) {
      final barHeight =
          ((data[i]['value'] as double) / (maxValue == 0 ? 1 : maxValue)) *
          chartHeight *
          animation.value;
      final x = padding + i * (barWidth + spacing) + spacing / 2;
      final y = size.height - padding - barHeight;

      // Create gradient for each bar
      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          data[i]['color'] as Color? ?? primaryColor,
          (data[i]['color'] as Color? ?? primaryColor).withOpacity(0.6),
        ],
      );

      final barPaint = Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(x, y, barWidth, barHeight),
        );

      // Draw rounded rectangle bar
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(8),
      );
      canvas.drawRRect(rrect, barPaint);

      // Draw value label on top of bar
      final valueText = data[i]['value'].toString();
      final textPainter = TextPainter(
        text: TextSpan(
          text: valueText,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + (barWidth - textPainter.width) / 2, y - 20),
      );

      // Draw category label
      final categoryText = data[i]['category'] as String;
      final categoryPainter = TextPainter(
        text: TextSpan(
          text: categoryText,
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
        ),
        textDirection: TextDirection.ltr,
      );
      categoryPainter.layout();
      categoryPainter.paint(
        canvas,
        Offset(
          x + (barWidth - categoryPainter.width) / 2,
          size.height - padding + 10,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PieChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final Animation<double> animation;

  PieChartPainter({required this.data, required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 3;

    // Calculate total value
    final total = data.map((d) => d['value'] as num).reduce((a, b) => a + b);

    double currentAngle = -math.pi / 2; // Start from top

    for (int i = 0; i < data.length; i++) {
      final sweepAngle =
          ((data[i]['value'] as double) / (total == 0 ? 1 : total)) *
          2 *
          math.pi *
          animation.value;
      final color = data[i]['color'] as Color? ?? _getDefaultColor(i);

      // Draw pie slice
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        sweepAngle,
        true,
        paint,
      );

      // Draw label
      final labelAngle = currentAngle + sweepAngle / 2;
      final labelX = center.dx + math.cos(labelAngle) * (radius * 0.7);
      final labelY = center.dy + math.sin(labelAngle) * (radius * 0.7);

      final percentage =
          (((data[i]['value'] as double) / (total == 0 ? 1 : total)) * 100)
              .round();
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$percentage%',
          style: AppTheme.bodySmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(labelX - textPainter.width / 2, labelY - textPainter.height / 2),
      );

      currentAngle += sweepAngle;
    }

    // Draw center circle for donut effect
    final centerPaint = Paint()
      ..color = AppTheme.surfaceCard
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.3, centerPaint);
  }

  Color _getDefaultColor(int index) {
    final colors = [
      AppTheme.primaryBlue,
      AppTheme.accentBlue,
      AppTheme.success,
      AppTheme.warning,
      AppTheme.error,
    ];
    return colors[index % colors.length];
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
