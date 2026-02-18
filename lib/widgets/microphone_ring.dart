import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/streaming_stt_service.dart';
import 'voice_input_design_tokens.dart';

/// Premium animated microphone ring indicator
/// Shows concentric rings that pulse based on voice activity intensity
class MicrophoneRing extends StatefulWidget {
  final VADState vadState;
  final double intensity; // 0.0 to 1.0
  final Duration animationDuration;

  const MicrophoneRing({
    Key? key,
    required this.vadState,
    required this.intensity,
    this.animationDuration = const Duration(milliseconds: 1500),
  }) : super(key: key);

  @override
  State<MicrophoneRing> createState() => _MicrophoneRingState();
}

class _MicrophoneRingState extends State<MicrophoneRing>
    with TickerProviderStateMixin {
  late AnimationController _ringController;
  late Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _ringController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    )..repeat();

    _ringAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(MicrophoneRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.intensity != widget.intensity) {
      // Adjust animation speed based on intensity
      _ringController.duration = Duration(
        milliseconds: (1500 * (0.5 + widget.intensity * 0.5)).toInt(),
      );
    }
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = VoiceInputDesignTokens.getVADStateColor(
      widget.vadState.toString().split('.').last,
    );

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring (largest, slowest fade)
          _buildRing(
            animation: _ringAnimation,
            color: baseColor,
            maxRadius: 100,
            startOpacity: 0.0,
            endOpacity: 0.1,
            intensity: widget.intensity,
          ),

          // Middle ring
          _buildRing(
            animation: _ringAnimation,
            color: baseColor,
            maxRadius: 70,
            startOpacity: 0.0,
            endOpacity: 0.2,
            intensity: widget.intensity,
            delay: 0.33,
          ),

          // Inner ring (closest, brightest)
          _buildRing(
            animation: _ringAnimation,
            color: baseColor,
            maxRadius: 50,
            startOpacity: 0.0,
            endOpacity: 0.4,
            intensity: widget.intensity,
            delay: 0.66,
          ),

          // Center microphone icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  baseColor.withOpacity(0.9),
                  baseColor.withOpacity(0.7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Optional: haptic feedback
                  HapticFeedback.lightImpact();
                },
                child: Center(
                  child: Icon(
                    VoiceInputDesignTokens.getVADStateIcon(
                      widget.vadState.toString().split('.').last,
                    ),
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRing({
    required Animation<double> animation,
    required Color color,
    required double maxRadius,
    required double startOpacity,
    required double endOpacity,
    required double intensity,
    double delay = 0.0,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // Apply delay by offsetting the animation value
        var delayedValue = (animation.value + delay) % 1.0;

        return Container(
          width: maxRadius * 2,
          height: maxRadius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(
                startOpacity +
                    (endOpacity - startOpacity) * delayedValue * intensity,
              ),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}
