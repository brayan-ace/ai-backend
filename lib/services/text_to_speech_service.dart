import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-Speech Service
///
/// Singleton service for managing speech synthesis across the app.
/// Features:
/// - On-device TTS using flutter_tts
/// - Only one message can speak at a time
/// - Automatic stop when new message is tapped
/// - LaTeX sanitization before speaking
/// - Speaking state tracking
/// - Clean resource management
class TextToSpeechService {
  static final TextToSpeechService _instance = TextToSpeechService._internal();

  factory TextToSpeechService() => _instance;

  TextToSpeechService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  String? _currentlySpeakingMessageId;
  bool _isInitialized = false;

  /// Speaking state listener
  final List<void Function(String? messageId, bool isSpeaking)>
  _stateListeners = [];

  /// Initialize the TTS service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configure TTS
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5); // Slower speech for clarity
      await _flutterTts.setVolume(1.0);

      // Listen to completion
      _flutterTts.completionHandler = _onSpeechComplete;

      _isInitialized = true;
      print('[TTS] ✅ Text-to-Speech service initialized');
    } catch (e) {
      print('[TTS] ❌ Error initializing TTS: $e');
      rethrow;
    }
  }

  /// Sanitize text before speaking
  /// Removes LaTeX formatting, emojis, and special characters to make speech natural
  String _sanitizeForSpeech(String text) {
    var sanitized = text;

    // Remove ALL dollar signs and LaTeX expressions first (both display and inline)
    // This catches $1, $$...$$ and $...$ patterns
    sanitized = sanitized.replaceAll(
      RegExp(r'\$\$[\s\S]*?\$\$'),
      '',
    ); // $$...$$
    sanitized = sanitized.replaceAll(
      RegExp(r'\$[^\s]*'),
      '',
    ); // $anything including $1
    sanitized = sanitized.replaceAll(
      RegExp(r'\\\[[\s\S]*?\\\]'),
      '',
    ); // \[...\]
    sanitized = sanitized.replaceAll(
      RegExp(r'\\\([\s\S]*?\\\)'),
      '',
    ); // \(...\)

    // Remove ALL emojis and special Unicode characters
    // Matches emoji patterns and other non-ASCII characters that shouldn't be spoken
    sanitized = sanitized.replaceAll(
      RegExp(
        r'[\p{Emoji}\p{Emoji_Component}\p{Emoji_Modifier}\p{Emoji_Modifier_Base}\p{Emoji_Presentation}]',
        unicode: true,
      ),
      '',
    );

    // Remove common Markdown formatting
    sanitized = sanitized.replaceAll(
      RegExp(r'\*\*([^*]*)\*\*'),
      r'$1',
    ); // **bold**
    sanitized = sanitized.replaceAll(RegExp(r'\*([^*]*)\*'), r'$1'); // *italic*
    sanitized = sanitized.replaceAll(RegExp(r'__([^_]*)__'), r'$1'); // __bold__
    sanitized = sanitized.replaceAll(RegExp(r'_([^_]*)_'), r'$1'); // _italic_
    sanitized = sanitized.replaceAll(
      RegExp(r'~~([^~]*)~~'),
      r'$1',
    ); // ~~strikethrough~~
    sanitized = sanitized.replaceAll(
      RegExp(r'\[([^\]]*)\]\([^)]*\)'),
      r'$1',
    ); // [link](url)

    // Remove code block markers and code formatting
    sanitized = sanitized.replaceAll(
      RegExp(r'```[\s\S]*?```'),
      '',
    ); // ```...```
    sanitized = sanitized.replaceAll(RegExp(r'`([^`]*)`'), r'$1'); // `code`

    // Remove markdown headings
    sanitized = sanitized.replaceAll(
      RegExp(r'^#{1,6}\s+', multiLine: true),
      '',
    );

    // Remove markdown list markers
    sanitized = sanitized.replaceAll(
      RegExp(r'^\s*[-•*]\s+', multiLine: true),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'^\s*\d+\.\s+', multiLine: true),
      '',
    );

    // Remove HTML tags
    sanitized = sanitized.replaceAll(RegExp(r'<[^>]*>'), '');

    // Remove special symbols and punctuation that don't need to be read
    sanitized = sanitized.replaceAll(RegExp(r'[~^`|{}\[\]\\]+'), '');

    // Clean up extra whitespace
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Handle common text replacements for better speech
    sanitized = sanitized.replaceAll('&', 'and');
    sanitized = sanitized.replaceAll('e.g.', 'for example');
    sanitized = sanitized.replaceAll('i.e.', 'that is');
    sanitized = sanitized.replaceAll('etc.', 'etcetera');

    return sanitized;
  }

  /// Speak AI message text
  /// Returns true if speech started successfully
  Future<bool> speak({
    required String messageId,
    required String text,
    VoidCallback? onStart,
    VoidCallback? onComplete,
  }) async {
    try {
      // Ensure service is initialized
      if (!_isInitialized) {
        await initialize();
      }

      // Stop any currently speaking message
      if (_currentlySpeakingMessageId != null &&
          _currentlySpeakingMessageId != messageId) {
        await stop();
      }

      // Sanitize text for natural speech
      final sanitized = _sanitizeForSpeech(text);

      // Check if text is empty after sanitization
      if (sanitized.isEmpty) {
        print('[TTS] ⚠️ Empty text after sanitization for message: $messageId');
        return false;
      }

      print(
        '[TTS] 🔊 Speaking message: $messageId (${sanitized.length} chars)',
      );

      _currentlySpeakingMessageId = messageId;
      _notifyStateChange(messageId, true);

      onStart?.call();

      // Speak the sanitized text
      await _flutterTts.speak(sanitized);

      return true;
    } catch (e) {
      print('[TTS] ❌ Error speaking: $e');
      _currentlySpeakingMessageId = null;
      _notifyStateChange(messageId, false);
      return false;
    }
  }

  /// Stop current speech
  Future<void> stop() async {
    try {
      final wasPlaying = _currentlySpeakingMessageId != null;
      final messageId = _currentlySpeakingMessageId;

      await _flutterTts.stop();
      _currentlySpeakingMessageId = null;

      if (wasPlaying && messageId != null) {
        _notifyStateChange(messageId, false);
        print('[TTS] ⏹️ Speech stopped for message: $messageId');
      }
    } catch (e) {
      print('[TTS] ❌ Error stopping speech: $e');
    }
  }

  /// Pause current speech
  Future<void> pause() async {
    try {
      await _flutterTts.pause();
      print('[TTS] ⏸️ Speech paused');
    } catch (e) {
      print('[TTS] ❌ Error pausing speech: $e');
    }
  }

  /// Check if a specific message is currently speaking
  bool isMessageSpeaking(String messageId) =>
      _currentlySpeakingMessageId == messageId;

  /// Get currently speaking message ID (null if nothing is speaking)
  String? getCurrentlySpeakingMessageId() => _currentlySpeakingMessageId;

  /// Register listener for speaking state changes
  void addStateListener(
    void Function(String? messageId, bool isSpeaking) listener,
  ) {
    _stateListeners.add(listener);
  }

  /// Remove listener
  void removeStateListener(
    void Function(String? messageId, bool isSpeaking) listener,
  ) {
    _stateListeners.remove(listener);
  }

  /// Internal method called when speech completes
  void _onSpeechComplete() {
    final messageId = _currentlySpeakingMessageId;
    _currentlySpeakingMessageId = null;

    if (messageId != null) {
      _notifyStateChange(messageId, false);
      print('[TTS] ✅ Speech completed for message: $messageId');
    }
  }

  /// Notify all listeners of state change
  void _notifyStateChange(String? messageId, bool isSpeaking) {
    for (final listener in _stateListeners) {
      listener(messageId, isSpeaking);
    }
  }

  /// Dispose service (cleanup resources)
  Future<void> dispose() async {
    try {
      await _flutterTts.stop();
      _currentlySpeakingMessageId = null;
      _stateListeners.clear();
      print('[TTS] 🧹 Text-to-Speech service disposed');
    } catch (e) {
      print('[TTS] ❌ Error disposing TTS: $e');
    }
  }
}
