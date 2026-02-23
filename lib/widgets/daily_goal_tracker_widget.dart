import 'package:flutter/material.dart';

/// Widget showing daily review goal progress and motivation
class DailyGoalTrackerWidget extends StatefulWidget {
  final int completedToday;
  final int recommendedDaily;
  final DateTime? today;
  final VoidCallback? onStartReview;

  const DailyGoalTrackerWidget({
    Key? key,
    required this.completedToday,
    required this.recommendedDaily,
    this.today,
    this.onStartReview,
  }) : super(key: key);

  @override
  State<DailyGoalTrackerWidget> createState() => _DailyGoalTrackerWidgetState();
}

class _DailyGoalTrackerWidgetState extends State<DailyGoalTrackerWidget> {
  late int completedToday;

  @override
  void initState() {
    super.initState();
    completedToday = widget.completedToday;
  }

  @override
  void didUpdateWidget(DailyGoalTrackerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completedToday != widget.completedToday) {
      setState(() {
        completedToday = widget.completedToday;
      });
    }
  }

  double get _progressPercentage =>
      (completedToday / widget.recommendedDaily).clamp(0.0, 1.0);

  bool get _isCompleted => completedToday >= widget.recommendedDaily;

  String get _motivationalMessage {
    if (_isCompleted) {
      return '🎉 Amazing! Daily goal complete!';
    }
    final remaining = widget.recommendedDaily - completedToday;
    if (remaining > 5) {
      return '💪 Keep going! $remaining more to reach your goal';
    } else if (remaining > 0) {
      return '🔥 Almost there! Just $remaining more review${remaining > 1 ? 's' : ''}';
    }
    return '🚀 Ready to start? Begin your daily reviews!';
  }

  Color get _progressColor {
    if (_isCompleted) return Colors.green;
    if (_progressPercentage >= 0.5) return Colors.blue;
    if (_progressPercentage >= 0.25) return Colors.orange;
    return Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _progressColor.withOpacity(0.1),
            _progressColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _progressColor.withOpacity(0.3), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📋 Today\'s Goal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _progressColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$completedToday / ${widget.recommendedDaily}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _progressColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progressPercentage,
              minHeight: 12,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
            ),
          ),
          SizedBox(height: 12),

          // Motivational Message
          Row(
            children: [
              Expanded(
                child: Text(
                  _motivationalMessage,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _progressColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Statistics Row
          Row(
            children: [
              Expanded(
                child: _StatItem(icon: '✨', label: 'Streak', value: 'Active'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StatItem(
                  icon: '⏱️',
                  label: 'Est. Time',
                  value: '${(widget.recommendedDaily * 5)} min',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StatItem(
                  icon: '📈',
                  label: 'Efficiency',
                  value: '${(100 * _progressPercentage).toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),

          if (!_isCompleted) ...[
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onStartReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _progressColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      completedToday > 0
                          ? '📚 Continue Reviews'
                          : '🚀 Start Learning',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    '✅ Goal Completed! Enjoy your day!',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _StatItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: TextStyle(fontSize: 18)),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Widget showing activity calendar for review streaks
class ActivityCalendarWidget extends StatelessWidget {
  final Map<DateTime, int> reviewsByDate;
  final DateTime fromDate;
  final DateTime toDate;

  const ActivityCalendarWidget({
    Key? key,
    required this.reviewsByDate,
    required this.fromDate,
    required this.toDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final weeks = _generateCalendarWeeks();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📊 Activity',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              // Day headers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                    .map(
                      (day) => SizedBox(
                        width: 32,
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              SizedBox(height: 8),
              // Calendar grid
              ...weeks.map(
                (week) => Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: week
                        .map(
                          (date) => _ActivityDot(
                            date: date,
                            reviewCount: reviewsByDate[date] ?? 0,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        // Legend
        Row(
          children: [
            _ActivityLegend(color: Colors.grey[300]!, label: 'No Activity'),
            SizedBox(width: 16),
            _ActivityLegend(color: Colors.orange[200]!, label: '1-5 reviews'),
            SizedBox(width: 16),
            _ActivityLegend(color: Colors.green[400]!, label: '5+ reviews'),
          ],
        ),
      ],
    );
  }

  List<List<DateTime>> _generateCalendarWeeks() {
    final weeks = <List<DateTime>>[];
    var current = DateTime(fromDate.year, fromDate.month, 1);

    // Pad first week
    final firstWeek = <DateTime>[];
    final startWeekday = current.weekday % 7; // Convert to Sun=0
    for (int i = 0; i < startWeekday; i++) {
      firstWeek.add(current.subtract(Duration(days: startWeekday - i)));
    }

    current = DateTime(fromDate.year, fromDate.month, 1);
    while (current.month == fromDate.month) {
      firstWeek.add(current);
      current = current.add(Duration(days: 1));
      if (firstWeek.length == 7) {
        weeks.add(firstWeek.toList());
        firstWeek.clear();
      }
    }

    // Add remaining days
    if (firstWeek.isNotEmpty) {
      while (firstWeek.length < 7) {
        firstWeek.add(current);
        current = current.add(Duration(days: 1));
      }
      weeks.add(firstWeek);
    }

    return weeks;
  }
}

class _ActivityDot extends StatelessWidget {
  final DateTime date;
  final int reviewCount;

  const _ActivityDot({Key? key, required this.date, required this.reviewCount})
    : super(key: key);

  Color _getColor() {
    if (reviewCount == 0) return Colors.grey[300]!;
    if (reviewCount < 5) return Colors.orange[200]!;
    return Colors.green[400]!;
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${date.day} reviews: $reviewCount',
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _getColor(),
          border: reviewCount > 0
              ? Border.all(color: Colors.grey[400]!, width: 0.5)
              : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: reviewCount > 0
              ? Text(
                  reviewCount > 9 ? '💯' : reviewCount.toString(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                )
              : SizedBox(),
        ),
      ),
    );
  }
}

class _ActivityLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ActivityLegend({Key? key, required this.color, required this.label})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}

/// Mini progress indicator for inline display
class MiniProgressIndicator extends StatelessWidget {
  final int completed;
  final int total;
  final double height;

  const MiniProgressIndicator({
    Key? key,
    required this.completed,
    required this.total,
    this.height = 6,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = completed / total;
    final color = percentage >= 1.0
        ? Colors.green
        : percentage >= 0.5
        ? Colors.blue
        : Colors.orange;

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: percentage.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: Colors.grey[300],
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}
