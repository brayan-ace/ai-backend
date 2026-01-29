import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'waveform_painter.dart';

class VoiceInputDialog extends StatefulWidget {
  const VoiceInputDialog({super.key});

  @override
  State<VoiceInputDialog> createState() => _VoiceInputDialogState();
}

class _VoiceInputDialogState extends State<VoiceInputDialog>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _transcribedText = '';
  String _errorMessage = '';
  Timer? _silenceTimer;
  Timer? _autoStopTimer;
  DateTime? _lastSoundDetected;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  List<double> _amplitudes = List.filled(20, 0.0);
  int _amplitudeIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initSpeech();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _silenceTimer?.cancel();
    _autoStopTimer?.cancel();
    try {
      if (_isListening && _speech.isListening) {
        _speech.stop();
      }
    } catch (e) {
      debugPrint('Error disposing speech: $e');
    }
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      // Check microphone permission
      final status = await Permission.microphone.status;

      if (status.isDenied) {
        final result = await Permission.microphone.request();
        if (result.isDenied) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Microphone permission is required';
            });
          }
          return;
        }
        if (result.isPermanentlyDenied) {
          if (mounted) {
            _showPermissionDialog();
          }
          return;
        }
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          _showPermissionDialog();
        }
        return;
      }

      // Initialize speech recognition
      final available = await _speech.initialize(
        onError: (error) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Error: ${error.errorMsg}';
              _isListening = false;
            });
          }
          _silenceTimer?.cancel();
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              _stopListening();
            }
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _speechAvailable = available;
        if (!available) {
          _errorMessage = 'Speech recognition not available';
        }
      });

      if (available) {
        await _startListening();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize: $e';
        });
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: const Text(
          'Please enable microphone permission in your device settings to use voice input.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _startListening() async {
    if (!_speechAvailable || _isListening) return;

    try {
      HapticFeedback.mediumImpact();

      if (!mounted) return;

      setState(() {
        _isListening = true;
        _transcribedText = '';
        _errorMessage = '';
        _lastSoundDetected = DateTime.now();
      });

      // Start the auto-stop timer for maximum listening duration (5 minutes)
      _autoStopTimer?.cancel();
      _autoStopTimer = Timer(const Duration(minutes: 5), () {
        if (mounted && _isListening) {
          _stopListening();
        }
      });

      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;

          setState(() {
            _transcribedText = result.recognizedWords;
          });

          // Reset silence timer when sound is detected
          if (result.recognizedWords.isNotEmpty) {
            _resetSilenceTimer();
          }

          // Update waveform with simulated amplitude
          if (_isListening) {
            setState(() {
              _amplitudes[_amplitudeIndex] = result.hasConfidenceRating
                  ? (result.confidence * 0.8 + 0.2)
                  : 0.6;
              _amplitudeIndex = (_amplitudeIndex + 1) % _amplitudes.length;
            });
          }
        },
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 10),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
        ),
      );

      // Start initial silence timer
      _resetSilenceTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to start listening: $e';
          _isListening = false;
        });
      }
    }
  }

  void _resetSilenceTimer() {
    _lastSoundDetected = DateTime.now();
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _isListening) {
        final now = DateTime.now();
        final silenceDuration = now.difference(_lastSoundDetected!);
        if (silenceDuration.inSeconds >= 8) {
          _stopListening();
        }
      }
    });
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;

    try {
      HapticFeedback.lightImpact();

      _silenceTimer?.cancel();
      _autoStopTimer?.cancel();

      if (_speech.isListening) {
        await _speech.stop();
      }

      if (!mounted) return;

      setState(() {
        _isListening = false;
      });

      // Return the transcribed text and close dialog
      if (mounted) {
        Navigator.pop(context, _transcribedText);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to stop listening: $e';
          _isListening = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 280,
        height: 270,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xE61E1E1E) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Close button
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: Icon(
                  Icons.close,
                  color: isDarkMode ? Colors.white70 : Color(0xFF6B7280),
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            // Main content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing microphone icon
                if (_isListening)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.blue.shade600,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: Colors.white,
                            size: 35,
                          ),
                        ),
                      );
                    },
                  )
                else
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDarkMode
                          ? Colors.grey.shade700
                          : Color(0xFFE5E7EB),
                    ),
                    child: Icon(
                      Icons.mic,
                      color: isDarkMode ? Colors.white : Color(0xFF1F2937),
                      size: 35,
                    ),
                  ),

                const SizedBox(height: 20),

                // Status text
                Text(
                  _errorMessage.isNotEmpty
                      ? _errorMessage
                      : _isListening
                      ? 'Listening...'
                      : 'Initializing...',
                  style: TextStyle(
                    color: _errorMessage.isNotEmpty
                        ? (isDarkMode
                              ? Colors.red.shade300
                              : Colors.red.shade600)
                        : (isDarkMode ? Colors.white : Color(0xFF1F2937)),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 16),

                // Waveform visualization
                if (_isListening)
                  SizedBox(
                    height: 55,
                    child: CustomPaint(
                      size: const Size(double.infinity, 55),
                      painter: WaveformPainter(
                        amplitudes: _amplitudes,
                        gradientColors: [
                          Colors.blue.shade400,
                          Colors.blue.shade600,
                        ],
                        animation: _pulseAnimation,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 55),

                const SizedBox(height: 12),

                // Transcribed text preview
                Container(
                  constraints: const BoxConstraints(maxHeight: 35),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SingleChildScrollView(
                    child: Text(
                      _transcribedText.isEmpty
                          ? 'Start speaking...'
                          : _transcribedText,
                      style: TextStyle(
                        color: _transcribedText.isEmpty
                            ? (isDarkMode ? Colors.white54 : Color(0xFF9CA3AF))
                            : (isDarkMode ? Colors.white : Color(0xFF1F2937)),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            // Checkmark button to manually stop
            if (_isListening)
              Positioned(
                bottom: 0,
                right: 0,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.green,
                  onPressed: _stopListening,
                  child: const Icon(Icons.check, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
