/// Study Bot Flow Controller - Manages state transitions and bot responses
/// Implements the state machine for the tutoring flow

import '../models/study_bot_state.dart';

class StudyBotFlowController {
  /// Private constructor - use factory methods
  StudyBotFlowController._internal();

  static final StudyBotFlowController _instance =
      StudyBotFlowController._internal();

  factory StudyBotFlowController() {
    return _instance;
  }

  /// Create a new Study Bot session
  StudyBotState createNewSession({required String botId}) {
    final now = DateTime.now();
    return StudyBotState(
      sessionId: '${botId}_${now.millisecondsSinceEpoch}',
      botId: botId,
      currentState: StudyBotStateType.intro,
      createdAt: now,
      lastUpdated: now,
      chatHistory: [],
      completedModules: [],
    );
  }

  /// Generate Table of Contents based on education level and description
  List<TableOfContentsItem> generateTableOfContents({
    required String educationLevel,
    required String planDescription,
  }) {
    final modules = _getModuleCountForLevel(educationLevel);
    final baseModules = _generateBaseModules(
      educationLevel,
      planDescription,
      modules,
    );
    return baseModules;
  }

  /// Get number of modules based on education level
  int _getModuleCountForLevel(String level) {
    return switch (level.toLowerCase()) {
      'primary' || 'elementary' => 6,
      'secondary' || 'middle school' => 8,
      'high school' || 'secondary school' => 9,
      'university' || 'college' => 10,
      'advanced' || 'professional' => 12,
      _ => 8,
    };
  }

  /// Generate base module structure
  List<TableOfContentsItem> _generateBaseModules(
    String educationLevel,
    String planDescription,
    int moduleCount,
  ) {
    final modules = <TableOfContentsItem>[];
    final isPrimary =
        educationLevel.toLowerCase().contains('primary') ||
        educationLevel.toLowerCase().contains('elementary');

    for (int i = 1; i <= moduleCount; i++) {
      final progress = (i - 1) / (moduleCount - 1);
      final difficulty = _getDifficultyProgression(progress, isPrimary);
      final timeEstimate = _getTimeEstimate(progress, isPrimary);

      modules.add(
        TableOfContentsItem(
          moduleNumber: i,
          title: _generateModuleTitle(planDescription, i, moduleCount),
          description: _generateModuleDescription(
            planDescription,
            i,
            moduleCount,
          ),
          subtopics: _generateSubtopics(
            planDescription,
            i,
            moduleCount,
            difficulty,
          ),
          estimatedTime: timeEstimate,
          difficultyLevel: difficulty,
        ),
      );
    }

    return modules;
  }

  /// Generate progressive difficulty levels
  String _getDifficultyProgression(double progress, bool isPrimary) {
    if (isPrimary) {
      return progress < 0.5 ? 'beginner' : 'intermediate';
    }

    if (progress < 0.33) {
      return 'beginner';
    } else if (progress < 0.66) {
      return 'intermediate';
    } else {
      return 'advanced';
    }
  }

  /// Generate time estimates
  String _getTimeEstimate(double progress, bool isPrimary) {
    if (isPrimary) {
      return progress < 0.5 ? '20 minutes' : '30 minutes';
    }

    if (progress < 0.33) {
      return '30 minutes';
    } else if (progress < 0.66) {
      return '45 minutes';
    } else {
      return '60 minutes';
    }
  }

  /// Generate module title based on stage
  String _generateModuleTitle(String description, int moduleNum, int total) {
    final topics = description.split(' ').where((w) => w.length > 3).toList();
    final topic = topics.isNotEmpty
        ? topics[moduleNum % topics.length]
        : 'Module';

    return switch (moduleNum) {
      1 => 'Foundations of $topic',
      2 => 'Core Concepts',
      3 => 'Developing Understanding',
      4 => 'Intermediate Applications',
      5 => 'Advanced Topics',
      6 => 'Synthesis and Connection',
      7 => 'Practical Application',
      8 => 'Critical Analysis',
      9 => 'Integration and Mastery',
      10 => 'Capstone and Reflection',
      _ => 'Module $moduleNum: Advanced Study',
    };
  }

  /// Generate module description
  String _generateModuleDescription(
    String description,
    int moduleNum,
    int total,
  ) {
    final stage = (moduleNum / total).clamp(0, 1);

    if (stage < 0.3) {
      return 'Introduction to key concepts and foundational knowledge';
    } else if (stage < 0.6) {
      return 'Building understanding through examples and applications';
    } else if (stage < 0.85) {
      return 'Advanced exploration and critical thinking';
    } else {
      return 'Synthesis, reflection, and mastery assessment';
    }
  }

  /// Generate subtopics for a module
  List<String> _generateSubtopics(
    String description,
    int moduleNum,
    int total,
    String difficulty,
  ) {
    final subtopicCount = difficulty == 'beginner'
        ? 3
        : difficulty == 'intermediate'
        ? 4
        : 5;
    final subtopics = <String>[];

    for (int i = 1; i <= subtopicCount; i++) {
      subtopics.add(
        'Topic $moduleNum.$i: Key Concept ${String.fromCharCode(65 + i - 1)}',
      );
    }

    return subtopics;
  }

  /// Validate if a state transition is allowed
  bool canTransitionTo(
    StudyBotStateType currentState,
    StudyBotStateType newState,
  ) {
    const validTransitions = {
      StudyBotStateType.intro: {StudyBotStateType.planProposal},
      StudyBotStateType.planProposal: {
        StudyBotStateType.planApproved,
        StudyBotStateType.planModification,
      },
      StudyBotStateType.planModification: {
        StudyBotStateType.planProposal, // Regenerate TOC
      },
      StudyBotStateType.planApproved: {StudyBotStateType.lessonActive},
      StudyBotStateType.lessonActive: {
        StudyBotStateType.assessment,
        StudyBotStateType.lessonActive, // Next module
      },
      StudyBotStateType.assessment: {
        StudyBotStateType.review,
        StudyBotStateType.lessonActive, // Retry or next module
      },
      StudyBotStateType.review: {
        StudyBotStateType.completed,
        StudyBotStateType.lessonActive, // Revisit modules
      },
      StudyBotStateType.completed: {
        StudyBotStateType.intro, // Reset for new session
      },
    };

    return validTransitions[currentState]?.contains(newState) ?? false;
  }

  /// Transition to new state (validates first)
  StudyBotState transitionTo(StudyBotState state, StudyBotStateType newState) {
    if (!canTransitionTo(state.currentState, newState)) {
      throw StateError(
        'Invalid transition from ${state.currentState} to $newState',
      );
    }

    return state.copyWith(currentState: newState, lastUpdated: DateTime.now());
  }

  /// Get appropriate bot greeting/response based on current state
  String getBotResponseForState(
    StudyBotStateType state, {
    String? botName,
    String? planName,
    String? educationLevel,
  }) {
    return switch (state) {
      StudyBotStateType.intro => _getIntroResponse(botName, planName),
      StudyBotStateType.planProposal => _getPlanProposalResponse(planName),
      StudyBotStateType.planApproved => _getPlanApprovedResponse(botName),
      StudyBotStateType.planModification => _getPlanModificationResponse(
        planName,
      ),
      StudyBotStateType.lessonActive => _getLessonActiveResponse(
        botName,
        planName,
      ),
      StudyBotStateType.assessment => _getAssessmentResponse(botName, planName),
      StudyBotStateType.review => _getReviewResponse(botName, planName),
      StudyBotStateType.completed => _getCompletedResponse(botName, planName),
    };
  }

  String _getIntroResponse(String? botName, String? planName) {
    final bot = botName ?? 'Your Study Bot';
    return '''Hi! I'm $bot, your personal study guide for "$planName". 

I'm here to help you master this topic in a structured, engaging way. We'll work through carefully designed modules that build your understanding step by step.

Are you ready to get started?''';
  }

  String _getPlanProposalResponse(String? planName) {
    return '''Great! I've prepared a personalized learning path for "$planName". 

Here's your Table of Contents - a roadmap for our learning journey together. Each module is designed to build progressively on what came before.

Take a look at the outline below. You can approve this plan, or if you'd like me to adjust the pace, topics, or depth of study, just let me know!''';
  }

  String _getPlanApprovedResponse(String? botName) {
    final bot = botName ?? 'Your Study Bot';
    return '''Excellent! We're ready to begin. 

$bot is excited to guide you through this learning journey. Let's start with Module 1 - you'll be amazed at how much you learn!

Ready to dive into the first module?''';
  }

  String _getPlanModificationResponse(String? planName) {
    return '''I appreciate your feedback! Let me know:
- Would you like to adjust the **pace** (faster/slower)?
- Would you prefer to focus on specific **topics**?
- Should we adjust the **depth** of study (more/less technical)?

Once you tell me your preferences, I'll regenerate your learning path.''';
  }

  String _getLessonActiveResponse(String? botName, String? planName) {
    final bot = botName ?? 'Your Study Bot';
    return '''$bot is now teaching you the material. We'll work through this module together, making sure you understand each concept.

I'll ask you questions along the way to check your understanding.''';
  }

  String _getAssessmentResponse(String? botName, String? planName) {
    final bot = botName ?? 'Your Study Bot';
    return '''Great work! Now let's assess what you've learned. 

$bot will ask you some questions to see how well you've mastered this module. This helps us understand where to focus next.

Ready for the assessment?''';
  }

  String _getReviewResponse(String? botName, String? planName) {
    final bot = botName ?? 'Your Study Bot';
    return '''Fantastic progress! Let me summarize what you've accomplished and what areas you've truly mastered.

$bot is impressed with your dedication to learning!''';
  }

  String _getCompletedResponse(String? botName, String? planName) {
    return '''Congratulations! You've completed "$planName"! 

You've worked through all the modules and demonstrated mastery. This is a significant achievement - be proud of yourself!

Would you like to start a new study plan?''';
  }

  /// Get action buttons for current state
  List<String> getActionButtonsForState(StudyBotStateType state) {
    return switch (state) {
      StudyBotStateType.intro => ['Yes, let\'s begin!', 'Tell me more'],
      StudyBotStateType.planProposal => ['Approve Plan', 'Modify Plan'],
      StudyBotStateType.planApproved => ['Start Module 1'],
      StudyBotStateType.planModification => [
        'Adjust Pace',
        'Change Topics',
        'Adjust Depth',
      ],
      StudyBotStateType.lessonActive => ['Next', 'Ask Question'],
      StudyBotStateType.assessment => ['Start Assessment', 'Review First'],
      StudyBotStateType.review => ['Next Module', 'View Report'],
      StudyBotStateType.completed => ['Start New Plan', 'View Final Report'],
    };
  }
}
