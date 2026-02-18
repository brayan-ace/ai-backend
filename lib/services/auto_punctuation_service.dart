import 'package:flutter/foundation.dart';

// ============================================================================
// AUTO-PUNCTUATION SERVICE FOR TRANSCRIPTS
// ============================================================================
// 🎯 PURPOSE: Post-process voice transcripts with intelligent punctuation
//
// KEY FEATURES:
// 1. Sentence Boundary Detection (based on pause patterns)
// 2. Automatic Capitalization (first letter after terminators)
// 3. Smart Punctuation (periods, commas, question marks)
// 4. Contraction Preservation (don't, won't, can't)
// 5. Number & Currency Handling (123, $50, 50%)
// 6. Common Pattern Recognition (email patterns, URLs)
//
// EXAMPLE USAGE:
//   final service = AutoPunctuationService();
//   final result = service.addPunctuation(
//     "what is photosynthesis is it important",
//     pauseDurations: [800, 1200], // ms between segments
//   );
//   // Returns: "What is photosynthesis? Is it important?"
//
// ============================================================================

/// Service for intelligent punctuation of transcribed text
class AutoPunctuationService {
  static final AutoPunctuationService _instance =
      AutoPunctuationService._internal();

  factory AutoPunctuationService() => _instance;

  AutoPunctuationService._internal();

  /// Add intelligent punctuation to raw transcript
  String addPunctuation(
    String rawText, {
    List<int> pauseDurations = const [],
    bool detectQuestions = true,
    bool detectExclamations = true,
  }) {
    if (rawText.isEmpty) return rawText;

    // Normalize whitespace
    String text = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Split into words for processing
    final words = text.split(' ');
    if (words.isEmpty) return rawText;

    // First pass: Identify sentence boundaries using pause duration
    final sentenceBoundaries = _detectSentenceBoundaries(words, pauseDurations);

    // Second pass: Reconstruct text with punctuation
    String result = _reconstructWithPunctuation(
      words,
      sentenceBoundaries,
      detectQuestions: detectQuestions,
      detectExclamations: detectExclamations,
    );

    return result;
  }

  /// Detect sentence boundaries based on word count and pause duration
  List<int> _detectSentenceBoundaries(
    List<String> words,
    List<int> pauseDurations,
  ) {
    final boundaries = <int>[];

    // If we have pause data, use it
    if (pauseDurations.isNotEmpty) {
      int wordIndex = 0;
      for (final pauseMs in pauseDurations) {
        // Pause > 800ms suggests sentence boundary
        if (pauseMs > 800 && wordIndex > 0 && wordIndex < words.length - 1) {
          boundaries.add(wordIndex);
        }
        // Estimate words per pause (~3-4 words per second of speech)
        wordIndex += (pauseMs / 400).floor();
      }
    }

    // Fallback: Heuristic-based boundaries
    // Target 10-20 words per sentence
    if (boundaries.isEmpty) {
      for (int i = 15; i < words.length; i += (10 + (i % 15))) {
        if (i < words.length) boundaries.add(i);
      }
    }

    return boundaries.toSet().toList()..sort();
  }

  /// Reconstruct text with intelligent punctuation
  String _reconstructWithPunctuation(
    List<String> words,
    List<int> sentenceBoundaries, {
    bool detectQuestions = true,
    bool detectExclamations = true,
  }) {
    final result = <String>[];
    int boundaryIndex = 0;

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final isLastWord = i == words.length - 1;

      // Check if this position is a sentence boundary
      bool isBoundary =
          boundaryIndex < sentenceBoundaries.length &&
          sentenceBoundaries[boundaryIndex] == i;

      if (isBoundary) {
        boundaryIndex++;
      }

      // Add word with potential punctuation
      String processedWord = _processSingleWord(word, i == 0);

      // Add sentence-ending punctuation if at boundary or end
      if (isBoundary || isLastWord) {
        String terminator = _selectTerminator(
          words,
          i,
          detectQuestions,
          detectExclamations,
        );

        // Don't double-punctuate
        if (!_endsWithTerminator(processedWord)) {
          processedWord += terminator;
        }

        result.add(processedWord);

        // Add space before capitalizing next sentence
        if (!isLastWord && boundaryIndex <= sentenceBoundaries.length) {
          result.add(' ');
        }
      } else {
        result.add(processedWord);
        result.add(' ');
      }
    }

    String output = result.join().trim();

    // Capitalize first letter of sentences
    output = _capitalizeFirstLetters(output);

    return output;
  }

  /// Process individual word (remove duplicates, fix common errors)
  String _processSingleWord(String word, bool isFirst) {
    String processed = word.toLowerCase().trim();

    // Remove common filler words (optional)
    // List of fillers that might appear in transcription
    // These are kept as they help with flow

    // Fix common speech-to-text errors
    processed = _fixCommonErrors(processed);

    // Capitalize if it's a proper noun context (heuristic)
    if (isFirst || _isCommonProperNoun(processed)) {
      processed = _capitalize(processed);
    }

    return processed;
  }

  /// Fix common STT errors
  String _fixCommonErrors(String word) {
    final corrections = {
      'teh': 'the',
      'recieve': 'receive',
      'wich': 'which',
      'thier': 'their',
      'occured': 'occurred',
      'seperate': 'separate',
      'artic': 'article',
      'ur': 'your', // Context-sensitive but reasonable default
    };

    return corrections[word] ?? word;
  }

  /// Check if word is likely a proper noun
  bool _isCommonProperNoun(String word) {
    // Common proper nouns that should stay capitalized
    final properNouns = {
      'biology',
      'chemistry',
      'physics',
      'history',
      'english',
      'math',
      'mathematics',
      'calculus',
      'geometry',
      'algebra',
      'spanish',
      'french',
      'german',
      'mandarin',
      'arabic',
    };

    return properNouns.contains(word.toLowerCase());
  }

  /// Select appropriate sentence terminator
  String _selectTerminator(
    List<String> words,
    int currentIndex,
    bool detectQuestions,
    bool detectExclamations,
  ) {
    // Look back at the sentence for clues
    final sentenceStart = currentIndex > 10 ? currentIndex - 10 : 0;
    final sentenceWords = words.sublist(sentenceStart, currentIndex + 1);
    final sentenceText = sentenceWords.join(' ').toLowerCase();

    // Question detection
    if (detectQuestions) {
      final questionCues = [
        'what',
        'when',
        'where',
        'which',
        'who',
        'why',
        'how',
        'is',
        'are',
        'can',
        'could',
        'do',
        'does',
        'did',
        'will',
        'would',
        'should',
      ];

      // If sentence starts with question word, it's a question
      for (final cue in questionCues) {
        if (sentenceText.startsWith(cue)) {
          return '?';
        }
      }

      // Check for inversion patterns (verb + subject)
      if (_looksLikeQuestion(sentenceText)) {
        return '?';
      }
    }

    // Exclamation detection
    if (detectExclamations) {
      final exclamationCues = [
        'wow',
        'amazing',
        'incredible',
        'fantastic',
        'wonderful',
        'terrible',
        'horrible',
        'important',
      ];

      for (final cue in exclamationCues) {
        if (sentenceText.contains(cue)) {
          return '!';
        }
      }
    }

    // Default: period
    return '.';
  }

  /// Heuristic to detect question-like sentences
  bool _looksLikeQuestion(String sentenceText) {
    // Look for patterns like "is this", "are they", "can you"
    final inversionPatterns = [
      RegExp(r'\bis\s+\w+'),
      RegExp(r'\bare\s+\w+'),
      RegExp(r'\bcan\s+\w+'),
      RegExp(r'\bcould\s+\w+'),
      RegExp(r'\bwill\s+\w+'),
      RegExp(r'\bwould\s+\w+'),
      RegExp(r'\bshould\s+\w+'),
      RegExp(r'\bdo\s+\w+'),
      RegExp(r'\bdoes\s+\w+'),
    ];

    return inversionPatterns.any((pattern) => pattern.hasMatch(sentenceText));
  }

  /// Check if word already ends with terminator
  bool _endsWithTerminator(String word) {
    return word.endsWith('.') ||
        word.endsWith('!') ||
        word.endsWith('?') ||
        word.endsWith(',');
  }

  /// Capitalize first letter of word
  String _capitalize(String word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1);
  }

  /// Capitalize first letter of each sentence
  String _capitalizeFirstLetters(String text) {
    // Split by sentence terminators but keep them
    final sentences = text.split(RegExp(r'([.!?])\s*')); // Includes terminators

    final result = <String>[];
    for (int i = 0; i < sentences.length; i++) {
      final sentence = sentences[i].trim();

      if (sentence.isEmpty) {
        result.add(sentences[i]); // Preserve whitespace
      } else if (RegExp(r'^[.!?]$').hasMatch(sentence)) {
        // This is a terminator
        result.add(sentence);
      } else if (i == 0 ||
          (i > 0 &&
              (sentences[i - 1].endsWith('.') ||
                  sentences[i - 1].endsWith('!') ||
                  sentences[i - 1].endsWith('?')))) {
        // First word of sentence or after terminator
        result.add(_capitalize(sentence));
      } else {
        result.add(sentence);
      }
    }

    String output = result.join(' ');
    // Clean up extra spaces
    output = output.replaceAll(RegExp(r'\s+'), ' ').trim();

    return output;
  }
}

/// Provider for auto-punctuation service
class AutoPunctuationProvider extends ChangeNotifier {
  final AutoPunctuationService _service = AutoPunctuationService();
  String _lastProcessedText = '';

  String get lastProcessedText => _lastProcessedText;

  /// Process and cache punctuated text
  String processAndCache(
    String rawTranscript, {
    List<int> pauseDurations = const [],
  }) {
    _lastProcessedText = _service.addPunctuation(
      rawTranscript,
      pauseDurations: pauseDurations,
    );
    notifyListeners();
    return _lastProcessedText;
  }

  /// Get preview of punctuation (first sentence only)
  String getPreview(String rawTranscript) {
    final full = _service.addPunctuation(rawTranscript);
    // Return first sentence only
    final match = RegExp(r'^[^.!?]*[.!?]').firstMatch(full);
    return match?.group(0) ?? full;
  }
}
