import 'package:flutter/material.dart';
import '../services/streak_calendar_service.dart';

/// Animated individual day tile in the streak calendar
/// Supports active, missed, today, and future states with unique animations
class StreakCalendarTile extends StatefulWidget {
  final StreakDayData dayData;
  final Duration entranceDelay;
  final VoidCallback? onTap;

  const StreakCalendarTile({
    Key? key,
    required this.dayData,
    this.entranceDelay = Duration.zero,
    this.onTap,
  }) : super(key: key);

  @override
  State<StreakCalendarTile> createState() => _StreakCalendarTileState();
}

class _StreakCalendarTileState extends State<StreakCalendarTile>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _scaleController;

  late Animation<double> _entranceScale;
  late Animation<double> _entranceOpacity;
  late Animation<double> _pulseScale;
  late Animation<double> _glowOpacity;
  late Animation<double> _tapScale;

  @override
  void initState() {
    super.initState();

    // Entrance animation (staggered slide-up + fade)
    _entranceController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _entranceScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );

    _entranceOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );

    // Pulse animation for active days (breathing effect)
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Glow animation for active days
    _glowController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowOpacity = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Tap animation
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 150),
      vsync: this,
    );

    _tapScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    // Start entrance animation with delay
    Future.delayed(widget.entranceDelay, () {
      if (mounted) {
        _entranceController.forward();
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _scaleController.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ScaleTransition(
      scale: _entranceScale,
      child: FadeTransition(
        opacity: _entranceOpacity,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          child: ScaleTransition(
            scale: _tapScale,
            child: _buildTile(context, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, bool isDark) {
    if (widget.dayData.isFuture) {
      return _buildFutureTile(context, isDark);
    } else if (widget.dayData.isMissed) {
      return _buildMissedTile(context, isDark);
    } else if (widget.dayData.isToday) {
      return _buildTodayTile(context, isDark);
    } else if (widget.dayData.isActive) {
      return _buildActiveTile(context, isDark);
    }

    return SizedBox(width: 56, height: 56);
  }

  /// Active streak day - Full glow with breathing animation
  Widget _buildActiveTile(BuildContext context, bool isDark) {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowOpacity, _pulseScale]),
      builder: (context, child) {
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF42A5F5).withOpacity(_glowOpacity.value),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
            border: Border.all(
              color: Color(0xFF42A5F5).withOpacity(0.6),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulseScale,
                child: Text('🔥', style: TextStyle(fontSize: 22)),
              ),
              SizedBox(height: 2),
              Text(
                '${widget.dayData.dayNumber}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Today's date - Green indicator with continuous breathing
  Widget _buildTodayTile(BuildContext context, bool isDark) {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowOpacity, _pulseScale]),
      builder: (context, child) {
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF10B981).withOpacity(_glowOpacity.value * 0.8),
                blurRadius: 20,
                spreadRadius: 3,
              ),
            ],
            border: Border.all(
              color: Color(0xFF10B981).withOpacity(0.8),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulseScale,
                child: Text('🟢', style: TextStyle(fontSize: 22)),
              ),
              SizedBox(height: 2),
              Text(
                '${widget.dayData.dayNumber}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Missed day - Dim with × mark
  Widget _buildMissedTile(BuildContext context, bool isDark) {
    final bgColor = isDark ? Color(0xFF1F2937) : Color(0xFFE5E7EB);
    final borderColor = isDark ? Color(0xFF374151) : Color(0xFFD1D5DB);

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: bgColor,
        border: Border.all(color: borderColor.withOpacity(0.5), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('❌', style: TextStyle(fontSize: 18)),
          SizedBox(height: 2),
          Text(
            '${widget.dayData.dayNumber}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? Color(0xFF6B7280) : Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  /// Future date - Empty placeholder
  Widget _buildFutureTile(BuildContext context, bool isDark) {
    final bgColor = isDark ? Color(0xFF161B22) : Color(0xFFF9FAFB);
    final borderColor = isDark ? Color(0xFF30363D) : Color(0xFFE5E7EB);

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: bgColor,
        border: Border.all(color: borderColor.withOpacity(0.3), width: 1),
      ),
      child: Center(
        child: Text(
          '${widget.dayData.dayNumber}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Color(0xFF6E7891) : Color(0xFFD1D5DB),
          ),
        ),
      ),
    );
  }
}
