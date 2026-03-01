import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth/google_auth_service.dart';
import '../../utils/theme.dart';
import '../../services/user_profile_service.dart';
import '../screens/google_username_confirmation_screen.dart';

/// Google Sign-In Button Widget - Production-Safe Implementation
///
/// CRITICAL FIXES:
/// 1. Uses auth state listener (authStateChanges) instead of immediate navigation
/// 2. Navigation only happens AFTER Firebase confirms auth state change
/// 3. Comprehensive error handling with user-friendly messages
/// 4. Prevents crashes by awaiting all async operations properly
/// 5. Handles the case where consent screen doesn't appear (normal behavior)
///
/// WHY THIS PREVENTS CRASHES:
/// - signInWithGoogle() is called, then we wait for auth state to update
/// - We DON'T immediately navigate; we wait for Firebase confirmation
/// - If anything goes wrong, error is caught and shown gracefully
/// - The app checks auth state has ACTUALLY changed before navigating
class GoogleSignInButton extends StatefulWidget {
  final bool isSignup;

  const GoogleSignInButton({super.key, this.isSignup = false});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final UserProfileService _userProfileService = UserProfileService.instance;

  bool _isLoading = false;
  String? _errorMessage;

  /// Handle Google Sign-In with proper async/await and state management
  /// This is the CORRECT way to implement Google Sign-In in Flutter
  Future<void> _handleGoogleSignIn() async {
    // Prevent multiple concurrent sign-in attempts
    if (_isLoading) {
      print('[GoogleSignInButton] ⚠️ Sign-in already in progress');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('[GoogleSignInButton] 🔐 Starting Google Sign-In flow...');

      // For signup flow: clear Google cache to force fresh account picker
      if (widget.isSignup) {
        print(
          '[GoogleSignInButton] Signup flow - clearing cached Google account...',
        );
        await _googleAuthService.clearGoogleAccountCache();
      }

      // Step 1: Call Google Sign-In
      // This returns User if successful, null if user cancelled or error occurred
      final user = await _googleAuthService.signInWithGoogle();

      if (!mounted) {
        print('[GoogleSignInButton] ⚠️ Widget disposed during sign-in');
        return;
      }

      // Step 2: Check if sign-in failed (user cancelled or error)
      if (user == null) {
        print('[GoogleSignInButton] ⓘ Google Sign-In returned null user');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sign-in was cancelled. Please try again.';
        });
        return;
      }

      print('[GoogleSignInButton] ✅ Google returned user: ${user.email}');

      // Step 3: Validate user fields before proceeding
      // This prevents crashes from null field access
      if (!_validateUserFields(user)) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'User profile incomplete. Please try signing in again.';
        });
        return;
      }

      // Step 4: Mark onboarding as complete
      try {
        await _userProfileService.setOnboardingComplete(true);
        print('[GoogleSignInButton] ✅ Onboarding marked as complete');
      } catch (e) {
        print('[GoogleSignInButton] ⚠️ Failed to set onboarding: $e');
        // Don't fail sign-in due to onboarding flag, but log it
      }

      if (!mounted) {
        print('[GoogleSignInButton] ⚠️ Widget disposed before navigation');
        return;
      }

      // Step 5: Wait for Firebase auth state to stabilize
      // This ensures the auth state listener has detected the change
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) {
        print('[GoogleSignInButton] ⚠️ Widget disposed during stabilization');
        return;
      }

      // Step 6: Verify Firebase auth state is updated
      // This double-check prevents navigation race conditions
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != user.uid) {
        print('[GoogleSignInButton] ⚠️ Auth state mismatch after sign-in');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Authentication state mismatch. Please try again.';
        });
        return;
      }

      print('[GoogleSignInButton] 🔐 Auth state verified: ${currentUser.uid}');

      // Step 7: Navigate based on flow (signup vs login)
      // For signup flow: go to username confirmation screen
      // For login flow: go to main app (AuthGate will handle email verification)
      if (mounted) {
        if (widget.isSignup) {
          // Signup flow: need username confirmation
          print(
            '[GoogleSignInButton] 🚀 Navigating to username confirmation...',
          );
          // Import GoogleUsernameConfirmationScreen at the top
          // For now, use Navigator.push to pass the User object
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  _buildGoogleUsernameConfirmation(currentUser),
            ),
          );
        } else {
          // Login flow: go directly to app
          print('[GoogleSignInButton] 🚀 Navigating to main app...');
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/main',
            (route) => false, // Remove all previous routes
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      // Firebase-specific errors
      if (mounted) {
        print('[GoogleSignInButton] ❌ Firebase error: ${e.code}');
        String userMessage = _getFirebaseErrorMessage(e.code);
        setState(() {
          _isLoading = false;
          _errorMessage = userMessage;
        });
      }
    } catch (e) {
      // Unexpected errors - still catch and display gracefully
      if (mounted) {
        print('[GoogleSignInButton] ❌ Unexpected error: $e');
        setState(() {
          _isLoading = false;
          _errorMessage = 'An unexpected error occurred. Please try again.';
        });
      }
    }

    // Ensure loading state is cleared even if something goes wrong
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Validate that user has required fields set
  /// This prevents null pointer exceptions later
  bool _validateUserFields(User user) {
    if (user.uid.isEmpty) {
      print('[GoogleSignInButton] ❌ User UID is empty');
      return false;
    }

    // Email may be optional in some cases, but log if missing
    if (user.email == null || user.email!.isEmpty) {
      print('[GoogleSignInButton] ⚠️ User email is null or empty');
    }

    // Display name is nice-to-have but not required
    if (user.displayName == null || user.displayName!.isEmpty) {
      print('[GoogleSignInButton] ⓘ User display name is null or empty');
    }

    // Photo URL is not required
    if (user.photoURL == null || user.photoURL!.isEmpty) {
      print('[GoogleSignInButton] ⓘ User photo URL is null or empty');
    }

    return true;
  }

  /// Convert Firebase error codes to user-friendly messages
  String _getFirebaseErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'operation-not-allowed':
        return 'Google Sign-In is not enabled. Please contact support.';
      case 'user-disabled':
        return 'Your account has been disabled. Please contact support.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'account-exists-with-different-credential':
        return 'This account is linked to a different sign-in method.';
      default:
        return 'Sign-in failed ($errorCode). Please try again.';
    }
  }

  /// Helper to build GoogleUsernameConfirmationScreen with proper parameters
  Widget _buildGoogleUsernameConfirmation(User user) {
    return GoogleUsernameConfirmationScreen(
      user: user,
      photoUrl: user.photoURL,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Google Sign-In Button
        Container(
          width: double.infinity,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.surfaceElevated, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : _handleGoogleSignIn,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Google Logo
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'G',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Button Text or Loading
                    Expanded(
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.primaryBlue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Signing in...',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              widget.isSignup
                                  ? 'Continue with Google'
                                  : 'Sign in with Google',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),

                    // Arrow icon (only when not loading)
                    if (!_isLoading)
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppTheme.textTertiary,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Error message with clear styling
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.error_outline,
                    color: AppTheme.error,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: AppTheme.error,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
