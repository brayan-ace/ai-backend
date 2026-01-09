/// StudyBot model representing a subject-specific AI study companion
class StudyBot {
  final String id;
  final String planName;
  final String planDescription;
  final String botName;
  final String educationLevel;
  final DateTime createdAt;

  StudyBot({
    required this.id,
    required this.planName,
    required this.planDescription,
    required this.botName,
    required this.educationLevel,
    required this.createdAt,
  });

  /// Convert StudyBot to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'planName': planName,
      'planDescription': planDescription,
      'botName': botName,
      'educationLevel': educationLevel,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create StudyBot from JSON
  factory StudyBot.fromJson(Map<String, dynamic> json) {
    return StudyBot(
      id: json['id'] as String,
      planName: json['planName'] as String,
      planDescription: json['planDescription'] as String,
      botName: json['botName'] as String,
      educationLevel: json['educationLevel'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Create a copy with modified fields
  StudyBot copyWith({
    String? id,
    String? planName,
    String? planDescription,
    String? botName,
    String? educationLevel,
    DateTime? createdAt,
  }) {
    return StudyBot(
      id: id ?? this.id,
      planName: planName ?? this.planName,
      planDescription: planDescription ?? this.planDescription,
      botName: botName ?? this.botName,
      educationLevel: educationLevel ?? this.educationLevel,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
