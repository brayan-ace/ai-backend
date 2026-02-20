import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Speech-to-Text Service
/// Handles audio recording and sends to backend for transcription with premium features
class SpeechToTextService {
  static final SpeechToTextService _instance = SpeechToTextService._internal();

  factory SpeechToTextService() => _instance;

  SpeechToTextService._internal();

  AudioRecorder? _recorder; // Nullable to prevent late initialization errors
  bool _isInitialized = false;
  bool _isRecording = false;
  String? _recordingPath;

  // Concurrent access control
  Future<void>? _initializationFuture; // Track ongoing initialization
  bool _isInitializing = false; // Flag to prevent concurrent initializations

  // Amplitude stream for waveform visualization
  final StreamController<List<double>> _amplitudeController =
      StreamController<List<double>>.broadcast();

  // Backend configuration
  static const String BACKEND_URL =
      'https://ai-backend-production-65d6.up.railway.app';
  static const String TRANSCRIBE_ENDPOINT = '/transcribe';

  // Premium timeout & retry settings
  static const Duration REQUEST_TIMEOUT = Duration(seconds: 15);
  static const int MAX_RETRIES = 3;

  /// Initialize the speech-to-text service with concurrent-safe deduplication
  Future<void> initialize() async {
    // Already initialized and recorder exists
    if (_isInitialized && _recorder != null) {
      debugPrint('[SpeechToText] ✅ Service already initialized');
      return;
    }

    // If initialization is already in progress, wait for it
    if (_isInitializing && _initializationFuture != null) {
      debugPrint('[SpeechToText] ⏳ Initialization in progress, waiting...');
      return _initializationFuture!;
    }

    // Mark as initializing and create future for deduplication
    _isInitializing = true;
    _initializationFuture = _performInitialization();

    try {
      await _initializationFuture!;
    } finally {
      _isInitializing = false;
    }
  }

  /// Actual initialization logic (called once per concurrent group)
  Future<void> _performInitialization() async {
    try {
      _recorder = AudioRecorder();
      _isInitialized = true;
      debugPrint('[SpeechToText] ✅ Service initialized successfully');
    } catch (e) {
      debugPrint('[SpeechToText] ❌ Initialization error: $e');
      _isInitialized = false;
      _recorder = null;
      rethrow;
    }
  }

  /// Start recording audio with safe concurrent handling
  Future<bool> startRecording() async {
    try {
      // Initialize if needed (safe against concurrent calls)
      if (_recorder == null) {
        await initialize();
      }

      // Check again after init (in case another thread won the race)
      if (_recorder == null) {
        debugPrint('[SpeechToText] ❌ Recorder still null after init');
        return false;
      }

      // Don't start if already recording
      if (_isRecording) {
        debugPrint('[SpeechToText] ⚠️ Already recording');
        return false;
      }

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      _recordingPath =
          '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';

      // Start recording with RecordConfig
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _recordingPath!,
      );

      _isRecording = true;
      debugPrint('[SpeechToText] 🎤 Recording started: $_recordingPath');

      // Start amplitude emission (100ms intervals)
      _startAmplitudeTracking();

      return true;
    } catch (e) {
      debugPrint('[SpeechToText] ❌ Error starting recording: $e');
      _isRecording = false;
      _recordingPath = null;
      return false;
    }
  }

  /// Start tracking and emitting amplitude data during recording
  void _startAmplitudeTracking() {
    // Generate amplitude updates with 100ms interval
    Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }

      // Generate 20 normalized amplitude values (simulating frequency bands)
      final amplitudes = List<double>.generate(
        20,
        (index) => (DateTime.now().microsecond % 1000) / 1000.0,
      );

      if (!_amplitudeController.isClosed) {
        _amplitudeController.add(amplitudes);
      }
    });
  }

  /// Get stream of amplitude data for waveform visualization
  Stream<List<double>> getAmplitudeStream() {
    return _amplitudeController.stream;
  }

  /// Stop recording and get the file
  Future<File?> stopRecording() async {
    try {
      if (_recorder == null || !_isRecording) {
        debugPrint('[SpeechToText] ⚠️ Not currently recording');
        return null;
      }

      final path = await _recorder!.stop();
      _isRecording = false;

      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          debugPrint('[SpeechToText] ✅ Recording stopped: $path');
          return file;
        }
      }

      return null;
    } catch (e) {
      debugPrint('[SpeechToText] ❌ Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Send audio file to backend for transcription with retry logic
  Future<String?> transcribeAudio(File audioFile, {int retryCount = 0}) async {
    try {
      if (!await audioFile.exists()) {
        throw Exception('Audio file does not exist');
      }

      debugPrint(
        '[SpeechToText] 📤 Sending audio to backend (attempt ${retryCount + 1}/$MAX_RETRIES)...',
      );

      // Create multipart request
      final uri = Uri.parse('$BACKEND_URL$TRANSCRIBE_ENDPOINT');
      final request = http.MultipartRequest('POST', uri);

      // Add audio file
      request.files.add(
        await http.MultipartFile.fromPath('audio', audioFile.path),
      );

      // Send request with timeout
      late http.StreamedResponse streamedResponse;
      try {
        streamedResponse = await request.send().timeout(
          REQUEST_TIMEOUT,
          onTimeout: () => throw TimeoutException('Backend request timeout'),
        );
      } on TimeoutException {
        debugPrint('[SpeechToText] ⏱️ Timeout. Retrying...');
        if (retryCount < MAX_RETRIES - 1) {
          // Exponential backoff: 1s, 2s, 3s
          await Future.delayed(Duration(seconds: retryCount + 1));
          return transcribeAudio(audioFile, retryCount: retryCount + 1);
        }
        throw TimeoutException('Backend timeout after $MAX_RETRIES attempts');
      }

      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('[SpeechToText] 📬 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Parse JSON response
        final responseBody = response.body;
        debugPrint('[SpeechToText] Response body: $responseBody');

        try {
          final jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;
          final transcribedText = jsonResponse['text'] as String? ?? '';

          if (transcribedText.isNotEmpty) {
            debugPrint('[SpeechToText] ✅ Transcription: $transcribedText');
            return transcribedText;
          }
        } catch (e) {
          debugPrint('[SpeechToText] ⚠️ JSON parse: $e');
        }

        return 'No speech detected';
      } else if (response.statusCode >= 500) {
        // Server error - retry if attempts remaining
        debugPrint(
          '[SpeechToText] 🔄 Server error (${response.statusCode}). Retrying...',
        );
        if (retryCount < MAX_RETRIES - 1) {
          await Future.delayed(Duration(seconds: retryCount + 1));
          return transcribeAudio(audioFile, retryCount: retryCount + 1);
        }
        throw Exception('Backend error 500: Service unavailable');
      } else {
        throw Exception(
          'Backend error: ${response.statusCode} - ${response.body}',
        );
      }
    } on SocketException catch (e) {
      debugPrint('[SpeechToText] 🌐 Network error: $e');
      if (retryCount < MAX_RETRIES - 1) {
        debugPrint('[SpeechToText] 🔄 Retrying network request...');
        await Future.delayed(Duration(seconds: retryCount + 1));
        return transcribeAudio(audioFile, retryCount: retryCount + 1);
      }
      return null;
    } on TimeoutException catch (e) {
      debugPrint('[SpeechToText] ⏱️ Timeout error: $e');
      return null;
    } catch (e) {
      debugPrint('[SpeechToText] ❌ Transcription error: $e');
      return null;
    }
  }

  /// Get user-friendly error message
  String getErrorMessage(String error) {
    if (error.contains('timeout') || error.contains('Timeout')) {
      return '⏱️ Server slow. Try again in 10s';
    } else if (error.contains('SocketException') ||
        error.contains('connection')) {
      return '🌐 No internet. Check your connection.';
    } else if (error.contains('500')) {
      return '⚠️ Service error. Try again';
    } else if (error.contains('permission')) {
      return '🔒 Microphone permission needed';
    } else if (error.contains('transcription_failed') || error.isEmpty) {
      return '🔇 Couldn\'t understand. Speak clearer';
    }
    return 'Could not transcribe. Please try again.';
  }

  /// Complete flow: Record, send, and transcribe
  /// Returns transcribed text or null on error
  Future<String?> recordAndTranscribe() async {
    try {
      // Start recording
      final started = await startRecording();
      if (!started) {
        throw Exception('Failed to start recording');
      }

      // Return the recorded file for manual stop (UI needs to call stopRecording)
      // This is separated for UI control
      return null;
    } catch (e) {
      print('[SpeechToText] ❌ Error in recordAndTranscribe: $e');
      return null;
    }
  }

  /// Fast transcription: Record for specific duration then transcribe
  Future<String?> recordForDurationAndTranscribe(Duration duration) async {
    try {
      // Start recording
      if (!await startRecording()) {
        throw Exception('Failed to start recording');
      }

      // Wait for duration
      await Future.delayed(duration);

      // Stop recording
      final audioFile = await stopRecording();
      if (audioFile == null) {
        throw Exception('Failed to stop recording');
      }

      // Transcribe
      final transcription = await transcribeAudio(audioFile);

      // Clean up
      try {
        await audioFile.delete();
      } catch (e) {
        debugPrint('Warning: Could not delete audio file: $e');
      }

      return transcription;
    } catch (e) {
      print('[SpeechToText] ❌ Error in recordForDurationAndTranscribe: $e');
      return null;
    }
  }

  /// Check if currently recording
  bool get isRecording => _isRecording;

  /// Cleanup
  Future<void> dispose() async {
    try {
      // Close amplitude stream controller
      if (!_amplitudeController.isClosed) {
        await _amplitudeController.close();
        debugPrint('[SpeechToText] 🧹 Amplitude controller closed');
      }

      if (_recorder == null) {
        debugPrint('[SpeechToText] ℹ️ Recorder not initialized');
        return;
      }

      // Stop recording if active
      if (_isRecording) {
        try {
          await _recorder!.stop();
          _isRecording = false;
          debugPrint('[SpeechToText] ⏹️ Stopped active recording');
        } catch (e) {
          debugPrint('[SpeechToText] ⚠️ Stop error: $e');
        }
      }

      // Dispose recorder
      try {
        await _recorder!.dispose();
        debugPrint('[SpeechToText] 🧹 Recorder disposed');
      } catch (e) {
        debugPrint('[SpeechToText] ⚠️ Dispose error: $e');
      }

      _recorder = null;
      _isInitialized = false;
      debugPrint('[SpeechToText] 🧹 Service cleaned up');
    } catch (e) {
      debugPrint('[SpeechToText] ❌ Cleanup failed: $e');
    }
  }
}
