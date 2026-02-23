import 'package:flutter/material.dart';
import '../services/checkpoint_quiz_service.dart';

class StruggleDetectionWidget extends StatelessWidget {
  final String struggles;
  final String? intervention;
  final VoidCallback? onAlternativeExplanation;
  final VoidCallback? onVisualExample;
  final VoidCallback? onBreak;
  final VoidCallback? onDismiss;

  const StruggleDetectionWidget({
    Key? key,
    required this.struggles,
    this.intervention,
    this.onAlternativeExplanation,
    this.onVisualExample,
    this.onBreak,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        border: Border(left: BorderSide(color: Colors.amber[600]!, width: 4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('🚨', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'I noticed you might be finding this challenging.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber[900],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Let me help! Here are some options:',
            style: TextStyle(fontSize: 13, color: Colors.amber[800]),
          ),
          SizedBox(height: 10),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAlternativeExplanation,
                  icon: Icon(Icons.lightbulb_outline, size: 16),
                  label: Text(
                    'Different Angle',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber[700],
                    side: BorderSide(color: Colors.amber[700]!),
                  ),
                ),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onVisualExample,
                  icon: Icon(Icons.image, size: 16),
                  label: Text('Show Example', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber[700],
                    side: BorderSide(color: Colors.amber[700]!),
                  ),
                ),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onBreak,
                  icon: Icon(Icons.coffee_outlined, size: 16),
                  label: Text('Take Break', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber[700],
                    side: BorderSide(color: Colors.amber[700]!),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget showing learning performance analytics
class LearningAnalyticsWidget extends StatefulWidget {
  final String botId;
  final String userId;
  final CheckpointQuizService quizService;

  const LearningAnalyticsWidget({
    Key? key,
    required this.botId,
    required this.userId,
    required this.quizService,
  }) : super(key: key);

  @override
  State<LearningAnalyticsWidget> createState() =>
      _LearningAnalyticsWidgetState();
}

class _LearningAnalyticsWidgetState extends State<LearningAnalyticsWidget> {
  late Future<List<ConceptPerformance>> performanceFuture;
  late Future<List<StruggleSignal>> struggleFuture;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  void _loadAnalytics() {
    performanceFuture = widget.quizService.getConceptPerformance(
      botId: widget.botId,
      userId: widget.userId,
    );
    struggleFuture = widget.quizService.getStruggleSignals(
      botId: widget.botId,
      userId: widget.userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Concept Performance Section
          Text(
            '📚 Concept Mastery Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6366F1),
            ),
          ),
          SizedBox(height: 12),
          FutureBuilder<List<ConceptPerformance>>(
            future: performanceFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No performance data yet',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                );
              }

              final performances = snapshot.data!;
              final avgScore =
                  performances
                      .where((p) => p.quizScore != null)
                      .fold<double>(0, (sum, p) => sum + (p.quizScore ?? 0)) /
                  performances.where((p) => p.quizScore != null).length;

              return Column(
                spacing: 12,
                children: [
                  // Average score card
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Average Mastery',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${avgScore.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Center(
                            child: Text(
                              avgScore > 80
                                  ? '⭐'
                                  : avgScore > 70
                                  ? '✅'
                                  : '📊',
                              style: TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Concept list
                  ...performances.map(
                    (p) => ConceptPerformanceCard(concept: p),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 24),

          // Struggle Detection Section
          Text(
            '🚨 Learning Challenges',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.amber[700],
            ),
          ),
          SizedBox(height: 12),
          FutureBuilder<List<StruggleSignal>>(
            future: struggleFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No struggles detected - you\'re doing great! 🎉',
                      style: TextStyle(color: Colors.green[600]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final struggles = snapshot.data!;
              return Column(
                spacing: 10,
                children: struggles
                    .map((s) => StruggleSignalCard(signal: s))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ConceptPerformanceCard extends StatelessWidget {
  final ConceptPerformance concept;

  const ConceptPerformanceCard({Key? key, required this.concept})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final score = concept.quizScore ?? 0;
    final difficulty = concept.isDifficult
        ? 'Needs Review'
        : concept.isStruggling
        ? 'In Progress'
        : 'Mastered';
    final color = concept.isDifficult
        ? Colors.red
        : concept.isStruggling
        ? Colors.amber
        : Colors.green;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Concept ${concept.conceptIndex + 1} - Module ${concept.moduleIndex + 1}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  difficulty,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color[700],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          // Score bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 6,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                '${score.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          if (concept.explanationRequests > 0 ||
              concept.timeToUnderstandSeconds != null)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                spacing: 16,
                children: [
                  if (concept.explanationRequests > 0)
                    Text(
                      '💬 Asked for help ${concept.explanationRequests} time${concept.explanationRequests > 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  if (concept.timeToUnderstandSeconds != null)
                    Text(
                      '⏱️ ${(concept.timeToUnderstandSeconds! ~/ 60)}m to understand',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class StruggleSignalCard extends StatelessWidget {
  final StruggleSignal signal;

  const StruggleSignalCard({Key? key, required this.signal}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final emoji = _getEmoji(signal.signalType);
    final color = Colors.amber;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color[50],
        border: Border.all(color: color[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: TextStyle(fontSize: 20)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signal.getReadableType(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color[900],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _getDescription(signal.signalType),
                  style: TextStyle(fontSize: 12, color: color[700]),
                ),
                if (signal.interventionApplied)
                  Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '✅ Intervention applied',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getEmoji(String signalType) {
    switch (signalType) {
      case 'explicit_confusion':
        return '🤔';
      case 'clarification_request':
        return '❓';
      case 'frustration_detected':
        return '😤';
      case 'disengagement_pattern':
        return '😐';
      case 'concept_mismatch':
        return '❌';
      default:
        return '⚠️';
    }
  }

  String _getDescription(String signalType) {
    switch (signalType) {
      case 'explicit_confusion':
        return 'You expressed confusion - let me explain differently';
      case 'clarification_request':
        return 'You asked for clarification - breaking it down further';
      case 'frustration_detected':
        return 'I detected frustration - let\'s take it step by step';
      case 'disengagement_pattern':
        return 'You went quiet - checking if you\'re following along';
      case 'concept_mismatch':
        return 'Answer doesn\'t match - reviewing the concept';
      default:
        return 'Learning challenge detected';
    }
  }
}
