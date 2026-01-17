/// Progress Tracking Service
/// Manages dynamic progress tracking with milestones, module completion,
/// and persistent progress across sessions

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Represents a learning milestone
class Milestone {
  final String id;
  final String description;
  final double progress; // 0.0 to 1.0
  final DateTime achievedAt;
  final String type; // 'concept_mastery', 'module_complete', 'quiz_passed'
  final Map<String, dynamic>? metadata;

  Milestone({
    required this.id,
    required this.description,
    required this.progress,
    required this.achievedAt,
    required this.type,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'progress': progress,
    'achievedAt': achievedAt.toIso8601String(),
    'type': type,
    'metadata': metadata,
  };

  factory Milestone.fromJson(Map<String, dynamic> json) => Milestone(
    id: json['id'] as String,
    description: json['description'] as String,
    progress: (json['progress'] as num).toDouble(),
    achievedAt: DateTime.parse(json['achievedAt'] as String),
    type: json['type'] as String,
    metadata: json['metadata'] as Map<String, dynamic>?,
  );
}

/// Progress tracking data
class ProgressData {
  final String sessionId;
  final double overallProgress; // 0.0 to 1.0
  final int currentModuleNumber;
  final int totalModules;
  final List<Milestone> milestones;
  final List<String> completedModules;
  final DateTime lastUpdated;
  final double estimatedCompletion; // 0.0 to 1.0

  ProgressData({
    required this.sessionId,
    this.overallProgress = 0.0,
    this.currentModuleNumber = 1,
    this.totalModules = 8,
    this.milestones = const [],
    this.completedModules = const [],
    required this.lastUpdated,
    this.estimatedCompletion = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'overallProgress': overallProgress,
    'currentModuleNumber': currentModuleNumber,
    'totalModules': totalModules,
    'milestones': milestones.map((m) => m.toJson()).toList(),
    'completedModules': completedModules,
    'lastUpdated': lastUpdated.toIso8601String(),
    'estimatedCompletion': estimatedCompletion,
  };

  factory ProgressData.fromJson(Map<String, dynamic> json) => ProgressData(
    sessionId: json['sessionId'] as String,
    overallProgress: (json['overallProgress'] as num?)?.toDouble() ?? 0.0,
    currentModuleNumber: json['currentModuleNumber'] as int? ?? 1,
    totalModules: json['totalModules'] as int? ?? 8,
    milestones:
        (json['milestones'] as List?)
            ?.map((m) => Milestone.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [],
    completedModules: List<String>.from(
      json['completedModules'] as List? ?? [],
    ),
    lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    estimatedCompletion:
        (json['estimatedCompletion'] as num?)?.toDouble() ?? 0.0,
  );

  /// Copy with modified fields
  ProgressData copyWith({
    double? overallProgress,
    int? currentModuleNumber,
    int? totalModules,
    List<Milestone>? milestones,
    List<String>? completedModules,
    double? estimatedCompletion,
  }) => ProgressData(
    sessionId: sessionId,
    overallProgress: overallProgress ?? this.overallProgress,
    currentModuleNumber: currentModuleNumber ?? this.currentModuleNumber,
    totalModules: totalModules ?? this.totalModules,
    milestones: milestones ?? this.milestones,
    completedModules: completedModules ?? this.completedModules,
    lastUpdated: DateTime.now(),
    estimatedCompletion: estimatedCompletion ?? this.estimatedCompletion,
  );
}

/// Progress Tracking Service
class ProgressTrackingService {
  static final ProgressTrackingService _instance =
      ProgressTrackingService._internal();

  factory ProgressTrackingService() => _instance;
  ProgressTrackingService._internal();

  static const String _progressKey = 'myai_progress_data_v1';

  /// Initialize progress for a new session
  Future<ProgressData> initializeProgress(
    String sessionId,
    int totalModules,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final progress = ProgressData(
      sessionId: sessionId,
      currentModuleNumber: 1,
      totalModules: totalModules,
      lastUpdated: DateTime.now(),
    );

    await _saveProgress(prefs, progress);
    return progress;
  }

  /// Get progress for a session
  Future<ProgressData?> getProgress(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_progressKey}_$sessionId');

    if (raw == null || raw.isEmpty) return null;

    try {
      return ProgressData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      print('[ProgressTracking] Error loading progress: $e');
      return null;
    }
  }

  /// Add milestone and update progress
  Future<ProgressData> addMilestone(
    String sessionId,
    String description,
    String type, {
    double? progressIncrement,
    Map<String, dynamic>? metadata,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    var progress = await getProgress(sessionId);

    if (progress == null) {
      throw Exception('Progress not initialized for session $sessionId');
    }

    final milestone = Milestone(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      description: description,
      progress: progress.overallProgress + (progressIncrement ?? 0.1),
      achievedAt: DateTime.now(),
      type: type,
      metadata: metadata,
    );

    final newMilestones = [...progress.milestones, milestone];
    final newProgress = (progressIncrement ?? 0.1) + progress.overallProgress;

    progress = progress.copyWith(
      milestones: newMilestones,
      overallProgress: newProgress.clamp(0.0, 1.0),
    );

    await _saveProgress(prefs, progress);
    return progress;
  }

  /// Mark module as completed
  Future<ProgressData> completeModule(
    String sessionId,
    int moduleNumber,
    String moduleName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    var progress = await getProgress(sessionId);

    if (progress == null) {
      throw Exception('Progress not initialized for session $sessionId');
    }

    final completed = [...progress.completedModules, moduleName];
    final progressIncrement = 1.0 / progress.totalModules;
    final newProgress = progress.overallProgress + progressIncrement;

    progress = progress.copyWith(
      completedModules: completed,
      currentModuleNumber: moduleNumber + 1,
      overallProgress: newProgress.clamp(0.0, 1.0),
    );

    // Add milestone
    final milestone = Milestone(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      description: 'Completed Module $moduleNumber: $moduleName',
      progress: newProgress,
      achievedAt: DateTime.now(),
      type: 'module_complete',
      metadata: {'moduleNumber': moduleNumber, 'moduleName': moduleName},
    );

    progress = progress.copyWith(
      milestones: [...progress.milestones, milestone],
    );

    await _saveProgress(prefs, progress);
    return progress;
  }

  /// Record concept mastery
  Future<ProgressData> recordConceptMastery(
    String sessionId,
    String conceptName,
    double masteryLevel,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    var progress = await getProgress(sessionId);

    if (progress == null) {
      throw Exception('Progress not initialized for session $sessionId');
    }

    // Small progress increment for concept mastery
    final increment = 0.02 * masteryLevel.clamp(0.0, 1.0);
    final newProgress = progress.overallProgress + increment;

    final milestone = Milestone(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      description: 'Mastered: $conceptName',
      progress: newProgress,
      achievedAt: DateTime.now(),
      type: 'concept_mastery',
      metadata: {'concept': conceptName, 'masteryLevel': masteryLevel},
    );

    progress = progress.copyWith(
      milestones: [...progress.milestones, milestone],
      overallProgress: newProgress.clamp(0.0, 1.0),
    );

    await _saveProgress(prefs, progress);
    return progress;
  }

  /// Record quiz performance
  Future<ProgressData> recordQuizPerformance(
    String sessionId,
    String quizTitle,
    double scorePercentage,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    var progress = await getProgress(sessionId);

    if (progress == null) {
      throw Exception('Progress not initialized for session $sessionId');
    }

    // Progress based on score
    final baseIncrement = 0.05;
    final increment = baseIncrement * (scorePercentage / 100.0);
    final newProgress = progress.overallProgress + increment;

    final milestone = Milestone(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      description:
          'Quiz Passed: $quizTitle (${scorePercentage.toStringAsFixed(1)}%)',
      progress: newProgress,
      achievedAt: DateTime.now(),
      type: 'quiz_passed',
      metadata: {'quizTitle': quizTitle, 'scorePercentage': scorePercentage},
    );

    progress = progress.copyWith(
      milestones: [...progress.milestones, milestone],
      overallProgress: newProgress.clamp(0.0, 1.0),
    );

    await _saveProgress(prefs, progress);
    return progress;
  }

  /// Update estimated completion time
  Future<ProgressData> updateEstimatedCompletion(
    String sessionId,
    double estimatedCompletion,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    var progress = await getProgress(sessionId);

    if (progress == null) {
      throw Exception('Progress not initialized for session $sessionId');
    }

    progress = progress.copyWith(
      estimatedCompletion: estimatedCompletion.clamp(0.0, 1.0),
    );

    await _saveProgress(prefs, progress);
    return progress;
  }

  /// Get milestone history for a session
  Future<List<Milestone>> getMilestoneHistory(String sessionId) async {
    final progress = await getProgress(sessionId);
    return progress?.milestones ?? [];
  }

  /// Get recent milestones (last N)
  Future<List<Milestone>> getRecentMilestones(
    String sessionId, {
    int count = 5,
  }) async {
    final progress = await getProgress(sessionId);
    if (progress == null) return [];

    return progress.milestones.length > count
        ? progress.milestones.sublist(progress.milestones.length - count)
        : progress.milestones;
  }

  /// Reset progress for a session
  Future<void> resetProgress(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_progressKey}_$sessionId');
  }

  /// Delete all progress data
  Future<void> deleteAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith(_progressKey))
        .toList();

    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  // ===== PRIVATE HELPERS =====

  Future<void> _saveProgress(SharedPreferences prefs, ProgressData data) async {
    await prefs.setString(
      '${_progressKey}_${data.sessionId}',
      jsonEncode(data.toJson()),
    );
  }
}
