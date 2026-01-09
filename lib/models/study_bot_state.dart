/// Study Bot State Enums and Models for Phase 2
/// Manages the flow and state transitions of the Study Bot tutoring system

/// Enum representing all possible states in the Study Bot flow
enum StudyBotStateType {
  /// Initial state: Bot greets user and checks if they're ready
  intro,

  /// Bot generates Table of Contents and asks for approval/modification
  planProposal,

  /// User approved the TOC, ready to start lessons
  planApproved,

  /// User wants to modify the TOC (pace, topics, depth)
  planModification,

  /// Active teaching state - Bot is teaching current module
  lessonActive,

  /// Assessment state - Bot is conducting quizzes/artifacts
  assessment,

  /// Review state - Bot summarizes progress and mastery
  review,

  /// Completed state - Study plan finished
  completed,
}

/// Table of Contents item for the study plan
class TableOfContentsItem {
  final int moduleNumber;
  final String title;
  final String description;
  final List<String> subtopics;
  final String estimatedTime; // e.g., "30 minutes", "1 hour"
  final String difficultyLevel; // "beginner", "intermediate", "advanced"

  TableOfContentsItem({
    required this.moduleNumber,
    required this.title,
    required this.description,
    required this.subtopics,
    required this.estimatedTime,
    required this.difficultyLevel,
  });

  Map<String, dynamic> toJson() => {
    'moduleNumber': moduleNumber,
    'title': title,
    'description': description,
    'subtopics': subtopics,
    'estimatedTime': estimatedTime,
    'difficultyLevel': difficultyLevel,
  };

  factory TableOfContentsItem.fromJson(Map<String, dynamic> json) =>
      TableOfContentsItem(
        moduleNumber: json['moduleNumber'] as int,
        title: json['title'] as String,
        description: json['description'] as String,
        subtopics: List<String>.from(json['subtopics'] as List),
        estimatedTime: json['estimatedTime'] as String,
        difficultyLevel: json['difficultyLevel'] as String,
      );
}

/// Modification request for the Table of Contents
class PlanModificationRequest {
  final String modificationArea; // "pace", "topics", "depth"
  final String userRequest; // User's specific request
  final DateTime timestamp;

  PlanModificationRequest({
    required this.modificationArea,
    required this.userRequest,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'modificationArea': modificationArea,
    'userRequest': userRequest,
    'timestamp': timestamp.toIso8601String(),
  };

  factory PlanModificationRequest.fromJson(Map<String, dynamic> json) =>
      PlanModificationRequest(
        modificationArea: json['modificationArea'] as String,
        userRequest: json['userRequest'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// Main Study Bot State data class
class StudyBotState {
  final String sessionId; // Unique session ID
  final String botId; // Reference to the Study Bot
  final StudyBotStateType currentState;

  // INTRO state data
  final bool? userReady;

  // PLAN_PROPOSAL state data
  final List<TableOfContentsItem>? tableOfContents;
  final bool tocGenerated;

  // PLAN_MODIFICATION state data
  final List<PlanModificationRequest>? modificationHistory;

  // PLAN_APPROVED & LESSON_ACTIVE state data
  final int currentModule; // Module index (1-based)
  final List<int>? completedModules;

  // Assessment state data
  final Map<String, dynamic>? currentAssessment;

  // Session tracking
  final DateTime createdAt;
  final DateTime lastUpdated;
  final List<Map<String, dynamic>>? chatHistory; // Message history

  // User preferences stored during modifications
  final Map<String, dynamic>?
  userPreferences; // pace, depth, topics preferences

  StudyBotState({
    required this.sessionId,
    required this.botId,
    required this.currentState,
    this.userReady,
    this.tableOfContents,
    this.tocGenerated = false,
    this.modificationHistory,
    this.currentModule = 0,
    this.completedModules,
    this.currentAssessment,
    required this.createdAt,
    required this.lastUpdated,
    this.chatHistory,
    this.userPreferences,
  });

  /// Create a copy with modified fields
  StudyBotState copyWith({
    String? sessionId,
    String? botId,
    StudyBotStateType? currentState,
    bool? userReady,
    List<TableOfContentsItem>? tableOfContents,
    bool? tocGenerated,
    List<PlanModificationRequest>? modificationHistory,
    int? currentModule,
    List<int>? completedModules,
    Map<String, dynamic>? currentAssessment,
    DateTime? createdAt,
    DateTime? lastUpdated,
    List<Map<String, dynamic>>? chatHistory,
    Map<String, dynamic>? userPreferences,
  }) => StudyBotState(
    sessionId: sessionId ?? this.sessionId,
    botId: botId ?? this.botId,
    currentState: currentState ?? this.currentState,
    userReady: userReady ?? this.userReady,
    tableOfContents: tableOfContents ?? this.tableOfContents,
    tocGenerated: tocGenerated ?? this.tocGenerated,
    modificationHistory: modificationHistory ?? this.modificationHistory,
    currentModule: currentModule ?? this.currentModule,
    completedModules: completedModules ?? this.completedModules,
    currentAssessment: currentAssessment ?? this.currentAssessment,
    createdAt: createdAt ?? this.createdAt,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    chatHistory: chatHistory ?? this.chatHistory,
    userPreferences: userPreferences ?? this.userPreferences,
  );

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'botId': botId,
    'currentState': currentState.toString(),
    'userReady': userReady,
    'tableOfContents': tableOfContents?.map((x) => x.toJson()).toList(),
    'tocGenerated': tocGenerated,
    'modificationHistory': modificationHistory?.map((x) => x.toJson()).toList(),
    'currentModule': currentModule,
    'completedModules': completedModules,
    'currentAssessment': currentAssessment,
    'createdAt': createdAt.toIso8601String(),
    'lastUpdated': lastUpdated.toIso8601String(),
    'chatHistory': chatHistory,
    'userPreferences': userPreferences,
  };

  factory StudyBotState.fromJson(Map<String, dynamic> json) {
    final stateString = (json['currentState'] as String).split('.').last;
    final state = StudyBotStateType.values.firstWhere(
      (e) => e.toString().endsWith(stateString),
      orElse: () => StudyBotStateType.intro,
    );

    return StudyBotState(
      sessionId: json['sessionId'] as String,
      botId: json['botId'] as String,
      currentState: state,
      userReady: json['userReady'] as bool?,
      tableOfContents: (json['tableOfContents'] as List<dynamic>?)
          ?.map(
            (x) => TableOfContentsItem.fromJson(
              Map<String, dynamic>.from(x as Map),
            ),
          )
          .toList(),
      tocGenerated: json['tocGenerated'] as bool? ?? false,
      modificationHistory: (json['modificationHistory'] as List<dynamic>?)
          ?.map(
            (x) => PlanModificationRequest.fromJson(
              Map<String, dynamic>.from(x as Map),
            ),
          )
          .toList(),
      currentModule: json['currentModule'] as int? ?? 0,
      completedModules: (json['completedModules'] as List<dynamic>?)
          ?.cast<int>(),
      currentAssessment: json['currentAssessment'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      chatHistory: (json['chatHistory'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>(),
      userPreferences: json['userPreferences'] as Map<String, dynamic>?,
    );
  }
}

/// Chat message for Study Bot conversations
class StudyBotMessage {
  final String id;
  final String senderType; // "user" or "bot"
  final String text;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata; // Optional: buttons, options, etc.

  StudyBotMessage({
    required this.id,
    required this.senderType,
    required this.text,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderType': senderType,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };

  factory StudyBotMessage.fromJson(Map<String, dynamic> json) =>
      StudyBotMessage(
        id: json['id'] as String,
        senderType: json['senderType'] as String,
        text: json['text'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
}
