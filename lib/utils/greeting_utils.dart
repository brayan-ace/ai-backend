/// Utility class for generating time-based greetings
class GreetingUtils {
  /// Returns the appropriate greeting based on the current time
  /// Morning: 5:00 - 11:59
  /// Afternoon: 12:00 - 17:59
  /// Evening: 18:00 - 4:59
  static String getGreeting() {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour >= 5 && hour < 12) {
      return 'How can I help you this morning?';
    } else if (hour >= 12 && hour < 18) {
      return 'How can I help you this afternoon?';
    } else {
      return 'How can I help you this evening?';
    }
  }

  /// Returns the time of day as a string for icon selection
  static String getTimeOfDay() {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour >= 5 && hour < 12) {
      return 'morning';
    } else if (hour >= 12 && hour < 18) {
      return 'afternoon';
    } else {
      return 'evening';
    }
  }
}
