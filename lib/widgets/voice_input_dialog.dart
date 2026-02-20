import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/speech_to_text_service.dart';
import '../utils/theme.dart';
import '../utils/app_localizations.dart';
import 'waveform_painter.dart';

class VoiceInputDialog extends StatefulWidget {
  const VoiceInputDialog({super.key});

  @override
  State<VoiceInputDialog> createState() => _VoiceInputDialogState();
}

class _VoiceInputDialogState extends State<VoiceInputDialog>
    with SingleTickerProviderStateMixin {
  late final SpeechToTextService _speechService;
  bool _isListening = false;
  bool _isProcessing = false;
  String _transcribedText = '';
  String _errorMessage = '';
  String _statusMessage = 'Ready';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  List<double> _amplitudes = List.filled(20, 0.0);
  Timer? _recordingTimer;
  StreamSubscription<List<double>>? _amplitudeSubscription;

  @override
  void initState() {
    super.initState();
    _speechService = SpeechToTextService();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _speechService.initialize();
      if (mounted) {
        setState(() {
          _statusMessage = AppLocalizations.of(
            context,
          ).t('voiceInput.tapToRecord');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e.toString().contains('permission')) {
            _errorMessage = AppLocalizations.of(
              context,
            ).t('voiceInput.permissionNeeded');
          } else {
            _errorMessage =
                '${AppLocalizations.of(context).t('voiceInput.initError')}: $e';
          }
          _statusMessage = AppLocalizations.of(context).t('voiceInput.error');
        });
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      HapticFeedback.mediumImpact();

      setState(() {
        _isListening = true;
        _isProcessing = false;
        _transcribedText = '';
        _errorMessage = '';
        _statusMessage = AppLocalizations.of(context).t('voiceInput.listening');
        _amplitudes = List.filled(20, 0.0);
      });

      // Start recording
      final started = await _speechService.startRecording();
      if (!started) {
        throw Exception(
          AppLocalizations.of(context).t('voiceInput.recordingFailed'),
        );
      }

      // Subscribe to real amplitude data from service
      _amplitudeSubscription = _speechService.getAmplitudeStream().listen(
        (amplitudes) {
          if (mounted && _isListening) {
            setState(() {
              _amplitudes = amplitudes.length == 20
                  ? amplitudes
                  : List<double>.generate(20, (i) {
                      return i < amplitudes.length ? amplitudes[i] : 0.0;
                    });
            });
          }
        },
        onError: (e) {
          debugPrint('[VoiceDialog] Error in amplitude stream: $e');
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e.toString().contains('PermissionDenied') ||
              e.toString().contains('permission')) {
            _errorMessage = AppLocalizations.of(
              context,
            ).t('voiceInput.micPermissionRequired');
          } else {
            _errorMessage =
                '${AppLocalizations.of(context).t('voiceInput.error')}: $e';
          }
          _isListening = false;
          _statusMessage = AppLocalizations.of(context).t('voiceInput.error');
        });
      }
    }
  }

  Future<void> _stopRecordingAndTranscribe() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    try {
      HapticFeedback.lightImpact();

      setState(() {
        _isListening = false;
        _isProcessing = true;
        _statusMessage = '';
      });

      // Stop recording
      final audioFile = await _speechService.stopRecording();
      if (audioFile == null) {
        throw Exception(
          AppLocalizations.of(context).t('voiceInput.recordingFailedToStop'),
        );
      }

      // Transcribe audio with built-in retry
      final transcription = await _speechService.transcribeAudio(audioFile);

      // Clean up audio file
      try {
        await audioFile.delete();
      } catch (e) {
        debugPrint('Warning: Could not delete audio file: $e');
      }

      if (transcription == null || transcription.isEmpty) {
        throw Exception('transcription_failed');
      }

      if (mounted) {
        setState(() {
          _transcribedText = transcription;
          _isProcessing = false;
          _statusMessage =
              '✅ ${AppLocalizations.of(context).t('voiceInput.done')}';
          _errorMessage = '';
        });

        // Auto-close after 800ms and return result
        await Future.delayed(Duration(milliseconds: 800));
        if (mounted) {
          Navigator.pop(context, transcription);
        }
      }
    } catch (e) {
      final errorMsg = e.toString();
      String userFriendlyError;

      if (errorMsg.contains('transcription_failed')) {
        userFriendlyError = AppLocalizations.of(
          context,
        ).t('voiceInput.couldNotUnderstand');
      } else if (errorMsg.contains('timeout') || errorMsg.contains('Timeout')) {
        userFriendlyError = AppLocalizations.of(
          context,
        ).t('voiceInput.serverTimeout');
      } else if (errorMsg.contains('SocketException') ||
          errorMsg.contains('connection')) {
        userFriendlyError = AppLocalizations.of(
          context,
        ).t('voiceInput.noInternet');
      } else if (errorMsg.contains('500')) {
        userFriendlyError = AppLocalizations.of(
          context,
        ).t('voiceInput.serviceError');
      } else {
        userFriendlyError = _speechService.getErrorMessage(errorMsg);
      }

      if (mounted) {
        setState(() {
          _errorMessage = userFriendlyError;
          _isListening = false;
          _isProcessing = false;
          _statusMessage = AppLocalizations.of(context).t('voiceInput.error');
        });

        // Keep error visible for 3 seconds
        await Future.delayed(Duration(seconds: 3));
        if (mounted) {
          setState(() {
            _errorMessage = '';
            _statusMessage = AppLocalizations.of(
              context,
            ).t('voiceInput.tapToRetry');
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _pulseController.dispose();
    _speechService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          width: 280,
          height: 340,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // Premium glass effect
            gradient: isDarkMode
                ? LinearGradient(
                    colors: [
                      AppTheme.surfaceElevated.withOpacity(0.95),
                      AppTheme.surfaceCard.withOpacity(0.9),
                    ],
                  )
                : LinearGradient(
                    colors: [
                      Color(0xFFFAFAFA).withOpacity(0.95),
                      Color(0xFFF5F5F5).withOpacity(0.9),
                    ],
                  ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDarkMode
                  ? AppTheme.primaryBlue.withOpacity(0.2)
                  : Color(0xFFE5E7EB),
              width: 1.5,
            ),
            boxShadow: [
              // Premium glow effect
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.15),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Close button
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDarkMode
                        ? AppTheme.textTertiary
                        : Color(0xFF6B7280),
                    size: 20,
                  ),
                  onPressed: () {
                    _recordingTimer?.cancel();
                    _amplitudeSubscription?.cancel();
                    if (_isListening) {
                      _speechService.dispose();
                    }
                    Navigator.pop(context);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              ),
              // Main content
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pulsing microphone icon with premium styling
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
                                colors: AppTheme.primaryGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryBlue.withOpacity(0.5),
                                  blurRadius: 25,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.mic,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        );
                      },
                    )
                  else
                    GestureDetector(
                      onTap: _isListening ? null : _startRecording,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isDarkMode
                                ? [
                                    AppTheme.surfaceElevated,
                                    AppTheme.surfaceCard,
                                  ]
                                : [Color(0xFFF3F4F6), Color(0xFFE5E7EB)],
                          ),
                          border: Border.all(
                            color: AppTheme.primaryBlue.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withOpacity(0.1),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.mic,
                          color: AppTheme.primaryBlue,
                          size: 36,
                        ),
                      ),
                    ),

                  const SizedBox(height: 22),

                  // Status indicator: Text or Spinner
                  if (_isProcessing)
                    // Premium spinner during transcription
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Rotating outer circle (border)
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _pulseController.value * 6.28,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.primaryBlue.withOpacity(
                                        0.3,
                                      ),
                                      width: 3,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          // Inner rotating colored circle
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: -_pulseController.value * 6.28,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: AppTheme.primaryGradient,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  else
                    // Status text
                    Text(
                      _errorMessage.isNotEmpty ? _errorMessage : _statusMessage,
                      style: TextStyle(
                        color: _errorMessage.isNotEmpty
                            ? (isDarkMode
                                  ? Color(0xFFEF4444)
                                  : Color(0xFFDC2626))
                            : (isDarkMode
                                  ? AppTheme.textPrimary
                                  : Color(0xFF000000)),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),

                  const SizedBox(height: 18),

                  // Waveform visualization with premium colors
                  if (_isListening)
                    SizedBox(
                      height: 55,
                      child: CustomPaint(
                        size: const Size(double.infinity, 55),
                        painter: WaveformPainter(
                          amplitudes: _amplitudes,
                          gradientColors: AppTheme.primaryGradient,
                          animation: _pulseAnimation,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 55),

                  const SizedBox(height: 14),

                  // Transcribed text preview with premium styling
                  Container(
                    constraints: const BoxConstraints(maxHeight: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: SingleChildScrollView(
                      child: Text(
                        _transcribedText.isEmpty
                            ? AppLocalizations.of(
                                context,
                              ).t('voiceInput.startSpeaking')
                            : _transcribedText,
                        style: TextStyle(
                          color: _transcribedText.isEmpty
                              ? (isDarkMode
                                    ? AppTheme.textTertiary
                                    : Color(0xFF9CA3AF))
                              : (isDarkMode
                                    ? AppTheme.textPrimary
                                    : Color(0xFF1F2937)),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              // Premium Done button during recording
              if (_isListening)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppTheme.primaryGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _stopRecordingAndTranscribe,
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Icons.stop,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
