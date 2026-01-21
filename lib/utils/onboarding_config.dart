import 'package:flutter/material.dart';
import '../widgets/onboarding_overlay.dart';
import '../utils/theme.dart';

/// Configuration for the first-time user onboarding experience
class OnboardingConfig {
  static GlobalKey welcomeKey = GlobalKey();
  static GlobalKey chatInputKey = GlobalKey();
  static GlobalKey hamburgerMenuKey = GlobalKey();
  static GlobalKey studyPlanKey = GlobalKey();
  static GlobalKey quizKey =
      studyPlanKey; // Same as studyPlanKey since quizzes are accessed through study plans

  /// Get the complete list of onboarding steps
  static List<OnboardingStep> getSteps() {
    return [
      // Step 1: Welcome
      OnboardingStep(
        title: 'Welcome to Nexa AI',
        description:
            'Your personal AI tutor that adapts to your learning style. Ask questions naturally and get personalized explanations.',
        illustration: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.school_outlined,
            size: 48,
            color: AppTheme.primaryBlue,
          ),
        ),
        spotlightAlignment: Alignment.center,
        spotlightSize: 150,
      ),

      // Step 2: Chat Interface
      OnboardingStep(
        title: 'Natural Conversations',
        description:
            'Chat with your AI tutor just like you would with a human teacher. Ask questions, get explanations, and explore topics at your own pace.',
        targetKey: chatInputKey,
        illustration: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.accentBlue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.chat_bubble_outline,
            size: 32,
            color: AppTheme.accentBlue,
          ),
        ),
      ),

      // Step 3: Hamburger Menu
      OnboardingStep(
        title: 'Your Learning Hub',
        description:
            'This menu contains your study plan, progress tracking, and all your learning tools. Everything you need is organized here.',
        targetKey: hamburgerMenuKey,
        illustration: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.menu, size: 32, color: AppTheme.success),
        ),
      ),

      // Step 4: Study Plan
      OnboardingStep(
        title: 'Personalized Study Plans',
        description:
            'AI creates a custom learning path based on your goals and progress. Your study plan adapts as you learn.',
        targetKey: studyPlanKey,
        illustration: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.track_changes, size: 32, color: AppTheme.warning),
        ),
      ),

      // Step 5: Quizzes & Practice
      OnboardingStep(
        title: 'Test Your Knowledge',
        description:
            'Quizzes are automatically generated from what you\'ve learned. Practice when you\'re ready and track your improvement.',
        targetKey: quizKey,
        illustration: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.error.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.quiz, size: 32, color: AppTheme.error),
        ),
      ),

      // Step 6: Completion
      OnboardingStep(
        title: 'Ready to Learn!',
        description:
            'You\'re all set to start your personalized learning journey. Remember, you can always access help and settings from the menu.',
        illustration: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryBlue.withOpacity(0.2),
                AppTheme.accentBlue.withOpacity(0.2),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.celebration, size: 32, color: AppTheme.primaryBlue),
        ),
        spotlightAlignment: Alignment.center,
        spotlightSize: 120,
      ),
    ];
  }

  /// Get keys that need to be attached to UI elements
  static Map<String, GlobalKey> getKeys() {
    return {
      'welcome': welcomeKey,
      'chatInput': chatInputKey,
      'hamburgerMenu': hamburgerMenuKey,
      'studyPlan': studyPlanKey,
      'quiz': quizKey,
    };
  }
}
