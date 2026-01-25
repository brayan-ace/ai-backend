import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google Authentication Service
///
/// Handles Google Sign-In integration with Firebase Authentication.
/// Provides clean methods for signing in with Google and handles all error cases.
class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Sign in with Google
  ///
  /// Returns the authenticated User on success, null on failure.
  /// Handles all common error scenarios and provides detailed logging.
  Future<User?> signInWithGoogle() async {
    try {
      print('[GoogleAuth] 🚀 Starting Google Sign-In process...');

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('[GoogleAuth] ❌ User cancelled Google Sign-In');
        return null;
      }

      print('[GoogleAuth] ✅ Google account selected: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      print('[GoogleAuth] 🔑 Google auth credentials obtained');

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      print('[GoogleAuth] 🏗️ Firebase credential created');

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        print('[GoogleAuth] ✅ User authenticated successfully');
        print('[GoogleAuth] 👤 User details:');
        print('  - UID: ${user.uid}');
        print('  - Email: ${user.email}');
        print('  - Display Name: ${user.displayName}');
        print('  - Photo URL: ${user.photoURL}');
        print('  - Email Verified: ${user.emailVerified}');
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print('[GoogleAuth] ❌ Firebase Auth Error: ${e.code} - ${e.message}');
      _handleFirebaseAuthError(e);
      return null;
    } catch (e) {
      print('[GoogleAuth] ❌ Unexpected error during Google Sign-In: $e');
      return null;
    }
  }

  /// Sign out from Google and Firebase
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      print('[GoogleAuth] 👋 Signed out successfully');
    } catch (e) {
      print('[GoogleAuth] ❌ Error during sign out: $e');
    }
  }

  /// Handle Firebase Auth specific errors
  void _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        print('[GoogleAuth] ⚠️ Account exists with different credential');
        break;
      case 'invalid-credential':
        print('[GoogleAuth] ⚠️ Invalid Google credential');
        break;
      case 'operation-not-allowed':
        print('[GoogleAuth] ⚠️ Google sign-in not enabled in Firebase');
        break;
      case 'user-disabled':
        print('[GoogleAuth] ⚠️ User account disabled');
        break;
      case 'user-not-found':
        print('[GoogleAuth] ⚠️ User not found');
        break;
      case 'wrong-password':
        print('[GoogleAuth] ⚠️ Wrong password (should not happen with Google)');
        break;
      case 'invalid-verification-code':
        print('[GoogleAuth] ⚠️ Invalid verification code');
        break;
      case 'invalid-verification-id':
        print('[GoogleAuth] ⚠️ Invalid verification ID');
        break;
      default:
        print('[GoogleAuth] ⚠️ Unknown Firebase Auth error: ${e.code}');
    }
  }

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  /// Listen to auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
