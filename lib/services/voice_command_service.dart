import 'package:flutter/foundation.dart';

// ============================================================================
// VOICE COMMAND DETECTION SERVICE
// ============================================================================
// 🎯 PURPOSE: Convert user speech into structured commands
//
// KEY FEATURES:
// 1. Intent Classification (create, search, navigate, ask, study, quiz)
// 2. Entity Extraction (bot topic, subject, question)
// 3. Confidence Scoring (low/medium/high based on pattern matching)
// 4. Grammar-based Command Recognition (study-bot specific patterns)
// 5. Fallback to Raw Transcript (if no command pattern matches)
//
// EXAMPLE USAGE:
//   final service = VoiceCommandService();
//   final result = service.parseCommand("Create a bot about biology");
//   // Returns: Command(intent: 'create', topic: 'biology', confidence: 0.95)
//
// ============================================================================

/// Enum for command intents
enum CommandIntent { create, search, navigate, ask, study, quiz, unknown }

/// Enum for confidence levels
enum ConfidenceLevel { low, medium, high, veryHigh }

/// Represents a parsed voice command
class VoiceCommand {
  final CommandIntent intent;
  final String originalText;
  final String? parameter;
  final double confidence;
  final ConfidenceLevel confidenceLevel;
  final List<String> keywords;
  final String? validationMessage;

  VoiceCommand({
    required this.intent,
    required this.originalText,
    this.parameter,
    required this.confidence,
    required this.confidenceLevel,
    this.keywords = const [],
    this.validationMessage,
  });

  bool get isValid => intent != CommandIntent.unknown && confidence >= 0.5;

  @override
  String toString() =>
      'VoiceCommand(intent: $intent, param: $parameter, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
}

/// Service for detecting and parsing voice commands
class VoiceCommandService {
  static final VoiceCommandService _instance = VoiceCommandService._internal();

  factory VoiceCommandService() => _instance;

  VoiceCommandService._internal();

  /// Parse user's spoken text into a structured command
  VoiceCommand parseCommand(String input) {
    final text = _normalizeText(input);

    // Try to match against known patterns
    for (final pattern in _createPatterns) {
      final match = _tryMatch(text, pattern);
      if (match != null) return match;
    }

    for (final pattern in _searchPatterns) {
      final match = _tryMatch(text, pattern);
      if (match != null) return match;
    }

    for (final pattern in _askPatterns) {
      final match = _tryMatch(text, pattern);
      if (match != null) return match;
    }

    for (final pattern in _quizPatterns) {
      final match = _tryMatch(text, pattern);
      if (match != null) return match;
    }

    for (final pattern in _navigatePatterns) {
      final match = _tryMatch(text, pattern);
      if (match != null) return match;
    }

    // Fallback: unknown command with raw text
    return VoiceCommand(
      intent: CommandIntent.unknown,
      originalText: input,
      parameter: input,
      confidence: 0.3,
      confidenceLevel: ConfidenceLevel.low,
      keywords: text.split(' '),
      validationMessage: 'Not recognized as a command',
    );
  }

  /// Normalize text for matching
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  /// Try to match text against a pattern
  VoiceCommand? _tryMatch(String text, _CommandPattern pattern) {
    for (final regex in pattern.regexes) {
      final match = regex.firstMatch(text);
      if (match != null) {
        final parameter = _extractParameter(
          text,
          regex,
          match,
          pattern.paramGroup,
        );
        final confidence = pattern.baseConfidence;

        return VoiceCommand(
          intent: pattern.intent,
          originalText: text,
          parameter: parameter,
          confidence: confidence,
          confidenceLevel: _getConfidenceLevel(confidence),
          keywords: [
            pattern.intent.toString().split('.').last,
            ...?parameter?.split(' '),
          ],
        );
      }
    }
    return null;
  }

  /// Extract parameter from regex match
  String? _extractParameter(
    String text,
    RegExp regex,
    RegExpMatch match,
    int group,
  ) {
    try {
      if (group > 0 && group <= match.groupCount) {
        String? param = match.group(group);
        return param?.trim();
      }
    } catch (_) {}

    // Fallback: try to extract everything after keywords
    return _intelligentExtract(text, regex);
  }

  /// Intelligently extract meaningful parameter
  String? _intelligentExtract(String text, RegExp regex) {
    final allMatches = regex.allMatches(text).toList();
    if (allMatches.isEmpty) return null;

    final match = allMatches.first;
    final before = text.substring(0, match.start);
    final after = text.substring(match.end);

    // Prefer after-match content (e.g., "create a bot [ABOUT BIOLOGY]")
    if (after.isNotEmpty) {
      return after.replaceAll(RegExp(r'^\s*(about|for|on|in)\s*'), '').trim();
    }

    // Otherwise use before-match
    return before.trim();
  }

  /// Convert confidence score to level
  ConfidenceLevel _getConfidenceLevel(double confidence) {
    if (confidence >= 0.9) return ConfidenceLevel.veryHigh;
    if (confidence >= 0.75) return ConfidenceLevel.high;
    if (confidence >= 0.5) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }

  // =========================================================================
  // COMMAND PATTERNS
  // =========================================================================

  late final List<_CommandPattern> _createPatterns = [
    _CommandPattern(
      intent: CommandIntent.create,
      regexes: [
        RegExp(
          r'(?:create|make|start|build|design)\s+(?:a\s+)?(?:new\s+)?(?:bot|tutor|study\s+(?:bot|tutor))\s+(?:about|for|on|in)\s+(\w+(?:\s+\w+)*)',
          caseSensitive: false,
        ),
        RegExp(
          r'(?:create|make|start|build)\s+(?:a\s+)?(?:new\s+)?(?:bot|tutor)\s+(?:called|named)\s+(\w+(?:\s+\w+)*)',
          caseSensitive: false,
        ),
      ],
      paramGroup: 1,
      baseConfidence: 0.95,
    ),
  ];

  late final List<_CommandPattern> _searchPatterns = [
    _CommandPattern(
      intent: CommandIntent.search,
      regexes: [
        RegExp(
          r'(?:search|find|look\s+for|show\s+me)\s+(?:questions|problems|topics|bots)\s+(?:about|for|on|in)\s+(\w+(?:\s+\w+)*)',
          caseSensitive: false,
        ),
        RegExp(
          r'(?:search|find|look\s+for)\s+(\w+(?:\s+\w+)*)\s+(?:questions|problems|topics|bots)',
          caseSensitive: false,
        ),
      ],
      paramGroup: 1,
      baseConfidence: 0.90,
    ),
  ];

  late final List<_CommandPattern> _askPatterns = [
    _CommandPattern(
      intent: CommandIntent.ask,
      regexes: [
        RegExp(
          r'(?:ask|tell|explain|what|how|why)\s+(?:about|about\s+)?(\w+(?:\s+\w+)*)',
          caseSensitive: false,
        ),
        RegExp(
          r'(?:what\s+is|how\s+do|why\s+is|explain)\s+(\w+(?:\s+\w+)*)',
          caseSensitive: false,
        ),
      ],
      paramGroup: 1,
      baseConfidence: 0.85,
    ),
  ];

  late final List<_CommandPattern> _quizPatterns = [
    _CommandPattern(
      intent: CommandIntent.quiz,
      regexes: [
        RegExp(
          r'(?:quiz\s+me|test\s+me|ask\s+me|give\s+me\s+questions)\s+(?:on|about|in)\s+(\w+(?:\s+\w+)*)',
          caseSensitive: false,
        ),
        RegExp(
          r'(?:start|begin|take)\s+(?:a\s+)?quiz\s+(?:on|about|in)\s+(\w+(?:\s+\w+)*)',
          caseSensitive: false,
        ),
      ],
      paramGroup: 1,
      baseConfidence: 0.92,
    ),
  ];

  late final List<_CommandPattern> _navigatePatterns = [
    _CommandPattern(
      intent: CommandIntent.navigate,
      regexes: [
        RegExp(
          r'(?:go\s+to|navigate\s+to|open|show\s+me)\s+(?:my\s+)?(?:bots|tutors|library|study\s+bots|study\s+tutors|home|settings)',
          caseSensitive: false,
        ),
      ],
      paramGroup: 0,
      baseConfidence: 0.88,
    ),
  ];
}

/// Internal command pattern definition
class _CommandPattern {
  final CommandIntent intent;
  final List<RegExp> regexes;
  final int paramGroup;
  final double baseConfidence;

  _CommandPattern({
    required this.intent,
    required this.regexes,
    required this.paramGroup,
    required this.baseConfidence,
  });
}

/// Provider for voice command service (use with Provider package)
class VoiceCommandServiceProvider extends ChangeNotifier {
  final VoiceCommandService _service = VoiceCommandService();
  VoiceCommand? _lastCommand;
  String? _lastRawInput;

  VoiceCommand? get lastCommand => _lastCommand;
  String? get lastRawInput => _lastRawInput;

  /// Parse and cache a command
  VoiceCommand parseAndCacheCommand(String input) {
    _lastRawInput = input;
    _lastCommand = _service.parseCommand(input);
    notifyListeners();
    return _lastCommand!;
  }

  /// Clear cached command
  void clearCache() {
    _lastCommand = null;
    _lastRawInput = null;
    notifyListeners();
  }

  /// Get recommended action based on command
  String? getRecommendedAction() {
    if (_lastCommand == null) return null;

    switch (_lastCommand!.intent) {
      case CommandIntent.create:
        return 'Creating bot about: ${_lastCommand!.parameter}';
      case CommandIntent.search:
        return 'Searching for: ${_lastCommand!.parameter}';
      case CommandIntent.ask:
        return 'Answering question about: ${_lastCommand!.parameter}';
      case CommandIntent.quiz:
        return 'Starting quiz on: ${_lastCommand!.parameter}';
      case CommandIntent.navigate:
        return 'Opening: ${_lastCommand!.parameter ?? "Home"}';
      case CommandIntent.study:
        return 'Study mode: ${_lastCommand!.parameter}';
      case CommandIntent.unknown:
        return null;
    }
  }
}
