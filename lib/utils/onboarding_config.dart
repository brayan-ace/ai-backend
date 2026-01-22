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
        title: 'Welcome to Nexa Smart AI',
        description:
            'Your personal AI tutor that adapts to your unique learning style. Ask questions naturally and receive personalized explanations that help you truly understand.',
        illustration: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryBlue.withOpacity(0.15),
                AppTheme.accentBlue.withOpacity(0.08),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.2),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.psychology_outlined,
            size: 56,
            color: AppTheme.primaryBlue,
          ),
        ),
        spotlightAlignment: Alignment.center,
        spotlightSize: 180,
      ),

      // Step 2: Chat Interface
      OnboardingStep(
        title: 'Chat Naturally',
        description:
            'Talk with your AI tutor just like you would with a human teacher. Ask questions, get explanations, and explore topics at your own pace.',
        targetKey: chatInputKey,
        illustration: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.accentBlue.withOpacity(0.15),
                AppTheme.accentBlue.withOpacity(0.05),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentBlue.withOpacity(0.2),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.chat_bubble_outline,
            size: 40,
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.success.withOpacity(0.15),
                AppTheme.success.withOpacity(0.05),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.success.withOpacity(0.2),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Icon(Icons.menu, size: 40, color: AppTheme.success),
        ),
      ),

      // Step 4: Study Plan
      OnboardingStep(
        title: 'Personalized Study Plans',
        description:
            'AI creates a custom learning path based on your goals and progress. Your study plan adapts as you learn, ensuring you always know what\'s next.',
        targetKey: studyPlanKey,
        illustration: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.warning.withOpacity(0.15),
                AppTheme.warning.withOpacity(0.05),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.warning.withOpacity(0.2),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Icon(Icons.track_changes, size: 40, color: AppTheme.warning),
        ),
      ),

      // Step 5: Quizzes & Practice
      OnboardingStep(
        title: 'Test Your Knowledge',
        description:
            'Quizzes are automatically generated from what you\'ve learned. Practice when you\'re ready and track your improvement over time.',
        targetKey: quizKey,
        illustration: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.error.withOpacity(0.15),
                AppTheme.error.withOpacity(0.05),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.error.withOpacity(0.2),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Icon(Icons.quiz_outlined, size: 40, color: AppTheme.error),
        ),
      ),

      // Step 6: Completion
      OnboardingStep(
        title: 'Ready to Learn!',
        description:
            'You\'re all set to start your personalized learning journey. Remember, you can always access help and settings from the menu. Let\'s begin!',
        illustration: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryBlue.withOpacity(0.2),
                AppTheme.accentBlue.withOpacity(0.15),
                AppTheme.success.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.3),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Icon(Icons.celebration_outlined, size: 40, color: AppTheme.primaryBlue),
        ),
        spotlightAlignment: Alignment.center,
        spotlightSize: 150,
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
