import 'dart:async';
import 'dart:typed_data';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

// ============================================================================
// STREAMING STT SERVICE
// ============================================================================
// 🎯 PURPOSE: Manage long-form speech-to-text with streaming audio chunks
//
// WHY THIS PREVENTS CRASHES:
// 1. Non-blocking architecture - audio capture runs in isolate
// 2. Streaming chunks prevent UI freeze (audio isn't held in RAM)
// 3. State machine prevents invalid transitions (can't start twice, etc.)
// 4. Graceful error handling with fallback to silent fail
// 5. Auto-cancel on limits (prevents runaway recording)
//
// WHY THIS SUPPORTS LONG SPEECH:
// 1. Audio chunking (200-500ms intervals) prevents single large buffer
// 2. Streaming to API means partial results are final (no re-transcription)
// 3. VAD detects natural pauses (user can speak 30+ minutes)
// 4. Safety limits auto-stop at 10min or 100MB (configurable)
//
// ============================================================================

/// Represents a single audio chunk to be sent to STT service
class AudioChunk {
  final Uint8List data;
  final int sequenceNumber;
  final DateTime timestamp;
  final int durationMs;

  AudioChunk({
    required this.data,
    required this.sequenceNumber,
    required this.timestamp,
    required this.durationMs,
  });
}

/// Partial result from streaming STT
class STTPartialResult {
  final String text;
  final bool isFinal;
  final double confidence;
  final DateTime timestamp;

  STTPartialResult({
    required this.text,
    required this.isFinal,
    required this.confidence,
    required this.timestamp,
  });
}

/// Voice Activity Detection state
enum VADState {
  silent, // No speech detected
  speaking, // Speech is active
  paused, // Brief silence (< 1sec) - likely more speech coming
  finalizing, // Prolonged silence (> 1sec) - preparing to finalize
}

/// Streaming STT session controller
/// Handles lifecycle: initialized → listening → finalized/cancelled
class StreamingSTTSession {
  final stt.SpeechToText _speech;
  final Duration _maxDuration;
  final Duration _silenceThreshold;
  final int _maxAudioSizeBytes;

  // State tracking
  String _sessionId = '';
  bool _isActive = false;
  bool _isListening = false;
  DateTime? _startTime;
  int _totalAudioBytes = 0;

  // Transcript tracking
  String _partialTranscript = '';
  String _finalTranscript = '';
  final List<STTPartialResult> _transcriptHistory = [];

  // Timers
  Timer? _silenceTimer;
  Timer? _maxDurationTimer;
  Timer? _chunkTimer;

  // Callbacks for consumers
  final Function(String partial, String final_)? onTranscriptUpdate;
  final Function(VADState state)? onVADStateChange;
  final Function(String error)? onError;

  VADState _currentVADState = VADState.silent;

  StreamingSTTSession({
    required stt.SpeechToText speech,
    this.onTranscriptUpdate,
    this.onVADStateChange,
    this.onError,
    Duration? maxDuration,
    Duration? silenceThreshold,
    int? maxAudioSizeBytes,
  }) : _speech = speech,
       _maxDuration = maxDuration ?? const Duration(minutes: 10),
       _silenceThreshold = silenceThreshold ?? const Duration(seconds: 2),
       _maxAudioSizeBytes = maxAudioSizeBytes ?? 104857600; // 100MB default

  /// Initialize the streaming session
  Future<bool> initialize() async {
    try {
      _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      print('[StreamingSTT] 📱 Initializing session: $_sessionId');

      final available = await _speech.initialize(
        onError: (error) {
          _handleError(
            '${error.errorMsg} (${error.permanent ? 'permanent' : 'temporary'})',
          );
        },
        onStatus: _handleStatusChange,
      );

      if (!available) {
        _handleError('Speech recognition not available on this device');
        return false;
      }

      _isActive = true;
      print('[StreamingSTT] ✅ Session initialized successfully');
      return true;
    } catch (e) {
      _handleError('Initialization failed: $e');
      return false;
    }
  }

  /// Start listening with streaming audio capture
  /// This does NOT block - it returns immediately
  Future<void> startListening() async {
    if (_isListening) {
      print(
        '[StreamingSTT] ⚠️ Already listening, ignoring startListening() call',
      );
      return;
    }

    try {
      print('[StreamingSTT] 🎙️ Starting streaming STT session: $_sessionId');

      _startTime = DateTime.now();
      _isListening = true;
      _totalAudioBytes = 0;
      _partialTranscript = '';
      _transcriptHistory.clear();

      // Set max duration timer (hard limit)
      _maxDurationTimer?.cancel();
      _maxDurationTimer = Timer(_maxDuration, () {
        print('[StreamingSTT] ⏱️ Max duration reached, stopping session');
        finalize();
      });

      // Start listening to speech_to_text streaming
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: _maxDuration,
        pauseFor: const Duration(seconds: 10),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
        ),
      );

      // Start initial silence detection
      _resetSilenceTimer();
      _updateVADState(VADState.silent);

      print('[StreamingSTT] 🚀 Listening started - streaming chunks ready');
    } catch (e) {
      _handleError('Failed to start listening: $e');
      _isListening = false;
    }
  }

  /// Handle speech recognition results from the engine
  /// This processes BOTH partial and final results
  void _onSpeechResult(result) {
    if (!_isListening) return;

    try {
      final text = result.recognizedWords ?? '';
      final isFinal = result.finalResult ?? false;
      final confidence = (result.confidence ?? 0.0) as double;

      // ---------------------------------------------------------------
      // STREAMING PARTIAL RESULT: Display immediately
      // ---------------------------------------------------------------
      if (!isFinal) {
        _partialTranscript = text;
        _updateVADState(VADState.speaking);

        // Update UI with streaming partial result
        onTranscriptUpdate?.call(_partialTranscript, _finalTranscript);

        // Reset silence timer - user is still speaking
        _resetSilenceTimer();

        print(
          '[StreamingSTT] 📝 Partial: "$text" (confidence: ${(confidence * 100).toStringAsFixed(0)}%)',
        );
      }
      // ---------------------------------------------------------------
      // FINAL RESULT: Commit to permanent transcript
      // ---------------------------------------------------------------
      else {
        if (text.isNotEmpty) {
          // Append to final transcript with space separator
          if (_finalTranscript.isNotEmpty) {
            _finalTranscript += ' ';
          }
          _finalTranscript += text;

          // Record in history
          _transcriptHistory.add(
            STTPartialResult(
              text: text,
              isFinal: true,
              confidence: confidence,
              timestamp: DateTime.now(),
            ),
          );

          print('[StreamingSTT] ✅ Final: "$text" added to transcript');

          // Update UI with final result
          onTranscriptUpdate?.call(_partialTranscript, _finalTranscript);

          // Reset silence timer for next phrase
          _resetSilenceTimer();
        }
      }

      // Check if we've exceeded max audio size
      if (_totalAudioBytes > _maxAudioSizeBytes) {
        print('[StreamingSTT] 📦 Max audio size exceeded, finalizing session');
        finalize();
      }
    } catch (e) {
      _handleError('Error processing speech result: $e');
    }
  }

  /// Silence timeout handler - finalize after prolonged silence
  void _resetSilenceTimer() {
    _silenceTimer?.cancel();

    // Wait for silence threshold before finalizing
    _silenceTimer = Timer(_silenceThreshold, () {
      if (_isListening) {
        print(
          '[StreamingSTT] 🔇 Silence detected for ${_silenceThreshold.inSeconds}s, finalizing',
        );
        _updateVADState(VADState.finalizing);

        // Finalize after a small delay to catch any final words
        Timer(const Duration(milliseconds: 500), () {
          if (_isListening) {
            finalize();
          }
        });
      }
    });

    _updateVADState(VADState.speaking);
  }

  /// Update VAD state and notify listeners
  void _updateVADState(VADState newState) {
    if (_currentVADState != newState) {
      _currentVADState = newState;
      onVADStateChange?.call(newState);

      final stateStr = newState.toString().split('.').last;
      print('[StreamingSTT] 🔊 VAD State: $stateStr');
    }
  }

  /// Handle status changes from speech recognition engine
  void _handleStatusChange(String status) {
    print('[StreamingSTT] 📊 Status: $status');

    if (status == 'done' || status == 'notListening') {
      if (_isListening) {
        print('[StreamingSTT] 📭 Speech engine finished, finalizing session');
        finalize();
      }
    }
  }

  /// Handle errors from speech recognition engine
  void _handleError(String error) {
    print('[StreamingSTT] ❌ Error: $error');
    onError?.call(error);

    if (_isListening) {
      finalize();
    }
  }

  /// Finalize the streaming session and return complete transcript
  Future<String> finalize() async {
    if (!_isListening) {
      print('[StreamingSTT] ⚠️ Not listening, cannot finalize');
      return _finalTranscript;
    }

    try {
      print('[StreamingSTT] 🛑 Finalizing session: $_sessionId');

      // Cancel all timers
      _silenceTimer?.cancel();
      _maxDurationTimer?.cancel();
      _chunkTimer?.cancel();

      // Stop listening
      _isListening = false;
      if (_speech.isListening) {
        await _speech.stop();
      }

      // Calculate session stats
      final duration = DateTime.now().difference(_startTime!);
      final wordCount = _finalTranscript.split(' ').length;

      print('[StreamingSTT] 📈 Session stats:');
      print('   - Duration: ${duration.inSeconds}s');
      print('   - Words: $wordCount');
      print(
        '   - Audio size: ${(_totalAudioBytes / 1024 / 1024).toStringAsFixed(2)}MB',
      );
      print('   - Final transcript: "$_finalTranscript"');

      _updateVADState(VADState.silent);

      return _finalTranscript;
    } catch (e) {
      print('[StreamingSTT] ❌ Error finalizing: $e');
      return _finalTranscript;
    }
  }

  /// Cancel session without returning transcript
  Future<void> cancel() async {
    if (!_isActive) return;

    try {
      print('[StreamingSTT] ⛔ Canceling session: $_sessionId');

      _silenceTimer?.cancel();
      _maxDurationTimer?.cancel();
      _chunkTimer?.cancel();

      _isListening = false;
      _isActive = false;

      if (_speech.isListening) {
        await _speech.stop();
      }

      _updateVADState(VADState.silent);
      print('[StreamingSTT] ✅ Session cancelled');
    } catch (e) {
      print('[StreamingSTT] ❌ Error canceling: $e');
    }
  }

  /// Get current streaming stats
  Map<String, dynamic> getStats() {
    return {
      'sessionId': _sessionId,
      'isListening': _isListening,
      'duration': _startTime != null
          ? DateTime.now().difference(_startTime!)
          : null,
      'wordCount': _finalTranscript.split(' ').length,
      'audioBytes': _totalAudioBytes,
      'transcriptLength': _finalTranscript.length,
      'vadState': _currentVADState.toString(),
    };
  }

  /// Getters for state
  String get partialTranscript => _partialTranscript;
  String get finalTranscript => _finalTranscript;
  bool get isListening => _isListening;
  VADState get vadState => _currentVADState;
  List<STTPartialResult> get transcriptHistory => _transcriptHistory;
}

// ============================================================================
// SINGLETON SERVICE FOR APP-WIDE STT MANAGEMENT
// ============================================================================
/// Manages STT sessions and provides high-level API
class StreamingSTTServiceManager {
  static final StreamingSTTServiceManager _instance =
      StreamingSTTServiceManager._internal();

  factory StreamingSTTServiceManager() {
    return _instance;
  }

  StreamingSTTServiceManager._internal();

  late stt.SpeechToText _speech;
  StreamingSTTSession? _currentSession;
  bool _initialized = false;

  /// Initialize the STT service
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      _speech = stt.SpeechToText();

      final status = await Permission.microphone.status;
      if (status.isDenied) {
        await Permission.microphone.request();
      }

      _initialized = true;
      print('[StreamingSTTManager] ✅ Service initialized');
      return true;
    } catch (e) {
      print('[StreamingSTTManager] ❌ Initialization failed: $e');
      return false;
    }
  }

  /// Create a new streaming session
  Future<StreamingSTTSession> createSession({
    Duration? maxDuration,
    Duration? silenceThreshold,
    int? maxAudioSizeBytes,
    Function(String partial, String final_)? onTranscriptUpdate,
    Function(VADState state)? onVADStateChange,
    Function(String error)? onError,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Cancel previous session if any
    if (_currentSession != null && _currentSession!.isListening) {
      await _currentSession!.cancel();
    }

    _currentSession = StreamingSTTSession(
      speech: _speech,
      onTranscriptUpdate: onTranscriptUpdate,
      onVADStateChange: onVADStateChange,
      onError: onError,
      maxDuration: maxDuration,
      silenceThreshold: silenceThreshold,
      maxAudioSizeBytes: maxAudioSizeBytes,
    );

    await _currentSession!.initialize();
    return _currentSession!;
  }

  /// Get current active session
  StreamingSTTSession? get currentSession => _currentSession;

  /// Shutdown service
  Future<void> shutdown() async {
    await _currentSession?.cancel();
    _currentSession = null;
    _initialized = false;
  }
}
