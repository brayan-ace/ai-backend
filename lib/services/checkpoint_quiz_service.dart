import 'package:http/http.dart' as http;
import 'dart:convert';

class CheckpointQuiz {
  final String concept;
  final List<CheckpointQuestion> questions;
  final int passingScore;
  final int timeLimitSeconds;

  CheckpointQuiz({
    required this.concept,
    required this.questions,
    required this.passingScore,
    required this.timeLimitSeconds,
  });

  factory CheckpointQuiz.fromJson(Map<String, dynamic> json) {
    final questions =
        (json['questions'] as List?)
            ?.map((q) => CheckpointQuestion.fromJson(q))
            .toList() ??
        [];
    return CheckpointQuiz(
      concept: json['concept'] ?? 'Unknown Concept',
      questions: questions,
      passingScore: json['passing_score'] ?? 2,
      timeLimitSeconds: json['time_limit_seconds'] ?? 180,
    );
  }
}

class CheckpointQuestion {
  final int id;
  final String type; // 'mcq' or 'short_answer'
  final String question;
  final List<String>? options;
  final String? correctOption;
  final String? explanation;

  CheckpointQuestion({
    required this.id,
    required this.type,
    required this.question,
    this.options,
    this.correctOption,
    this.explanation,
  });

  factory CheckpointQuestion.fromJson(Map<String, dynamic> json) {
    return CheckpointQuestion(
      id: json['id'] ?? 0,
      type: json['type'] ?? 'mcq',
      question: json['question'] ?? '',
      options: (json['options'] as List?)?.map((o) => o.toString()).toList(),
      correctOption: json['correct_option'],
      explanation: json['explanation'],
    );
  }
}

class CheckpointQuizResult {
  final bool passed;
  final int score;
  final int totalQuestions;
  final double scorePercentage;
  final double passingThreshold;
  final String message;
  final String nextAction; // 'concept_advance' or 'concept_review'

  CheckpointQuizResult({
    required this.passed,
    required this.score,
    required this.totalQuestions,
    required this.scorePercentage,
    required this.passingThreshold,
    required this.message,
    required this.nextAction,
  });

  factory CheckpointQuizResult.fromJson(Map<String, dynamic> json) {
    return CheckpointQuizResult(
      passed: json['passed'] ?? false,
      score: json['score'] ?? 0,
      totalQuestions: json['totalQuestions'] ?? 0,
      scorePercentage: double.parse(json['scorePercentage']?.toString() ?? '0'),
      passingThreshold: double.parse(
        json['passingThreshold']?.toString() ?? '66.7',
      ),
      message: json['message'] ?? '',
      nextAction: json['nextAction'] ?? 'concept_review',
    );
  }
}

class CheckpointQuizService {
  final String backendUrl;

  CheckpointQuizService({required this.backendUrl});

  /// Submit checkpoint quiz answers
  Future<CheckpointQuizResult> submitQuizAnswers({
    required String botId,
    required String userId,
    required int moduleIndex,
    required int conceptIndex,
    required List<String> answers,
    required List<String> correctAnswers,
  }) async {
    try {
      final uri = Uri.parse('$backendUrl/api/submit-checkpoint-quiz');
      final payload = {
        'botId': botId,
        'userId': userId,
        'moduleIndex': moduleIndex,
        'conceptIndex': conceptIndex,
        'answers': answers,
        'correctAnswers': correctAnswers,
      };

      print('[Checkpoint] Submitting quiz answers for concept $conceptIndex');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final result = CheckpointQuizResult.fromJson(body);
        print(
          '[Checkpoint] Quiz submitted: ${result.passed ? "PASSED" : "FAILED"} (${result.scorePercentage.toStringAsFixed(1)}%)',
        );
        return result;
      } else {
        throw Exception('Failed to submit quiz: ${response.statusCode}');
      }
    } catch (e) {
      print('[Checkpoint] Error submitting quiz: $e');
      rethrow;
    }
  }

  /// Fetch struggle signals for analytics
  Future<List<StruggleSignal>> getStruggleSignals({
    required String botId,
    required String userId,
    int? moduleIndex,
    int? conceptIndex,
  }) async {
    try {
      String query = '$backendUrl/api/struggle-signals/$botId/$userId';
      if (moduleIndex != null) query += '?moduleIndex=$moduleIndex';
      if (conceptIndex != null) {
        query += moduleIndex != null ? '&' : '?';
        query += 'conceptIndex=$conceptIndex';
      }

      final response = await http
          .get(Uri.parse(query))
          .timeout(Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final signals =
            (body['signals'] as List?)
                ?.map((s) => StruggleSignal.fromJson(s))
                .toList() ??
            [];
        print('[Struggle] Retrieved ${signals.length} struggle signals');
        return signals;
      } else {
        return [];
      }
    } catch (e) {
      print('[Struggle] Error fetching signals: $e');
      return [];
    }
  }

  /// Fetch concept performance metrics
  Future<List<ConceptPerformance>> getConceptPerformance({
    required String botId,
    required String userId,
  }) async {
    try {
      final response = await http
          .get(Uri.parse('$backendUrl/api/concept-performance/$botId/$userId'))
          .timeout(Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final concepts =
            (body['concepts'] as List?)
                ?.map((c) => ConceptPerformance.fromJson(c))
                .toList() ??
            [];
        print(
          '[Performance] Retrieved metrics for ${concepts.length} concepts',
        );
        return concepts;
      } else {
        return [];
      }
    } catch (e) {
      print('[Performance] Error fetching metrics: $e');
      return [];
    }
  }
}

class StruggleSignal {
  final int id;
  final String signalType;
  final double confidence;
  final String? recommendation;
  final DateTime detectedAt;
  final bool interventionApplied;
  final String? interventionType;

  StruggleSignal({
    required this.id,
    required this.signalType,
    required this.confidence,
    this.recommendation,
    required this.detectedAt,
    required this.interventionApplied,
    this.interventionType,
  });

  factory StruggleSignal.fromJson(Map<String, dynamic> json) {
    final signalValue = json['signal_value'] as Map<String, dynamic>? ?? {};
    return StruggleSignal(
      id: json['id'] ?? 0,
      signalType: json['signal_type'] ?? 'unknown',
      confidence: double.parse(signalValue['confidence']?.toString() ?? '0.5'),
      recommendation: signalValue['recommendation'],
      detectedAt: DateTime.parse(
        json['detected_at'] ?? DateTime.now().toIso8601String(),
      ),
      interventionApplied: json['intervention_applied'] ?? false,
      interventionType: json['intervention_type'],
    );
  }

  String getReadableType() {
    switch (signalType) {
      case 'explicit_confusion':
        return 'Confusion Detected';
      case 'clarification_request':
        return 'Needs Clarification';
      case 'frustration_detected':
        return 'Frustration Detected';
      case 'disengagement_pattern':
        return 'Disengagement';
      case 'concept_mismatch':
        return 'Concept Mismatch';
      default:
        return 'Learning Challenge';
    }
  }
}

class ConceptPerformance {
  final int id;
  final int moduleIndex;
  final int conceptIndex;
  final int? timeToUnderstandSeconds;
  final int explanationRequests;
  final double? quizScore;
  final String? confidenceLevel;
  final DateTime? lastReviewed;
  final DateTime createdAt;
  final DateTime updatedAt;

  ConceptPerformance({
    required this.id,
    required this.moduleIndex,
    required this.conceptIndex,
    this.timeToUnderstandSeconds,
    required this.explanationRequests,
    this.quizScore,
    this.confidenceLevel,
    this.lastReviewed,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ConceptPerformance.fromJson(Map<String, dynamic> json) {
    return ConceptPerformance(
      id: json['id'] ?? 0,
      moduleIndex: json['module_index'] ?? 0,
      conceptIndex: json['concept_index'] ?? 0,
      timeToUnderstandSeconds: json['time_to_understand_seconds'],
      explanationRequests: json['explanation_requests'] ?? 0,
      quizScore: json['quiz_score'] != null
          ? double.parse(json['quiz_score'].toString())
          : null,
      confidenceLevel: json['confidence_level'],
      lastReviewed: json['last_reviewed'] != null
          ? DateTime.parse(json['last_reviewed'])
          : null,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  bool get isDifficult => quizScore != null && quizScore! < 70;
  bool get isStruggling =>
      explanationRequests > 2 || (timeToUnderstandSeconds ?? 0) > 600;
}
