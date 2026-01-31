import 'package:flutter/material.dart';
import '../utils/theme.dart';

class TypingIndicator extends StatefulWidget {
  final String? message;
  const TypingIndicator({super.key, this.message});

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
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: EdgeInsets.all(AppTheme.spaceMd),
      margin: EdgeInsets.symmetric(
        vertical: AppTheme.spaceXs,
        horizontal: AppTheme.spaceSm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLightTheme
              ? [Color(0xFFFAFAFA), Color(0xFFF5F5F5)]
              : AppTheme.surfaceGradient,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isLightTheme
              ? Color(0xFFE5E7EB)
              : AppTheme.surfaceElevated.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildLine(0, 0.6),
          SizedBox(width: 4),
          _buildLine(1, 0.8),
          SizedBox(width: 4),
          _buildLine(2, 0.5),
          if (widget.message != null) ...[
            SizedBox(width: AppTheme.spaceMd),
            Text(
              widget.message!,
              style: AppTheme.bodyMedium.copyWith(
                color: isLightTheme
                    ? Color(0xFF000000)
                    : AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLine(int index, double baseHeight) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final delay = index * 0.15;
        final value = (_controller.value - delay) % 1.0;

        // Animate height: small -> large -> small
        final animatedHeight = baseHeight * (0.5 + (value.abs() - 0.5).abs());

        return Container(
          width: 3,
          height: 14 * animatedHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: AppTheme.accentGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentBlue.withOpacity(0.3),
                blurRadius: 4,
                spreadRadius: 0,
              ),
            ],
          ),
        );
      },
    );
  }
}
