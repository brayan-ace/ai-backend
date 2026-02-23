/// Spaced Repetition Service - Implements SM-2 algorithm for optimal review scheduling
///
/// The SM-2 algorithm calculates optimal review intervals based on:
/// - Recall quality (0-5 scale)
/// - Easiness factor of the material
/// - Previous intervals
class SpacedRepetitionService {
  // SM-2 algorithm constants
  static const double INITIAL_EASINESS = 2.5;
  static const int INITIAL_INTERVAL = 1; // 1 day
  static const double EASINESS_MIN = 1.3;

  /// Calculate next review date based on SM-2 algorithm
  ///
  /// Parameters:
  /// - lastReviewDate: When the concept was last reviewed
  /// - quality: User response quality (0-5 scale)
  ///   0-2: Forgot/Poor - new interval starts at 1 day
  ///   3-4: Acceptable - interval increases
  ///   5: Perfect - maximum interval increase
  /// - easiness: Easiness factor (affects difficulty perception)
  /// - previousInterval: Days since last review
  ///
  /// Returns: Map with nextReviewDate, newEasiness, newInterval
  static Map<String, dynamic> calculateNextReview({
    required DateTime lastReviewDate,
    required int quality,
    required double easiness,
    required int previousInterval,
  }) {
    // Validate quality score
    if (quality < 0 || quality > 5) {
      throw ArgumentError('Quality must be between 0 and 5');
    }

    double newEasiness;
    int newInterval;

    if (quality < 3) {
      // Failed - reset to 1 day
      newInterval = 1;
      newEasiness = easiness; // Keep same easiness
    } else {
      // Passed - calculate new interval
      if (previousInterval == 0 || previousInterval == 1) {
        // First review
        newInterval = 3; // 3 days
      } else if (previousInterval == 3) {
        // Second review
        newInterval = 7; // 7 days
      } else {
        // Subsequent reviews - multiply by easiness factor
        newInterval = (previousInterval * easiness).round();
      }

      // Update easiness factor using SM-2 formula
      newEasiness =
          easiness + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));

      // Ensure easiness factor doesn't go below minimum
      if (newEasiness < EASINESS_MIN) {
        newEasiness = EASINESS_MIN;
      }
    }

    final nextReviewDate = lastReviewDate.add(Duration(days: newInterval));

    return {
      'nextReviewDate': nextReviewDate,
      'newEasiness': newEasiness,
      'newInterval': newInterval,
      'quality': quality,
    };
  }

  /// Determine if a concept needs review based on current date
  static bool needsReview(
    DateTime? lastReviewDate, {
    Duration? customThreshold,
  }) {
    if (lastReviewDate == null) return false;

    final threshold = customThreshold ?? Duration(days: 0);
    return DateTime.now().isAfter(lastReviewDate.add(threshold));
  }

  /// Get review urgency (0-1, where 1 is most urgent)
  static double getReviewUrgency(DateTime reviewDate) {
    final now = DateTime.now();
    if (now.isBefore(reviewDate)) {
      return 0; // Not due yet
    }

    final daysOverdue = now.difference(reviewDate).inDays;
    // Urgency increases by 0.1 for each day overdue (capped at 1.0)
    return (daysOverdue * 0.1).clamp(0, 1.0);
  }

  /// Generate review schedule for the next N days
  static List<ScheduledReview> generateReviewSchedule({
    required List<ConceptReview> concepts,
    required int daysAhead,
  }) {
    final schedule = <ScheduledReview>[];
    final now = DateTime.now();

    for (var i = 0; i <= daysAhead; i++) {
      final targetDate = now.add(Duration(days: i));
      final dayReviews = concepts.where((c) {
        if (c.nextReviewDate == null) return false;
        return c.nextReviewDate!.year == targetDate.year &&
            c.nextReviewDate!.month == targetDate.month &&
            c.nextReviewDate!.day == targetDate.day;
      }).toList();

      if (dayReviews.isNotEmpty) {
        schedule.add(
          ScheduledReview(
            date: targetDate,
            concepts: dayReviews,
            isToday: i == 0,
            isPastDue: i < 0,
          ),
        );
      }
    }

    return schedule;
  }

  /// Get recommended daily goal for reviews
  static int getRecommendedDailyGoal(List<ConceptReview> concepts) {
    int overdue = 0;
    int dueToday = 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var concept in concepts) {
      if (concept.nextReviewDate == null) continue;

      final reviewDate = DateTime(
        concept.nextReviewDate!.year,
        concept.nextReviewDate!.month,
        concept.nextReviewDate!.day,
      );

      if (reviewDate.isBefore(today)) {
        overdue++;
      } else if (reviewDate == today) {
        dueToday++;
      } else if (reviewDate.isBefore(today.add(Duration(days: 7)))) {
        // Not tracking dueSoon in daily goal calculation
      }
    }

    // Recommend 5-10 reviews per day depending on backlog
    if (overdue > 20) return 20; // Heavy backlog
    if (overdue > 10) return 15;
    if (overdue > 0) return 10;
    if (dueToday > 0) return dueToday + 3;
    return 5; // Default
  }
}

/// Model for tracking concept review history
class ConceptReview {
  final int conceptIndex;
  final int moduleIndex;
  final double easinessFactor;
  final DateTime? lastReviewDate;
  final DateTime? nextReviewDate;
  final int intervalDays;
  final int reviewCount;
  final int qualityHistory; // Stores last quality score
  final DateTime createdAt;
  final DateTime updatedAt;

  ConceptReview({
    required this.conceptIndex,
    required this.moduleIndex,
    this.easinessFactor = SpacedRepetitionService.INITIAL_EASINESS,
    this.lastReviewDate,
    this.nextReviewDate,
    this.intervalDays = 1,
    this.reviewCount = 0,
    this.qualityHistory = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create updated concept review after a review session
  ConceptReview withReviewUpdate({
    required int quality,
    required Map<String, dynamic> nextReviewCalc,
  }) {
    return ConceptReview(
      conceptIndex: conceptIndex,
      moduleIndex: moduleIndex,
      easinessFactor: nextReviewCalc['newEasiness'],
      lastReviewDate: DateTime.now(),
      nextReviewDate: nextReviewCalc['nextReviewDate'],
      intervalDays: nextReviewCalc['newInterval'],
      reviewCount: reviewCount + 1,
      qualityHistory: quality,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  factory ConceptReview.fromJson(Map<String, dynamic> json) {
    return ConceptReview(
      conceptIndex: json['concept_index'] ?? 0,
      moduleIndex: json['module_index'] ?? 0,
      easinessFactor: double.parse(
        json['easiness_factor']?.toString() ?? '2.5',
      ),
      lastReviewDate: json['last_review_date'] != null
          ? DateTime.parse(json['last_review_date'])
          : null,
      nextReviewDate: json['next_review_date'] != null
          ? DateTime.parse(json['next_review_date'])
          : null,
      intervalDays: json['interval_days'] ?? 1,
      reviewCount: json['review_count'] ?? 0,
      qualityHistory: json['quality_history'] ?? 0,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'concept_index': conceptIndex,
      'module_index': moduleIndex,
      'easiness_factor': easinessFactor,
      'last_review_date': lastReviewDate?.toIso8601String(),
      'next_review_date': nextReviewDate?.toIso8601String(),
      'interval_days': intervalDays,
      'review_count': reviewCount,
      'quality_history': qualityHistory,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isOverdue {
    if (nextReviewDate == null) return false;
    return DateTime.now().isAfter(nextReviewDate!);
  }

  bool get isDueToday {
    if (nextReviewDate == null) return false;
    final today = DateTime.now();
    return today.year == nextReviewDate!.year &&
        today.month == nextReviewDate!.month &&
        today.day == nextReviewDate!.day;
  }

  int get daysUntilDue {
    if (nextReviewDate == null) return -1;
    return nextReviewDate!.difference(DateTime.now()).inDays;
  }
}

/// Scheduled review for display in UI
class ScheduledReview {
  final DateTime date;
  final List<ConceptReview> concepts;
  final bool isToday;
  final bool isPastDue;

  ScheduledReview({
    required this.date,
    required this.concepts,
    this.isToday = false,
    this.isPastDue = false,
  });

  int get daysFromNow {
    final now = DateTime.now();
    return date.difference(now).inDays;
  }

  String get dateLabel {
    if (isToday) return 'Today';
    if (isPastDue) return 'Overdue';
    final daysFromNow = this.daysFromNow;
    if (daysFromNow == 1) return 'Tomorrow';
    if (daysFromNow <= 7) return 'In $daysFromNow days';
    // Format as date
    return '${date.month}/${date.day}';
  }
}

/// Spaced Repetition Statistics
class SpacedRepetitionStats {
  final int totalConcepts;
  final int conceptsMastered;
  final int conceptsLearning;
  final int conceptsReview;
  final int overdueConcepts;
  final int reviewsToday;
  final double averageEasiness;
  final double masteryPercentage;

  SpacedRepetitionStats({
    required this.totalConcepts,
    required this.conceptsMastered,
    required this.conceptsLearning,
    required this.conceptsReview,
    required this.overdueConcepts,
    required this.reviewsToday,
    required this.averageEasiness,
    required this.masteryPercentage,
  });

  factory SpacedRepetitionStats.fromConcepts(List<ConceptReview> concepts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final overdue = concepts.where((c) {
      if (c.nextReviewDate == null) return false;
      return DateTime(
        c.nextReviewDate!.year,
        c.nextReviewDate!.month,
        c.nextReviewDate!.day,
      ).isBefore(today);
    }).length;

    final dueToday = concepts.where((c) {
      if (c.nextReviewDate == null) return false;
      final reviewDate = DateTime(
        c.nextReviewDate!.year,
        c.nextReviewDate!.month,
        c.nextReviewDate!.day,
      );
      return reviewDate == today;
    }).length;

    final avgEasiness = concepts.isEmpty
        ? 2.5
        : concepts.fold<double>(0, (sum, c) => sum + c.easinessFactor) /
              concepts.length;

    final mastered = concepts
        .where((c) => c.reviewCount >= 2 && c.qualityHistory >= 4)
        .length;
    final learning = concepts
        .where((c) => c.reviewCount >= 1 && c.reviewCount < 2)
        .length;

    return SpacedRepetitionStats(
      totalConcepts: concepts.length,
      conceptsMastered: mastered,
      conceptsLearning: learning,
      conceptsReview: concepts.where((c) => c.reviewCount == 0).length,
      overdueConcepts: overdue,
      reviewsToday: dueToday,
      averageEasiness: avgEasiness,
      masteryPercentage: concepts.isEmpty
          ? 0
          : (mastered / concepts.length) * 100,
    );
  }
}
