import 'package:flutter/material.dart';
import '../services/streaming_stt_service.dart';
import '../utils/theme.dart';

/// Premium Voice Activity Detection (VAD) Visual Indicator
/// Shows animated visual feedback for different speech states:
/// 🔴 Silent (red, low pulsing)
/// 🟡 Paused (yellow, medium pulsing)
/// 🟢 Speaking (green, high pulsing)
/// 🔵 Finalizing (blue, processing)

class VADVisualIndicator extends StatefulWidget {
  final VADState vadState;
  final bool isRecording;
  final Duration animationDuration;

  const VADVisualIndicator({
    Key? key,
    required this.vadState,
    required this.isRecording,
    this.animationDuration = const Duration(milliseconds: 600),
  }) : super(key: key);

  @override
  State<VADVisualIndicator> createState() => _VADVisualIndicatorState();
}

class _VADVisualIndicatorState extends State<VADVisualIndicator>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    // Pulse animation - continuous loop
    _pulseController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Scale animation - responsive to state
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
  }

  @override
  void didUpdateWidget(VADVisualIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vadState != widget.vadState) {
      // Trigger scale animation on state change
      _scaleController.forward().then((_) {
        _scaleController.reverse();
      });

      // Adjust pulse speed based on state
      _pulseController.duration = _getPulseDuration();
    }
  }

  Duration _getPulseDuration() {
    switch (widget.vadState) {
      case VADState.silent:
        return const Duration(milliseconds: 1000); // Slow pulse
      case VADState.paused:
        return const Duration(milliseconds: 700); // Medium pulse
      case VADState.speaking:
        return const Duration(milliseconds: 500); // Fast pulse
      case VADState.finalizing:
        return const Duration(milliseconds: 300); // Very fast pulse
    }
  }

  Color _getStateColor() {
    switch (widget.vadState) {
      case VADState.silent:
        return const Color(0xFFEF4444); // Red
      case VADState.paused:
        return const Color(0xFFF59E0B); // Amber
      case VADState.speaking:
        return const Color(0xFF10B981); // Green
      case VADState.finalizing:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  String _getStateLabel() {
    switch (widget.vadState) {
      case VADState.silent:
        return 'Silent';
      case VADState.paused:
        return 'Paused';
      case VADState.speaking:
        return 'Speaking';
      case VADState.finalizing:
        return 'Processing...';
    }
  }

  IconData _getStateIcon() {
    switch (widget.vadState) {
      case VADState.silent:
        return Icons.mic_off;
      case VADState.paused:
        return Icons.pause_circle;
      case VADState.speaking:
        return Icons.mic;
      case VADState.finalizing:
        return Icons.done_all;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final stateColor = _getStateColor();

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _scaleAnimation]),
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                stateColor.withOpacity(0.15),
                stateColor.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: stateColor.withOpacity(0.3), width: 2),
          ),
          child: Row(
            children: [
              // Animated pulsing indicator dot
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: stateColor.withOpacity(_pulseAnimation.value),
                  boxShadow: [
                    BoxShadow(
                      color: stateColor.withOpacity(
                        _pulseAnimation.value * 0.5,
                      ),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // State info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getStateLabel(),
                      style: TextStyle(
                        color: stateColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getStateDescription(),
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // State icon
              Transform.scale(
                scale: _scaleAnimation.value,
                child: Icon(_getStateIcon(), color: stateColor, size: 24),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getStateDescription() {
    switch (widget.vadState) {
      case VADState.silent:
        return 'Waiting for your voice...';
      case VADState.paused:
        return 'Brief pause detected';
      case VADState.speaking:
        return 'Speech detected - keep talking!';
      case VADState.finalizing:
        return 'Finalizing transcription...';
    }
  }
}

/// Animated waveform ring that responds to microphone input
/// Shows intensity level visually
class MicrophoneRing extends StatefulWidget {
  final VADState vadState;
  final double intensity; // 0.0 to 1.0

  const MicrophoneRing({Key? key, required this.vadState, this.intensity = 0.5})
    : super(key: key);

  @override
  State<MicrophoneRing> createState() => _MicrophoneRingState();
}

class _MicrophoneRingState extends State<MicrophoneRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _ringAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getRingColor() {
    switch (widget.vadState) {
      case VADState.silent:
        return const Color(0xFFEF4444).withOpacity(0.5);
      case VADState.paused:
        return const Color(0xFFF59E0B).withOpacity(0.5);
      case VADState.speaking:
        return const Color(0xFF10B981).withOpacity(0.5);
      case VADState.finalizing:
        return const Color(0xFF3B82F6).withOpacity(0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ringAnimation,
      builder: (context, child) {
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _getRingColor(),
              width: 2 + (widget.intensity * 2),
            ),
            boxShadow: [
              BoxShadow(
                color: _getRingColor(),
                blurRadius: 8 + (_ringAnimation.value * 12),
                spreadRadius: _ringAnimation.value * 4,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
              child: Icon(Icons.mic, size: 40, color: AppTheme.primaryBlue),
            ),
          ),
        );
      },
    );
  }
}
