import 'package:intl/intl.dart';

/// Service for generating streak calendar data
/// Handles date calculations, active days, and statistics
class StreakCalendarService {
  /// Generate calendar data for a specific month with proper weekday alignment
  /// Returns a map of dates to their streak status
  static Map<DateTime, StreakDayData> generateCalendarData({
    required int currentStreak,
    required int longestStreak,
    required DateTime lastActivityDate,
    DateTime? forMonth,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Use provided month or current month
    final targetMonth = forMonth ?? today;
    final monthStart = DateTime(targetMonth.year, targetMonth.month, 1);

    // Get the first day of the month and find the Monday of that week
    final firstDayWeekday = monthStart.weekday; // 1=Monday, 7=Sunday
    final daysBeforeMonth = firstDayWeekday - 1; // Days from previous month
    final startDate = monthStart.subtract(Duration(days: daysBeforeMonth));

    // Get the last day of the month
    final lastDayOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0);
    final lastDayWeekday = lastDayOfMonth.weekday;
    final daysAfterMonth = 7 - lastDayWeekday; // Days for next month

    final endDate = lastDayOfMonth.add(Duration(days: daysAfterMonth));

    final calendarData = <DateTime, StreakDayData>{};

    // Generate streak days backwards from today
    Set<DateTime> streakDays = _generateStreakDays(
      streakCount: currentStreak,
      lastActivityDate: lastActivityDate,
    );

    // Fill calendar from startDate to endDate
    var currentDate = startDate;
    while (!currentDate.isAfter(endDate)) {
      final dateOnly = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
      );

      final isActive = streakDays.contains(dateOnly);
      final isToday = dateOnly.isAtSameMomentAs(today);
      final isFuture = dateOnly.isAfter(today);
      final isCurrentMonth =
          dateOnly.month == monthStart.month &&
          dateOnly.year == monthStart.year;
      final isMissed = !isActive && !isFuture && !isToday && isCurrentMonth;

      calendarData[dateOnly] = StreakDayData(
        date: dateOnly,
        isActive: isActive,
        isToday: isToday,
        isMissed: isMissed,
        isFuture: isFuture,
        isCurrentMonth: isCurrentMonth,
        dayNumber: dateOnly.day,
        weekday: dateOnly.weekday,
      );

      currentDate = currentDate.add(Duration(days: 1));
    }

    return calendarData;
  }

  /// Generate the set of active streak days
  static Set<DateTime> _generateStreakDays({
    required int streakCount,
    required DateTime lastActivityDate,
  }) {
    if (streakCount == 0) return {};

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final streakDays = <DateTime>{};

    // Add current day
    streakDays.add(today);

    // Add previous streak days (backwards)
    for (int i = 1; i < streakCount; i++) {
      final prevDate = today.subtract(Duration(days: i));
      streakDays.add(prevDate);
    }

    return streakDays;
  }

  /// Get week data for a given date range
  static List<WeekData> generateWeekData(
    Map<DateTime, StreakDayData> calendarData,
  ) {
    final weeks = <WeekData>[];
    final sortedDates = calendarData.keys.toList()..sort();

    for (int i = 0; i < sortedDates.length; i += 7) {
      final weekDays = sortedDates.skip(i).take(7).toList();
      final startDate = weekDays.first;
      final monthName = _getMonthName(startDate);

      weeks.add(
        WeekData(
          startDate: startDate,
          days: weekDays.map((d) => calendarData[d]!).toList(),
          monthName: monthName,
          weekNumber: (i ~/ 7) + 1,
        ),
      );
    }

    return weeks;
  }

  /// Get month statistics for a specific month
  static MonthStats getMonthStats({
    required Map<DateTime, StreakDayData> calendarData,
    required int currentStreak,
    required int longestStreak,
    DateTime? forMonth,
  }) {
    final now = DateTime.now();
    final targetMonth = forMonth ?? DateTime(now.year, now.month);

    int daysStudiedThisMonth = 0;
    final lastDayOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0);
    int totalDaysInMonth = lastDayOfMonth.day;

    calendarData.forEach((date, data) {
      if (date.year == targetMonth.year &&
          date.month == targetMonth.month &&
          data.isActive) {
        daysStudiedThisMonth++;
      }
    });

    final consistency = totalDaysInMonth > 0
        ? (daysStudiedThisMonth / totalDaysInMonth * 100).round()
        : 0;

    return MonthStats(
      daysStudied: daysStudiedThisMonth,
      totalDays: totalDaysInMonth,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      consistencyPercentage: consistency,
    );
  }

  /// Get motivational message based on streak
  static String getMotivationalMessage(int streak) {
    if (streak >= 30) return 'You\'re a study superstar! 🌟';
    if (streak >= 14) return 'Two weeks of consistency! Keep crushing it!';
    if (streak >= 7) return 'One week down! You\'re unstoppable! 🚀';
    if (streak >= 3) return 'Building momentum! 🔥';
    if (streak >= 1) return 'Great start! Keep it going! 💪';
    return 'Start your streak today! 🎯';
  }

  static String _getMonthName(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }
}

/// Data class for a single day in the streak calendar
class StreakDayData {
  final DateTime date;
  final bool isActive; // Part of current streak
  final bool isToday; // Is today
  final bool isMissed; // Missed (gap in streak)
  final bool isFuture; // Future date
  final bool isCurrentMonth; // In the target month
  final int dayNumber; // Day of month (1-31)
  final int weekday; // 1=Monday, 7=Sunday

  StreakDayData({
    required this.date,
    required this.isActive,
    required this.isToday,
    required this.isMissed,
    required this.isFuture,
    required this.isCurrentMonth,
    required this.dayNumber,
    required this.weekday,
  });

  String getWeekdayShort() {
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday];
  }
}

/// Data class for a week of days
class WeekData {
  final DateTime startDate;
  final List<StreakDayData> days;
  final String monthName;
  final int weekNumber;

  WeekData({
    required this.startDate,
    required this.days,
    required this.monthName,
    required this.weekNumber,
  });
}

/// Statistics for the current month
class MonthStats {
  final int daysStudied;
  final int totalDays;
  final int currentStreak;
  final int longestStreak;
  final int consistencyPercentage;

  MonthStats({
    required this.daysStudied,
    required this.totalDays,
    required this.currentStreak,
    required this.longestStreak,
    required this.consistencyPercentage,
  });
}
