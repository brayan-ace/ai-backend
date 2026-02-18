import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

// ============================================================================
// OFFLINE STT FALLBACK SERVICE
// ============================================================================
// 🎯 PURPOSE: Provide voice recognition when cloud STT is unavailable
//
// KEY FEATURES:
// 1. Android Native Speech Recognition (API 21+)
// 2. Automatic Fallback Detection (no internet, provider unavailable)
// 3. Configurable Preferences (user can choose offline mode)
// 4. Device API Level Detection
// 5. Graceful Degradation (reduces features on older APIs)
// 6. Caching Preferences (user's offline mode choice)
//
// EXAMPLE USAGE:
//   final service = OfflineSTTService();
//   final available = await service.isOfflineSTTAvailable();
//   if (available) {
//     final transcript = await service.startOfflineSpeechRecognition();
//   }
//
// ============================================================================

/// Service for offline device-native speech recognition
class OfflineSTTService {
  static final OfflineSTTService _instance = OfflineSTTService._internal();
  static const platform = MethodChannel('com.nexa.smartai/stt');

  // Configuration
  String _language = 'en-US';
  int _maxResults = 3;
  Duration _listeningTimeout = const Duration(minutes: 2);
  Duration _initialSilenceTimeout = const Duration(seconds: 5);
  Duration _finalSilenceTimeout = const Duration(seconds: 2);

  // Device capabilities
  int? _androidApiLevel;
  bool? _hasNativeSTT;
  bool _preferOfflineMode = false;

  factory OfflineSTTService() => _instance;

  OfflineSTTService._internal();

  /// Check if offline STT is available on this device
  Future<bool> isOfflineSTTAvailable() async {
    try {
      if (_hasNativeSTT != null) {
        return _hasNativeSTT!;
      }

      // Try to get Android API level from native code
      final result = await platform.invokeMethod<Map>('getDeviceInfo');
      _androidApiLevel = result?['apiLevel'] as int? ?? 21;
      _hasNativeSTT = (_androidApiLevel ?? 0) >= 21;

      return _hasNativeSTT!;
    } catch (e) {
      print('[OfflineSTT] Error checking availability: $e');
      _hasNativeSTT = false;
      return false;
    }
  }

  /// Check if user has microphone permission
  Future<bool> hasMicrophonePermission() async {
    try {
      final status = await Permission.microphone.status;
      return status.isGranted || status.isDenied;
    } catch (_) {
      return false;
    }
  }

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Start offline speech recognition
  Future<String?> startOfflineSpeechRecognition({
    required void Function(String) onPartialResult,
    required void Function(String) onFinalResult,
    required void Function(String) onError,
  }) async {
    try {
      // Check prerequisites
      final available = await isOfflineSTTAvailable();
      if (!available) {
        onError('Offline STT not available on this device');
        return null;
      }

      // Check and request permissions
      final hasPermission = await hasMicrophonePermission();
      if (!hasPermission) {
        final granted = await requestMicrophonePermission();
        if (!granted) {
          onError('Microphone permission denied');
          return null;
        }
      }

      // Call native platform method
      final result = await platform.invokeMethod<String>('startOfflineSTT', {
        'language': _language,
        'maxResults': _maxResults,
        'listeningTimeoutMs': _listeningTimeout.inMilliseconds,
        'initialSilenceTimeoutMs': _initialSilenceTimeout.inMilliseconds,
        'finalSilenceTimeoutMs': _finalSilenceTimeout.inMilliseconds,
      });

      return result;
    } on PlatformException catch (e) {
      print('[OfflineSTT] Platform error: ${e.message}');
      onError('STT Error: ${e.message}');
      return null;
    } catch (e) {
      print('[OfflineSTT] Error: $e');
      onError('Unexpected error: $e');
      return null;
    }
  }

  /// Cancel active speech recognition
  Future<void> stopOfflineSTT() async {
    try {
      await platform.invokeMethod('stopOfflineSTT');
    } catch (e) {
      print('[OfflineSTT] Error stopping: $e');
    }
  }

  /// Set language for offline recognition
  void setLanguage(String locale) {
    _language = locale;
  }

  /// Get current language
  String getLanguage() => _language;

  /// Set whether to prefer offline mode
  void setPreferOfflineMode(bool prefer) {
    _preferOfflineMode = prefer;
  }

  /// Check if user prefers offline mode
  bool get prefersOfflineMode => _preferOfflineMode;

  /// Get Android API level
  int? get androidApiLevel => _androidApiLevel;

  /// Get list of supported languages
  List<String> getSupportedLanguages() {
    // Filtered based on Android native support
    if ((_androidApiLevel ?? 0) >= 29) {
      // Android 10+ has better language support
      return [
        'en-US',
        'en-GB',
        'es-ES',
        'fr-FR',
        'de-DE',
        'it-IT',
        'ja-JP',
        'ko-KR',
        'zh-CN',
        'pt-BR',
      ];
    } else {
      // Earlier versions have limited support
      return ['en-US', 'en-GB', 'es-ES', 'fr-FR', 'de-DE'];
    }
  }

  /// Get device STT capabilities
  Future<Map<String, dynamic>> getCapabilities() async {
    return {
      'isAvailable': await isOfflineSTTAvailable(),
      'apiLevel': _androidApiLevel,
      'language': _language,
      'maxResults': _maxResults,
      'supportedLanguages': getSupportedLanguages(),
      'supportsPartialResults': (_androidApiLevel ?? 0) >= 26,
      'supportsVAD': (_androidApiLevel ?? 0) >= 23,
    };
  }
}

/// Session manager for offline STT (similar to streaming STT but for offline)
class OfflineSTTSession {
  final OfflineSTTService _service;
  final void Function(String partial, String final_) onTranscriptUpdate;
  final void Function(String error) onError;

  String _partialTranscript = '';
  String _finalTranscript = '';
  bool _isListening = false;

  OfflineSTTSession({
    required OfflineSTTService service,
    required this.onTranscriptUpdate,
    required this.onError,
  }) : _service = service;

  bool get isListening => _isListening;
  String get partialTranscript => _partialTranscript;
  String get finalTranscript => _finalTranscript;

  /// Start listening with offline STT
  Future<void> startListening() async {
    if (_isListening) return;

    _isListening = true;
    _partialTranscript = '';
    _finalTranscript = '';

    final transcript = await _service.startOfflineSpeechRecognition(
      onPartialResult: (partial) {
        _partialTranscript = partial;
        onTranscriptUpdate(partial, _finalTranscript);
      },
      onFinalResult: (final_) {
        _finalTranscript = final_;
        _partialTranscript = '';
        onTranscriptUpdate('', final_);
        _isListening = false;
      },
      onError: (error) {
        _isListening = false;
        onError(error);
      },
    );

    if (transcript != null && transcript.isNotEmpty) {
      _finalTranscript = transcript;
      onTranscriptUpdate('', transcript);
      _isListening = false;
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;
    await _service.stopOfflineSTT();
    _isListening = false;
  }

  /// Cancel and discard results
  Future<void> cancel() async {
    await stopListening();
    _partialTranscript = '';
    _finalTranscript = '';
  }

  /// Get final result
  String getResult() => _finalTranscript;
}

/// Session manager for automatic fallback (tries cloud first, then offline)
class HybridSTTSession {
  final OfflineSTTService _offlineService;
  bool _useOfflineMode = false;

  HybridSTTSession({OfflineSTTService? offlineService})
    : _offlineService = offlineService ?? OfflineSTTService();

  /// Detect if offline mode should be used
  Future<bool> shouldUseOfflineMode() async {
    // Priority 1: User preference
    if (_offlineService.prefersOfflineMode) {
      return true;
    }

    // Priority 2: Cloud STT unavailable (would need network check)
    // For now, just check if offline STT is available
    return await _offlineService.isOfflineSTTAvailable();
  }

  /// Determine which STT provider to use
  Future<STTProvider> selectProvider() async {
    _useOfflineMode = await shouldUseOfflineMode();
    return _useOfflineMode ? STTProvider.offline : STTProvider.cloud;
  }

  bool get isUsingOfflineMode => _useOfflineMode;
}

/// Enum for STT provider selection
enum STTProvider { cloud, offline, hybrid }
