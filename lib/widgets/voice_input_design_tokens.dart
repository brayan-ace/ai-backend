import 'package:flutter/material.dart';

/// Central design tokens for premium voice input UI
/// Ensures consistency across all voice input components
class VoiceInputDesignTokens {
  // ===================================================================
  // COLOR PALETTE
  // ===================================================================

  static const Color silentStateColor = Color(0xFFEF4444); // Red
  static const Color pausedStateColor = Color(0xFFF59E0B); // Amber
  static const Color speakingStateColor = Color(0xFF10B981); // Green
  static const Color finalizingStateColor = Color(0xFF3B82F6); // Blue

  // Accent colors for different intents
  static const Map<String, Color> intentColors = {
    'create': Color(0xFF10B981), // Green
    'search': Color(0xFF3B82F6), // Blue
    'ask': Color(0xFF8B5CF6), // Purple
    'quiz': Color(0xFFEC4899), // Pink
    'navigate': Color(0xFFF59E0B), // Amber
    'study': Color(0xFF14B8A6), // Teal
  };

  // ===================================================================
  // SPACING
  // ===================================================================

  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;

  // ===================================================================
  // BORDER RADIUS
  // ===================================================================

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 20.0;
  static const double radiusXL = 28.0;

  // ===================================================================
  // ANIMATION DURATIONS
  // ===================================================================

  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // ===================================================================
  // VAD STATE PULSE DURATIONS
  // ===================================================================

  static const Duration pulseSilent = Duration(milliseconds: 1200);
  static const Duration pulsePaused = Duration(milliseconds: 800);
  static const Duration pulseSpeaking = Duration(milliseconds: 500);
  static const Duration pulseFinalizing = Duration(milliseconds: 300);

  // ===================================================================
  // SHADOW DEFINITIONS
  // ===================================================================

  static final List<BoxShadow> shadowSmall = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> shadowLarge = [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];

  static final List<BoxShadow> shadowExtra = [
    BoxShadow(
      color: Colors.black.withOpacity(0.25),
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
  ];

  // ===================================================================
  // GRADIENT DEFINITIONS
  // ===================================================================

  static LinearGradient premiumBackground(bool isDarkMode) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDarkMode
          ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
          : [const Color(0xFFF8FAFC), const Color(0xFFEFF6FF)],
    );
  }

  static LinearGradient glassEffect(bool isDarkMode) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDarkMode
          ? [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]
          : [Colors.white.withOpacity(0.4), Colors.white.withOpacity(0.2)],
    );
  }

  // ===================================================================
  // HELPER METHODS
  // ===================================================================

  /// Get color for VAD state
  static Color getVADStateColor(String vadState) {
    switch (vadState.toLowerCase()) {
      case 'silent':
        return silentStateColor;
      case 'paused':
        return pausedStateColor;
      case 'speaking':
        return speakingStateColor;
      case 'finalizing':
        return finalizingStateColor;
      default:
        return Colors.grey;
    }
  }

  /// Get text label for VAD state
  static String getVADStateLabel(String vadState) {
    switch (vadState.toLowerCase()) {
      case 'silent':
        return 'Waiting...';
      case 'paused':
        return 'Processing...';
      case 'speaking':
        return 'Listening...';
      case 'finalizing':
        return 'Finalizing...';
      default:
        return 'Ready';
    }
  }

  /// Get icon for VAD state
  static IconData getVADStateIcon(String vadState) {
    switch (vadState.toLowerCase()) {
      case 'silent':
        return Icons.mic_none;
      case 'paused':
        return Icons.pause_circle_outline;
      case 'speaking':
        return Icons.mic;
      case 'finalizing':
        return Icons.check_circle_outline;
      default:
        return Icons.mic;
    }
  }

  /// Get background for different states
  static Color getStateBgColor(String vadState, bool isDarkMode) {
    final baseColor = getVADStateColor(vadState);
    return baseColor.withOpacity(isDarkMode ? 0.12 : 0.08);
  }
}
