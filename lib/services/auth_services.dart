import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign up with email & password
  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // send verification email
      try {
        await result.user?.sendEmailVerification();
      } catch (e) {
        // ignore send verification errors here; caller can retry
      }
      return result.user;
    } catch (e) {
      // Error: return null so caller can show an error message
      return null;
    }
  }

  // Sign in with email & password
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // If not verified, keep the user signed in but caller should check
      return result.user;
    } catch (e) {
      // Error: return null so caller can show an error message
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get current user
  User? get currentUser => _auth.currentUser;
}
