import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/onboarding_service.dart';
import '../widgets/onboarding_overlay.dart';
import '../utils/onboarding_config.dart';
import '../screens/online_ai_screen.dart';

void main() {
  group('Onboarding System Tests', () {
    setUp(() async {
      // Reset shared preferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('should show onboarding for new users', () async {
      final shouldShow = await OnboardingService.shouldShowOnboarding();
      expect(shouldShow, true);
    });

    test('should not show onboarding after completion', () async {
      await OnboardingService.completeOnboarding();
      final shouldShow = await OnboardingService.shouldShowOnboarding();
      expect(shouldShow, false);
    });

    test('should not show onboarding after skipping', () async {
      await OnboardingService.skipOnboarding();
      final shouldShow = await OnboardingService.shouldShowOnboarding();
      expect(shouldShow, false);
    });

    test('should track current step correctly', () async {
      await OnboardingService.saveCurrentStep(2);
      final currentStep = await OnboardingService.getCurrentStep();
      expect(currentStep, 2);
    });

    test('should reset onboarding state', () async {
      // Complete onboarding first
      await OnboardingService.completeOnboarding();
      expect(await OnboardingService.shouldShowOnboarding(), false);

      // Reset onboarding
      await OnboardingService.resetOnboarding();
      expect(await OnboardingService.shouldShowOnboarding(), true);
      expect(await OnboardingService.getCurrentStep(), 0);
      expect(await OnboardingService.hasSkippedOnboarding(), false);
    });

    testWidgets('onboarding overlay renders correctly', (WidgetTester tester) async {
      // Create test widget
      final testWidget = MaterialApp(
        home: Scaffold(
          body: OnboardingOverlay(
            steps: OnboardingConfig.getSteps(),
            onComplete: () {},
            onSkip: () {},
          ),
        ),
      );

      await tester.pumpWidget(testWidget);
      await tester.pumpAndSettle();

      // Verify overlay is rendered
      expect(find.byType(OnboardingOverlay), findsOneWidget);
      
      // Verify step indicators are rendered
      expect(find.byType(AnimatedContainer), findsWidgets);
      
      // Verify content card is rendered
      expect(find.byType(Container), findsWidgets);
      
      // Verify navigation buttons are rendered
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('onboarding steps navigate correctly', (WidgetTester tester) async {
      bool onCompleteCalled = false;
      bool onSkipCalled = false;

      final testWidget = MaterialApp(
        home: Scaffold(
          body: OnboardingOverlay(
            steps: OnboardingConfig.getSteps(),
            onComplete: () => onCompleteCalled = true,
            onSkip: () => onSkipCalled = true,
          ),
        ),
      );

      await tester.pumpWidget(testWidget);
      await tester.pumpAndSettle();

      // Test next button
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Test skip button
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(onSkipCalled, true);
    });

    testWidgets('onboarding completes after last step', (WidgetTester tester) async {
      bool onCompleteCalled = false;

      final testWidget = MaterialApp(
        home: Scaffold(
          body: OnboardingOverlay(
            steps: OnboardingConfig.getSteps(),
            onComplete: () => onCompleteCalled = true,
            onSkip: () {},
          ),
        ),
      );

      await tester.pumpWidget(testWidget);
      await tester.pumpAndSettle();

      // Navigate through all steps
      for (int i = 0; i < OnboardingConfig.getSteps().length - 1; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      // On last step, button should say "Start Learning"
      expect(find.text('Start Learning'), findsOneWidget);
      
      // Tap finish button
      await tester.tap(find.text('Start Learning'));
      await tester.pumpAndSettle();

      expect(onCompleteCalled, true);
    });

    test('onboarding config has correct number of steps', () {
      final steps = OnboardingConfig.getSteps();
      expect(steps.length, 6); // Should have exactly 6 steps
    });

    test('onboarding config has all required keys', () {
      final keys = OnboardingConfig.getKeys();
      expect(keys.containsKey('welcome'), true);
      expect(keys.containsKey('chatInput'), true);
      expect(keys.containsKey('hamburgerMenu'), true);
      expect(keys.containsKey('studyPlan'), true);
      expect(keys.containsKey('quiz'), true);
    });

    test('onboarding steps have proper content', () {
      final steps = OnboardingConfig.getSteps();
      
      // Welcome step
      expect(steps[0].title, contains('Welcome'));
      expect(steps[0].description, contains('personal'));
      expect(steps[0].illustration, isNotNull);
      
      // Chat interface step
      expect(steps[1].title, contains('Chat'));
      expect(steps[1].description, contains('naturally'));
      expect(steps[1].targetKey, isNotNull);
      
      // Menu step
      expect(steps[2].title, contains('Learning Hub'));
      expect(steps[2].description, contains('menu'));
      expect(steps[2].targetKey, isNotNull);
      
      // Study plan step
      expect(steps[3].title, contains('Study Plan'));
      expect(steps[3].description, contains('personalized'));
      expect(steps[3].targetKey, isNotNull);
      
      // Quiz step
      expect(steps[4].title, contains('Test'));
      expect(steps[4].description, contains('Quizzes'));
      expect(steps[4].targetKey, isNotNull);
      
      // Completion step
      expect(steps[5].title, contains('Ready'));
      expect(steps[5].description, contains('journey'));
      expect(steps[5].illustration, isNotNull);
    });
  });

  group('Online AI Screen Integration Tests', () {
    testWidgets('onboarding initializes correctly on AI screen', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      final testWidget = MaterialApp(
        home: OnlineAiScreen(),
      );

      await tester.pumpWidget(testWidget);
      await tester.pumpAndSettle();

      // Onboarding should be initialized and potentially shown
      // The exact behavior depends on the onboarding service state
      expect(find.byType(OnlineAiScreen), findsOneWidget);
    });
  });
}
