import 'package:flutter/material.dart';
import '../../services/auth/google_auth_service.dart';
import '../../utils/theme.dart';
import '../../services/user_profile_service.dart';

/// Google Sign-In Button Widget
///
/// A premium-styled Google Sign-In button that integrates seamlessly
/// with the app's design system. Handles loading states, errors, and navigation.
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final UserProfileService _userProfileService = UserProfileService.instance;

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _googleAuthService.signInWithGoogle();

      if (user != null && mounted) {
        // Mark onboarding as complete for Google users
        await _userProfileService.setOnboardingComplete(true);

        // Navigate directly to online AI screen for Google users
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/ai',
            (route) => false, // Remove all previous routes
          );
        }
      } else if (mounted) {
        // User cancelled or sign-in failed
        setState(() {
          _errorMessage = user == null
              ? 'Sign-in cancelled or failed. Please try again.'
              : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
        });
        print('[GoogleSignInButton] ❌ Unexpected error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Google Sign-In Button
        Container(
          width: double.infinity,
          height: 64, // Increased from 56 to 64
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(20), // Increased from 16 to 20
            border: Border.all(color: AppTheme.surfaceElevated, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12, // Increased from 8 to 12
                offset: const Offset(0, 3), // Increased offset
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : _handleGoogleSignIn,
              borderRadius: BorderRadius.circular(
                20,
              ), // Increased from 16 to 20
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ), // Increased from 16 to 20
                child: Row(
                  children: [
                    // Google Logo (Text-based for reliability)
                    Container(
                      width: 28, // Increased from 24 to 28
                      height: 28, // Increased from 24 to 28
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'G',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18, // Increased from 16 to 18
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16), // Increased from 12 to 16
                    // Button Text
                    Expanded(
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 24, // Increased from 20 to 24
                                  height: 24, // Increased from 20 to 24
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.primaryBlue,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 16,
                                ), // Increased from 12 to 16
                                Text(
                                  'Signing in...',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 18, // Increased from 16 to 18
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Continue with Google',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18, // Increased from 16 to 18
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),

                    // Arrow icon (only when not loading)
                    if (!_isLoading)
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppTheme.textTertiary,
                        size: 20, // Increased from 16 to 20
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Error message
        if (_errorMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.error.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: AppTheme.error, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
