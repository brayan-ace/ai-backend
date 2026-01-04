class QuizQuestion {
  final String question;
  final List<String>? options;
  final String? correctAnswer;
  final String? explanation;

  QuizQuestion({
    required this.question,
    this.options,
    this.correctAnswer,
    this.explanation,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> m) {
    return QuizQuestion(
      question: m['question'] ?? '',
      options: m['options'] != null ? List<String>.from(m['options']) : null,
      correctAnswer: m['correctAnswer'],
      explanation: m['explanation'],
    );
  }
}

class QuizArtifact {
  final String id;
  final String title;
  final int numQuestions;
  final String gradeLevel;
  final bool includeAnswers;
  final DateTime timestamp;
  final List<QuizQuestion> questions;

  QuizArtifact({
    required this.id,
    required this.title,
    required this.numQuestions,
    required this.gradeLevel,
    required this.includeAnswers,
    required this.timestamp,
    required this.questions,
  });

  factory QuizArtifact.fromFirestore(Map<String, dynamic> m) {
    final qs = <QuizQuestion>[];
    if (m['questions'] is List) {
      for (final q in m['questions']) {
        if (q is Map<String, dynamic>) qs.add(QuizQuestion.fromMap(q));
      }
    }

    return QuizArtifact(
      id: m['id'] ?? '',
      title: m['title'] ?? 'Untitled Quiz',
      numQuestions: (m['numQuestions'] is int)
          ? m['numQuestions']
          : (m['questions'] is List ? (m['questions'] as List).length : 0),
      gradeLevel: m['gradeLevel'] ?? 'N/A',
      includeAnswers: m['includeAnswers'] == true,
      timestamp: DateTime.tryParse(m['timestamp'] ?? '') ?? DateTime.now(),
      questions: qs,
    );
  }
}
