import 'package:flutter/material.dart';
import '../services/streak_calendar_service.dart';
import 'streak_calendar_tile.dart';

/// Calendar grid widget displaying 6 weeks of streak data with animations
class StreakCalendarGrid extends StatefulWidget {
  final Map<DateTime, StreakDayData> calendarData;
  final List<WeekData> weeks;

  const StreakCalendarGrid({
    Key? key,
    required this.calendarData,
    required this.weeks,
  }) : super(key: key);

  @override
  State<StreakCalendarGrid> createState() => _StreakCalendarGridState();
}

class _StreakCalendarGridState extends State<StreakCalendarGrid>
    with TickerProviderStateMixin {
  late AnimationController _gridFadeController;
  late Animation<double> _gridFadeAnimation;

  @override
  void initState() {
    super.initState();

    _gridFadeController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    _gridFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gridFadeController, curve: Curves.easeOut),
    );

    // Start animation
    Future.delayed(Duration(milliseconds: 200), () {
      if (mounted) {
        _gridFadeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _gridFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _gridFadeAnimation,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            // Month names header (animated)
            _buildMonthHeader(context, isDark),

            SizedBox(height: 20),

            // Weekday header
            _buildWeekdayHeader(context, isDark),

            SizedBox(height: 16),

            // Calendar grid with all weeks
            for (
              int weekIndex = 0;
              weekIndex < widget.weeks.length;
              weekIndex++
            )
              Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: _buildWeekRow(
                  context,
                  widget.weeks[weekIndex],
                  isDark,
                  weekIndex,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Month separator header with gradient
  Widget _buildMonthHeader(BuildContext context, bool isDark) {
    if (widget.weeks.isEmpty) return SizedBox();

    return Column(
      children: [
        for (int i = 0; i < widget.weeks.length; i++)
          if (i == 0 ||
              widget.weeks[i].monthName != widget.weeks[i - 1].monthName)
            _buildMonthSeparator(context, widget.weeks[i].monthName, isDark),
      ],
    );
  }

  /// Individual month separator
  Widget _buildMonthSeparator(
    BuildContext context,
    String monthName,
    bool isDark,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF2196F3).withOpacity(0),
                    Color(0xFF2196F3).withOpacity(0.5),
                    Color(0xFF2196F3).withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              monthName,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Color(0xFFB4BDD4) : Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF2196F3).withOpacity(0),
                    Color(0xFF2196F3).withOpacity(0.5),
                    Color(0xFF2196F3).withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Weekday header (Mon, Tue, etc.)
  Widget _buildWeekdayHeader(BuildContext context, bool isDark) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Color(0xFF30363D) : Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final day in weekdays)
            Expanded(
              child: Center(
                child: Text(
                  day,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Color(0xFF6E7891) : Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Single week row with 7 day tiles
  Widget _buildWeekRow(
    BuildContext context,
    WeekData week,
    bool isDark,
    int weekIndex,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (int dayIndex = 0; dayIndex < week.days.length; dayIndex++)
          Expanded(
            child: Center(
              child: StreakCalendarTile(
                dayData: week.days[dayIndex],
                entranceDelay: Duration(
                  milliseconds: 50 + (weekIndex * 50) + (dayIndex * 30),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
