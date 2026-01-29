import 'package:flutter/material.dart';
import '../services/text_to_speech_service.dart';
import '../utils/theme.dart';

/// TTS Speaker Icon Widget
///
/// Displays a speaker icon for AI messages with state management:
/// - Idle: Gray speaker icon (tap to play)
/// - Speaking: Animated blue speaker icon (tap to stop)
/// - Respects light/dark themes
/// - Compact size to fit inside message bubbles
class TTSSpeakerIcon extends StatefulWidget {
  final String messageId;
  final String messageText;
  final bool isAiMessage;
  final VoidCallback? onSpeakStart;
  final VoidCallback? onSpeakEnd;

  const TTSSpeakerIcon({
    Key? key,
    required this.messageId,
    required this.messageText,
    this.isAiMessage = true,
    this.onSpeakStart,
    this.onSpeakEnd,
  }) : super(key: key);

  @override
  State<TTSSpeakerIcon> createState() => _TTSSpeakerIconState();
}

class _TTSSpeakerIconState extends State<TTSSpeakerIcon>
    with SingleTickerProviderStateMixin {
  late TextToSpeechService _ttsService;
  late AnimationController _animationController;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _ttsService = TextToSpeechService();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Listen to TTS state changes
    _ttsService.addStateListener(_onTtsStateChange);

    // Check if this message is already speaking
    _updateSpeakingState();
  }

  @override
  void dispose() {
    _ttsService.removeStateListener(_onTtsStateChange);
    _animationController.dispose();
    super.dispose();
  }

  void _updateSpeakingState() {
    final isSpeaking = _ttsService.isMessageSpeaking(widget.messageId);
    if (isSpeaking != _isSpeaking) {
      setState(() {
        _isSpeaking = isSpeaking;
        if (_isSpeaking) {
          _animationController.repeat();
        } else {
          _animationController.stop();
          _animationController.reset();
        }
      });
    }
  }

  void _onTtsStateChange(String? messageId, bool isSpeaking) {
    // Update only if this message's state changed
    if (messageId == widget.messageId) {
      _updateSpeakingState();
      if (isSpeaking) {
        widget.onSpeakStart?.call();
      } else {
        widget.onSpeakEnd?.call();
      }
    }
  }

  Future<void> _toggleSpeech() async {
    if (_isSpeaking) {
      // Stop speech
      await _ttsService.stop();
    } else {
      // Start speech
      await _ttsService.speak(
        messageId: widget.messageId,
        text: widget.messageText,
        onStart: widget.onSpeakStart,
        onComplete: widget.onSpeakEnd,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAiMessage) {
      return SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _toggleSpeech,
      child: Tooltip(
        message: _isSpeaking ? 'Stop speaking' : 'Speak message',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.15).animate(
              CurvedAnimation(parent: _animationController, curve: Curves.ease),
            ),
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isSpeaking
                    ? AppTheme.primaryBlue.withOpacity(0.15)
                    : Colors.transparent,
              ),
              child: Icon(
                _isSpeaking
                    ? Icons.volume_up_rounded
                    : Icons.volume_up_outlined,
                size: 16,
                color: _isSpeaking
                    ? AppTheme.primaryBlue
                    : AppTheme.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
