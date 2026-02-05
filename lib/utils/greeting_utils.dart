import '../services/user_profile_service.dart';
import 'package:flutter/material.dart';
import 'app_localizations.dart';

/// Utility class for generating time-based greetings
class GreetingUtils {
  /// Returns the appropriate greeting based on the current time
  /// Morning: 5:00 - 11:59
  /// Afternoon: 12:00 - 17:59
  /// Evening: 18:00 - 4:59
  static String getGreeting({BuildContext? context}) {
    final now = DateTime.now();
    final hour = now.hour;

    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (hour >= 5 && hour < 12) {
        return localizations.t('greeting.morningGreeting');
      } else if (hour >= 12 && hour < 18) {
        return localizations.t('greeting.afternoonGreeting');
      } else {
        return localizations.t('greeting.eveningGreeting');
      }
    } else {
      // Fallback to English if context is not provided
      if (hour >= 5 && hour < 12) {
        return 'How can I help you this morning?';
      } else if (hour >= 12 && hour < 18) {
        return 'How can I help you this afternoon?';
      } else {
        return 'How can I help you this evening?';
      }
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

  /// Returns the time period name (Morning/Afternoon/Evening)
  static String getTimePeriod({BuildContext? context}) {
    final now = DateTime.now();
    final hour = now.hour;

    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (hour >= 5 && hour < 12) {
        return localizations.t('greeting.goodMorning');
      } else if (hour >= 12 && hour < 18) {
        return localizations.t('greeting.goodAfternoon');
      } else {
        return localizations.t('greeting.goodEvening');
      }
    } else {
      // Fallback to English
      if (hour >= 5 && hour < 12) {
        return 'Morning';
      } else if (hour >= 12 && hour < 18) {
        return 'Afternoon';
      } else {
        return 'Evening';
      }
    }
  }

  /// Returns a personalized greeting with the user's name
  /// Format: "Good Morning, {username}. What can we do today?"
  static String getPersonalizedGreeting({
    String? username,
    BuildContext? context,
  }) {
    final timePeriod = getTimePeriod(context: context);
    final name = username ?? UserProfileService.instance.getDisplayNameSync();
    final whatCanWeDo = context != null
        ? AppLocalizations.of(context).t('greeting.whatCanWeDo')
        : 'What can we do today?';

    return '$timePeriod, $name. $whatCanWeDo';
  }

  /// Returns a personalized greeting asynchronously (fetches username if needed)
  static Future<String> getPersonalizedGreetingAsync({
    BuildContext? context,
  }) async {
    final timePeriod = getTimePeriod(context: context);
    final name = await UserProfileService.instance.getDisplayName();
    final whatCanWeDo = context != null
        ? AppLocalizations.of(context).t('greeting.whatCanWeDo')
        : 'What can we do today?';

    return '$timePeriod, $name. $whatCanWeDo';
  }

  /// Returns just the greeting prefix without the question
  /// Format: "Good Morning, {username}"
  static String getGreetingPrefix({String? username, BuildContext? context}) {
    final timePeriod = getTimePeriod(context: context);
    final name = username ?? UserProfileService.instance.getDisplayNameSync();

    return '$timePeriod, $name';
  }
}
