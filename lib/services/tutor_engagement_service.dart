/// Tutor Engagement Service
/// Handles warm greetings, learner profile building, mood detection,
/// and high-end private tutor interaction logic

import 'dart:math';

/// Learner profile built from initial casual banter
class LearnerProfile {
  final String sessionId;
  final String learningStyle; // visual, auditory, reading, kinesthetic, mixed
  final String pacePreference; // slow, moderate, fast
  final String communicationTone; // formal, casual, encouraging, challenging
  final String motivationLevel; // low, medium, high
  final double confidenceLevel; // 0.0 to 1.0
  final DateTime createdAt;
  final Map<String, dynamic> conversationContext;

  LearnerProfile({
    required this.sessionId,
    this.learningStyle = 'mixed',
    this.pacePreference = 'moderate',
    this.communicationTone = 'encouraging',
    this.motivationLevel = 'medium',
    this.confidenceLevel = 0.5,
    required this.createdAt,
    this.conversationContext = const {},
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'learningStyle': learningStyle,
    'pacePreference': pacePreference,
    'communicationTone': communicationTone,
    'motivationLevel': motivationLevel,
    'confidenceLevel': confidenceLevel,
    'createdAt': createdAt.toIso8601String(),
    'conversationContext': conversationContext,
  };

  /// Create from JSON
  factory LearnerProfile.fromJson(Map<String, dynamic> json) => LearnerProfile(
    sessionId: json['sessionId'] as String,
    learningStyle: json['learningStyle'] as String? ?? 'mixed',
    pacePreference: json['pacePreference'] as String? ?? 'moderate',
    communicationTone: json['communicationTone'] as String? ?? 'encouraging',
    motivationLevel: json['motivationLevel'] as String? ?? 'medium',
    confidenceLevel: (json['confidenceLevel'] as num?)?.toDouble() ?? 0.5,
    createdAt: DateTime.parse(json['createdAt'] as String),
    conversationContext: Map<String, dynamic>.from(
      json['conversationContext'] as Map? ?? {},
    ),
  );

  /// Copy with modified fields
  LearnerProfile copyWith({
    String? learningStyle,
    String? pacePreference,
    String? communicationTone,
    String? motivationLevel,
    double? confidenceLevel,
    Map<String, dynamic>? conversationContext,
  }) => LearnerProfile(
    sessionId: sessionId,
    learningStyle: learningStyle ?? this.learningStyle,
    pacePreference: pacePreference ?? this.pacePreference,
    communicationTone: communicationTone ?? this.communicationTone,
    motivationLevel: motivationLevel ?? this.motivationLevel,
    confidenceLevel: confidenceLevel ?? this.confidenceLevel,
    createdAt: createdAt,
    conversationContext: conversationContext ?? this.conversationContext,
  );
}

/// Mood and emotional state detection
class UserMoodState {
  final String sentiment; // positive, neutral, negative, frustrated, confused
  final double confidence; // 0.0 to 1.0
  final List<String> indicators; // Keywords that indicate mood
  final DateTime detectedAt;
  final String suggestedAction; // What tutor should do

  UserMoodState({
    required this.sentiment,
    this.confidence = 0.5,
    this.indicators = const [],
    required this.detectedAt,
    this.suggestedAction = '',
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'sentiment': sentiment,
    'confidence': confidence,
    'indicators': indicators,
    'detectedAt': detectedAt.toIso8601String(),
    'suggestedAction': suggestedAction,
  };
}

/// Main Tutor Engagement Service
class TutorEngagementService {
  static final TutorEngagementService _instance =
      TutorEngagementService._internal();

  factory TutorEngagementService() => _instance;
  TutorEngagementService._internal();

  // Warm greeting templates - casual and empathetic
  final List<String> _warmGreetings = [
    "Hey there! 👋 I'm so glad we're getting started on this. How are you feeling today?",
    "Welcome! I'm excited to be your study companion. Before we dive in, what's on your mind?",
    "Hi! Great to meet you. How's your day going so far? Any stress or excitement about learning today?",
    "Hello! I'm here to make learning feel natural and fun. How are you doing right now?",
    "Hey! Ready for something awesome? But first—tell me, how are you really feeling?",
  ];

  // Follow-up questions for learner profile building
  final List<String> _profileQuestions = [
    "Do you learn best with examples, videos, or by reading? What's your style?",
    "How do you like to go at your own pace—fast and intense, or slow and steady?",
    "What would make this learning feel most comfortable for you?",
    "When you're confused, do you like me to explain differently or give you more examples?",
    "What's your usual energy level when learning—pumped up or chill?",
  ];

  // Check-in messages to verify understanding
  final List<String> _checkInMessages = [
    "Does that make sense so far? Want me to try a different angle?",
    "Following me? Anything unclear before we move forward?",
    "How's that landing for you? Should we go deeper or keep moving?",
    "On the same page? Any questions popping up?",
    "Getting it? Want to try a quick example to make sure?",
  ];

  // Tutor-like transition messages
  final List<String> _transitionMessages = [
    "Great! Now that you've got that down, let's build on it.",
    "Perfect. You're ready for the next step.",
    "Excellent grasp on that. Here's where it gets interesting.",
    "Solid understanding. Let me take you a bit deeper.",
    "You've nailed that concept. Ready for something new?",
  ];

  // Break/simplification suggestions for struggling users
  final List<String> _supportMessages = [
    "I see you're working hard here. How about we take a quick 2-minute breather? I'll simplify this next part.",
    "This might be tricky—let me break it down into smaller pieces for you.",
    "Let's pause and catch our breath. I'll explain this differently.",
    "You're doing great, but this is complex. Let me make it simpler.",
    "No worries! Let's rewind and take this step-by-step with easier examples.",
  ];

  // Progress affirmations
  final List<String> _affirmations = [
    "You're crushing this! 🎯",
    "Look at that progress! 🚀",
    "You've got this down solid. 💪",
    "I can see real growth here. Amazing!",
    "You're becoming a pro at this!",
  ];

  /// Generate warm initial greeting
  String generateWarmGreeting(String botName, String planName) {
    final greeting = _warmGreetings[Random().nextInt(_warmGreetings.length)];
    return greeting;
  }

  /// Generate learner profile from initial conversation
  LearnerProfile buildLearnerProfile(
    String sessionId,
    List<Map<String, String>> initialExchange,
  ) {
    var learningStyle = _detectLearningStyle(initialExchange);
    var pacePreference = _detectPacePreference(initialExchange);
    var tone = _detectPreferredTone(initialExchange);
    var motivation = _detectMotivationLevel(initialExchange);
    var confidence = _detectConfidenceLevel(initialExchange);

    return LearnerProfile(
      sessionId: sessionId,
      learningStyle: learningStyle,
      pacePreference: pacePreference,
      communicationTone: tone,
      motivationLevel: motivation,
      confidenceLevel: confidence,
      createdAt: DateTime.now(),
      conversationContext: {
        'initialMessages': initialExchange.length,
        'firstTopic': initialExchange.isNotEmpty ? initialExchange.first : {},
      },
    );
  }

  /// Detect mood from user message
  UserMoodState detectMood(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    // Frustration indicators
    if (_containsAny(lowerMessage, [
      'frustrated',
      'confused',
      'don\'t understand',
      'this is hard',
      'lost',
      'stuck',
      '😤',
      '😞',
      'not making sense',
      'help',
    ])) {
      return UserMoodState(
        sentiment: 'frustrated',
        confidence: 0.8,
        indicators: ['difficulty_signals', 'need_intervention'],
        detectedAt: DateTime.now(),
        suggestedAction: 'simplify_and_offer_break',
      );
    }

    // Positive indicators
    if (_containsAny(lowerMessage, [
      'great',
      'got it',
      'understand',
      'cool',
      'awesome',
      '😊',
      '👍',
      'makes sense',
      'love',
      'interesting',
    ])) {
      return UserMoodState(
        sentiment: 'positive',
        confidence: 0.75,
        indicators: ['understanding', 'enthusiasm'],
        detectedAt: DateTime.now(),
        suggestedAction: 'affirmation_and_advance',
      );
    }

    // Confused indicators
    if (_containsAny(lowerMessage, [
      'what?',
      'huh?',
      'again?',
      'explain',
      'how?',
      'why?',
      'different way',
      'not sure',
    ])) {
      return UserMoodState(
        sentiment: 'confused',
        confidence: 0.7,
        indicators: ['need_clarification'],
        detectedAt: DateTime.now(),
        suggestedAction: 'provide_example_or_different_explanation',
      );
    }

    // Default: neutral
    return UserMoodState(
      sentiment: 'neutral',
      confidence: 0.5,
      indicators: [],
      detectedAt: DateTime.now(),
      suggestedAction: 'continue_normally',
    );
  }

  /// Get next profile question
  String getNextProfileQuestion(int questionIndex) {
    return _profileQuestions[questionIndex % _profileQuestions.length];
  }

  /// Get check-in message
  String getCheckInMessage() {
    return _checkInMessages[Random().nextInt(_checkInMessages.length)];
  }

  /// Get transition message
  String getTransitionMessage() {
    return _transitionMessages[Random().nextInt(_transitionMessages.length)];
  }

  /// Get support message for struggling user
  String getSupportMessage() {
    return _supportMessages[Random().nextInt(_supportMessages.length)];
  }

  /// Get affirmation message
  String getAffirmationMessage() {
    return _affirmations[Random().nextInt(_affirmations.length)];
  }

  /// Format teaching content in small, digestible chunks
  String formatTutorResponse(
    String content, {
    required String learningStyle,
    required bool isCheckPoint,
  }) {
    // Keep responses concise - break into smaller chunks
    if (content.length > 300) {
      // Split by sentences and limit
      final sentences = content.split(RegExp(r'(?<=[.!?])\s+'));
      final limited =
          sentences.take(3).join(' ').trimRight() + '...'; // 3 sentences max
      return limited;
    }

    // Add check-in at end if checkpoint
    if (isCheckPoint) {
      return '$content\n\n${getCheckInMessage()}';
    }

    return content;
  }

  /// Generate active recall quiz question
  String generateActiveRecallQuestion(
    String previousContent,
    int difficultyLevel,
  ) {
    // Extract key concepts from previous content
    final keyPhrases = _extractKeyPhrases(previousContent);

    if (keyPhrases.isEmpty) {
      return 'Quick check: what was the main idea we just covered?';
    }

    final formats = [
      'Can you explain ${keyPhrases[0]} in your own words?',
      'Why is ${keyPhrases[0]} important here?',
      'How would you apply ${keyPhrases[0]} to a real example?',
      'What would happen if we changed ${keyPhrases[0]}?',
      'Can you spot where ${keyPhrases[0]} appears in this scenario?',
    ];

    return formats[Random().nextInt(formats.length)];
  }

  // ===== PRIVATE HELPER METHODS =====

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword.toLowerCase()));
  }

  String _detectLearningStyle(List<Map<String, String>> exchange) {
    // Simple heuristic - can be enhanced with ML
    var visual = 0, auditory = 0, reading = 0, kinesthetic = 0;

    for (var message in exchange) {
      final text = (message['text'] ?? '').toLowerCase();
      if (_containsAny(text, [
        'see',
        'look',
        'picture',
        'diagram',
        'visualize',
        'image',
      ])) {
        visual++;
      }
      if (_containsAny(text, [
        'hear',
        'listen',
        'sound',
        'explain',
        'talk',
        'discuss',
      ])) {
        auditory++;
      }
      if (_containsAny(text, ['read', 'write', 'notes', 'document', 'text'])) {
        reading++;
      }
      if (_containsAny(text, [
        'try',
        'do',
        'practice',
        'hands-on',
        'example',
      ])) {
        kinesthetic++;
      }
    }

    if (visual > auditory && visual > reading && visual > kinesthetic)
      return 'visual';
    if (auditory > reading && auditory > kinesthetic) return 'auditory';
    if (reading > kinesthetic) return 'reading';
    if (kinesthetic > 0) return 'kinesthetic';
    return 'mixed';
  }

  String _detectPacePreference(List<Map<String, String>> exchange) {
    // Look for pace-related keywords
    var slowIndicators = 0, fastIndicators = 0;

    for (var message in exchange) {
      final text = (message['text'] ?? '').toLowerCase();
      if (_containsAny(text, ['slow', 'steady', 'careful', 'detail', 'step'])) {
        slowIndicators++;
      }
      if (_containsAny(text, [
        'fast',
        'quick',
        'brief',
        'quick',
        'get to it',
      ])) {
        fastIndicators++;
      }
    }

    if (fastIndicators > slowIndicators) return 'fast';
    if (slowIndicators > 0) return 'slow';
    return 'moderate';
  }

  String _detectPreferredTone(List<Map<String, String>> exchange) {
    // Detect if user prefers casual vs formal
    var casualIndicators = 0, formalIndicators = 0;

    for (var message in exchange) {
      final text = (message['text'] ?? '').toLowerCase();
      if (_containsAny(text, [
        'hey',
        'cool',
        'awesome',
        'lol',
        'fun',
        'chill',
      ])) {
        casualIndicators++;
      }
      if (_containsAny(text, [
        'please',
        'kindly',
        'academic',
        'professional',
        'formal',
      ])) {
        formalIndicators++;
      }
    }

    if (formalIndicators > casualIndicators) return 'formal';
    return 'encouraging'; // default to encouraging/casual
  }

  String _detectMotivationLevel(List<Map<String, String>> exchange) {
    // Judge motivation from initial messages
    var highMotivation = 0, lowMotivation = 0;

    for (var message in exchange) {
      final text = (message['text'] ?? '').toLowerCase();
      if (_containsAny(text, [
        'excited',
        'want to learn',
        'passionate',
        'eager',
        'goal',
        'achieve',
      ])) {
        highMotivation++;
      }
      if (_containsAny(text, [
        'have to',
        'forced',
        'required',
        'don\'t want',
        'boring',
        'waste',
      ])) {
        lowMotivation++;
      }
    }

    if (highMotivation > lowMotivation) return 'high';
    if (lowMotivation > 0) return 'low';
    return 'medium';
  }

  double _detectConfidenceLevel(List<Map<String, String>> exchange) {
    // Confidence based on questions asked
    var uncertaintyMarkers = 0;

    for (var message in exchange) {
      final text = (message['text'] ?? '').toLowerCase();
      if (text.contains('?')) {
        uncertaintyMarkers++;
      }
      if (_containsAny(text, [
        'not sure',
        'confused',
        'don\'t know',
        'lost',
        'help',
      ])) {
        uncertaintyMarkers++;
      }
    }

    final baseConfidence = 0.5;
    final adjustment = -0.05 * uncertaintyMarkers;
    return (baseConfidence + adjustment).clamp(0.0, 1.0);
  }

  List<String> _extractKeyPhrases(String text) {
    // Simple keyword extraction - can be enhanced
    final words = text.split(RegExp(r'\s+'));
    final keywordLengths = words.where((w) => w.length > 5).toList();
    return keywordLengths.take(3).toList();
  }
}
