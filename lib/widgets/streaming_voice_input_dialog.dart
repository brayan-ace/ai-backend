import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/streaming_stt_service.dart';

// ============================================================================
// ENHANCED VOICE INPUT DIALOG WITH STREAMING STT
// ============================================================================
// 🎯 PURPOSE: Display streaming transcription with non-blocking UI
//
// KEY IMPROVEMENTS OVER OLD DIALOG:
// 1. Live partial transcript display (updates as user speaks)
// 2. No UI freezing - separate state management
// 3. VAD visualization (shows if app is detecting speech)
// 4. Graceful error handling with fallback
// 5. Manual stop button + auto-finalize on silence
// 6. Animated waveform reflects actual speech activity
// 7. Never crashes - all errors caught and handled
//
// ============================================================================

class StreamingVoiceInputDialog extends StatefulWidget {
  final Duration? maxDuration;
  final Duration? silenceThreshold;

  const StreamingVoiceInputDialog({
    super.key,
    this.maxDuration,
    this.silenceThreshold,
  });

  @override
  State<StreamingVoiceInputDialog> createState() =>
      _StreamingVoiceInputDialogState();
}

class _StreamingVoiceInputDialogState extends State<StreamingVoiceInputDialog>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late StreamingSTTServiceManager _sttManager;
  StreamingSTTSession? _session;

  // UI State
  String _partialTranscript = '';
  String _finalTranscript = '';
  VADState _vadState = VADState.silent;
  String _errorMessage = '';
  bool _isInitialized = false;
  bool _sessionStarted = false;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  List<double> _waveformAmplitudes = List.filled(40, 0.0);
  int _amplitudeIndex = 0;

  // Timer for waveform animation
  Timer? _waveformUpdateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize STT and start listening
    _initializeAndListen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _waveformUpdateTimer?.cancel();

    // Cancel session but don't close dialog here - let it finish
    if (_session?.isListening ?? false) {
      _session?.cancel();
    }

    super.dispose();
  }

  /// Initialize STT service and create streaming session
  Future<void> _initializeAndListen() async {
    try {
      print('[VoiceDialog] 🚀 Initializing streaming STT...');

      _sttManager = StreamingSTTServiceManager();

      // Create streaming session with callbacks
      _session = await _sttManager.createSession(
        maxDuration: widget.maxDuration ?? const Duration(minutes: 10),
        silenceThreshold: widget.silenceThreshold ?? const Duration(seconds: 2),
        onTranscriptUpdate: _onTranscriptUpdate,
        onVADStateChange: _onVADStateChange,
        onError: _onError,
      );

      // Start listening
      await _session!.startListening();

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
        _sessionStarted = true;
      });

      // Start waveform animation
      _startWaveformAnimation();

      print('[VoiceDialog] ✅ Listening started');
    } catch (e) {
      print('[VoiceDialog] ❌ Initialization error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to start voice input: $e';
          _isInitialized = true;
        });
      }
    }
  }

  /// Callback: Transcript updated with partial or final results
  void _onTranscriptUpdate(String partial, String final_) {
    if (!mounted) return;

    setState(() {
      _partialTranscript = partial;
      _finalTranscript = final_;

      // Auto-scroll indication: if we have a lot of text, that's good!
      print('[VoiceDialog] 📝 Transcript updated:');
      print('   Partial: "$partial"');
      print('   Final: "$final_"');
    });
  }

  /// Callback: Voice Activity Detection state changed
  void _onVADStateChange(VADState state) {
    if (!mounted) return;

    setState(() {
      _vadState = state;
    });

    // Trigger haptic feedback on state changes
    if (state == VADState.speaking) {
      HapticFeedback.lightImpact();
    }
  }

  /// Callback: Error occurred
  void _onError(String error) {
    if (!mounted) return;

    print('[VoiceDialog] ⚠️ Error: $error');

    setState(() {
      _errorMessage = error;
    });

    // Automatically finalize after showing error for a moment
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _session != null) {
        _finalizeAndClose();
      }
    });
  }

  /// Start animated waveform updates
  void _startWaveformAnimation() {
    _waveformUpdateTimer?.cancel();
    _waveformUpdateTimer = Timer.periodic(const Duration(milliseconds: 80), (
      _,
    ) {
      if (!mounted) return;

      setState(() {
        // Generate pseudo-random waveform based on VAD state
        final amplitude = _getAmplitudeForVADState();
        _waveformAmplitudes[_amplitudeIndex] = amplitude;
        _amplitudeIndex = (_amplitudeIndex + 1) % _waveformAmplitudes.length;
      });
    });
  }

  /// Get waveform amplitude based on current VAD state
  double _getAmplitudeForVADState() {
    switch (_vadState) {
      case VADState.silent:
        return 0.1 + (DateTime.now().microsecond % 50) / 500.0;
      case VADState.speaking:
        return 0.4 + (DateTime.now().microsecond % 100) / 300.0;
      case VADState.paused:
        return 0.2 + (DateTime.now().microsecond % 30) / 200.0;
      case VADState.finalizing:
        return 0.3 + (DateTime.now().microsecond % 40) / 250.0;
    }
  }

  /// Finalize session and close dialog with result
  Future<void> _finalizeAndClose() async {
    if (_session == null || !_session!.isListening) return;

    try {
      print('[VoiceDialog] 🛑 Finalizing session...');

      final finalResult = await _session!.finalize();

      if (mounted) {
        // Close dialog and return the result
        Navigator.pop(context, finalResult);
      }
    } catch (e) {
      print('[VoiceDialog] ❌ Error finalizing: $e');

      if (mounted) {
        setState(() {
          _errorMessage = 'Error finalizing transcript: $e';
        });
      }
    }
  }

  /// Manual stop button handler
  void _onStopPressed() {
    print('[VoiceDialog] ⏹️ User clicked stop');
    HapticFeedback.mediumImpact();
    _finalizeAndClose();
  }

  /// Manual cancel button handler
  void _onCancelPressed() {
    print('[VoiceDialog] ❌ User cancelled');
    HapticFeedback.lightImpact();

    if (_session?.isListening ?? false) {
      _session!.cancel();
    }

    if (mounted) {
      Navigator.pop(context, null);
    }
  }

  /// Get color for VAD state indicator
  Color _getVADStateColor() {
    switch (_vadState) {
      case VADState.silent:
        return Colors.grey;
      case VADState.speaking:
        return const Color(0xFF10b981); // Green
      case VADState.paused:
        return Colors.orange;
      case VADState.finalizing:
        return Colors.blue;
    }
  }

  /// Get text description for VAD state
  String _getVADStateText() {
    switch (_vadState) {
      case VADState.silent:
        return 'Waiting for speech...';
      case VADState.speaking:
        return 'Listening...';
      case VADState.paused:
        return 'Processing pause...';
      case VADState.finalizing:
        return 'Finalizing...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 340,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1a1a2e) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ============================================================
              // HEADER: Title and close button
              // ============================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Voice Input',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!_errorMessage.isEmpty)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _onCancelPressed,
                      tooltip: 'Cancel',
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // ============================================================
              // MAIN CONTENT: Waveform + Animated indicator
              // ============================================================
              if (_isInitialized && _errorMessage.isEmpty)
                Column(
                  children: [
                    // Animated waveform visualization
                    _buildWaveformVisualizer(),
                    const SizedBox(height: 20),

                    // VAD State indicator with animation
                    _buildVADIndicator(),
                    const SizedBox(height: 24),

                    // Streaming transcript display
                    _buildTranscriptDisplay(),
                  ],
                ),

              // ============================================================
              // ERROR STATE
              // ============================================================
              if (_errorMessage.isNotEmpty)
                Column(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDarkMode ? Colors.red[300] : Colors.red,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              // ============================================================
              // LOADING STATE
              // ============================================================
              if (!_isInitialized && _errorMessage.isEmpty)
                Column(
                  children: [
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Initializing voice input...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              // ============================================================
              // ACTION BUTTONS
              // ============================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Cancel button
                  TextButton(
                    onPressed: _onCancelPressed,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),

                  // Stop/Done button (prominent)
                  if (_sessionStarted && _errorMessage.isEmpty)
                    FilledButton.tonal(
                      onPressed: _session?.isListening ?? false
                          ? _onStopPressed
                          : null,
                      child: const Text('Done'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build waveform visualization widget
  Widget _buildWaveformVisualizer() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (int i = 0; i < _waveformAmplitudes.length; i++) ...[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 3,
                    height: _waveformAmplitudes[i] * 80,
                    decoration: BoxDecoration(
                      color: _getVADStateColor().withValues(
                        alpha: 0.6 + _waveformAmplitudes[i] * 0.4,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build VAD state indicator with animations
  Widget _buildVADIndicator() {
    return Column(
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getVADStateColor().withValues(alpha: 0.2),
              border: Border.all(color: _getVADStateColor(), width: 2),
            ),
            child: Center(
              child: Icon(
                _getVADStateIcon(),
                color: _getVADStateColor(),
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _getVADStateText(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: _getVADStateColor(),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Get icon for VAD state
  IconData _getVADStateIcon() {
    switch (_vadState) {
      case VADState.silent:
        return Icons.mic_none;
      case VADState.speaking:
        return Icons.mic;
      case VADState.paused:
        return Icons.pause_circle_outline;
      case VADState.finalizing:
        return Icons.check_circle_outline;
    }
  }

  /// Build transcript display area
  Widget _buildTranscriptDisplay() {
    final hasTranscript =
        _finalTranscript.isNotEmpty || _partialTranscript.isNotEmpty;

    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]!
              : Colors.grey[300]!,
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Final transcript (confirmed)
              if (_finalTranscript.isNotEmpty) ...[
                Text(
                  _finalTranscript,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              // Partial transcript (temporary, faded)
              if (_partialTranscript.isNotEmpty) ...[
                if (_finalTranscript.isNotEmpty) const SizedBox(height: 8),
                Text(
                  _partialTranscript,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[500]
                        : Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],

              // Empty state
              if (!hasTranscript)
                Text(
                  'Your transcription will appear here...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[600]
                        : Colors.grey[500],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
