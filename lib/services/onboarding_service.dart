import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage first-time user onboarding state
class OnboardingService {
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _onboardingStepKey = 'onboarding_current_step';
  static const String _onboardingSkippedKey = 'onboarding_skipped';

  static SharedPreferences? _prefs;

  /// Initialize the service
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Check if user has completed onboarding
  static Future<bool> hasCompletedOnboarding() async {
    await init();
    return _prefs?.getBool(_onboardingCompletedKey) ?? false;
  }

  /// Check if user has skipped onboarding
  static Future<bool> hasSkippedOnboarding() async {
    await init();
    return _prefs?.getBool(_onboardingSkippedKey) ?? false;
  }

  /// Mark onboarding as completed
  static Future<void> completeOnboarding() async {
    await init();
    await _prefs?.setBool(_onboardingCompletedKey, true);
    await _prefs?.remove(_onboardingStepKey); // Clean up step tracking
  }

  /// Mark onboarding as skipped
  static Future<void> skipOnboarding() async {
    await init();
    await _prefs?.setBool(_onboardingSkippedKey, true);
  }

  /// Get current onboarding step (for resuming if needed)
  static Future<int> getCurrentStep() async {
    await init();
    return _prefs?.getInt(_onboardingStepKey) ?? 0;
  }

  /// Save current step (for resuming)
  static Future<void> saveCurrentStep(int step) async {
    await init();
    await _prefs?.setInt(_onboardingStepKey, step);
  }

  /// Reset onboarding (for testing or manual trigger)
  static Future<void> resetOnboarding() async {
    await init();
    await _prefs?.remove(_onboardingCompletedKey);
    await _prefs?.remove(_onboardingStepKey);
    await _prefs?.remove(_onboardingSkippedKey);
  }

  /// Check if onboarding should be shown
  static Future<bool> shouldShowOnboarding() async {
    final completed = await hasCompletedOnboarding();
    final skipped = await hasSkippedOnboarding();
    return !completed && !skipped;
  }
}
