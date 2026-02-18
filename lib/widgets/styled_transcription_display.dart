import 'package:flutter/material.dart';
import '../utils/theme.dart';
import 'voice_input_design_tokens.dart';

/// Premium styled transcription display for voice input
/// Shows partial (interim) results in gray and finalized text in white
/// with smooth animations and visual distinction

class StyledTranscriptionDisplay extends StatelessWidget {
  /// The finalized transcript text accumulated so far
  final String finalTranscript;

  /// The partial (interim) transcript from current speaking segment
  final String partialTranscript;

  /// Total confidence of the transcription (0.0 to 1.0)
  final double confidence;

  /// Whether currently recording audio
  final bool isRecording;

  /// Triggered when user selects/highlights text
  final Function(String)? onTextSelected;

  const StyledTranscriptionDisplay({
    Key? key,
    required this.finalTranscript,
    required this.partialTranscript,
    this.confidence = 0.0,
    this.isRecording = false,
    this.onTextSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: VoiceInputDesignTokens.spacing16,
          vertical: VoiceInputDesignTokens.spacing12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transcription text with styled segments
            _buildStyledTranscript(context, isDarkMode),

            if (finalTranscript.isNotEmpty)
              SizedBox(height: VoiceInputDesignTokens.spacing16),

            // Helpful hints
            if (finalTranscript.isEmpty && partialTranscript.isEmpty)
              _buildHelpText(isDarkMode),
          ],
        ),
      ),
    );
  }

  /// Build the main styled transcript with final + partial segments
  Widget _buildStyledTranscript(BuildContext context, bool isDarkMode) {
    if (finalTranscript.isEmpty && partialTranscript.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Start speaking...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? Colors.white54 : Colors.black54,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Final transcript section
        if (finalTranscript.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (partialTranscript.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: VoiceInputDesignTokens.spacing8,
                  ),
                  child: Text(
                    'Finalized',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDarkMode ? Colors.white54 : Colors.black54,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              Text(
                finalTranscript,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),

        // Partial transcript section (with animation)
        if (partialTranscript.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (finalTranscript.isNotEmpty)
                SizedBox(height: VoiceInputDesignTokens.spacing12),
              if (finalTranscript.isNotEmpty)
                Text(
                  'Interim',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              if (finalTranscript.isNotEmpty)
                SizedBox(height: VoiceInputDesignTokens.spacing4),
              Text(
                partialTranscript,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Show helpful hints when transcript is empty
  Widget _buildHelpText(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [
                    AppTheme.primaryBlue.withOpacity(0.15),
                    AppTheme.accentBlue.withOpacity(0.1),
                  ]
                : [
                    AppTheme.primaryBlue.withOpacity(0.08),
                    AppTheme.accentBlue.withOpacity(0.05),
                  ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryBlue, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Voice Input Tips',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '• Speak clearly and naturally\n'
              '• Wait for the pause before stopping\n'
              '• Avoid background noise when possible\n'
              '• Use punctuation words (comma, period, question mark)',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.grey[700],
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
