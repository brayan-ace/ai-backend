import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/theme.dart';
import '../services/auth_services.dart';
import '../widgets/social_media_icons.dart';

// Global keys for navigation and scaffolding
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class AuthScreen extends StatefulWidget {
  final VoidCallback? onAuthenticated;

  const AuthScreen({super.key, this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  bool isLogin = true; // toggle between login and signup
  String email = '';
  String password = '';
  String error = '';
  bool _loading = false;

  void _showError(String msg) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  /// Show forgot password dialog
  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.lock_reset, color: AppTheme.primaryBlue, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Reset Password',
                    style: AppTheme.headlineSmall.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your email address and we\'ll send you a link to reset your password.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: AppTheme.spaceMd),
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: AppTheme.primaryBlue,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.surfaceElevated),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.primaryBlue),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (emailController.text.isEmpty) {
                            _showError('Please enter your email address');
                            return;
                          }

                          setState(() => isLoading = true);
                          Navigator.of(context).pop();

                          try {
                            await FirebaseAuth.instance.sendPasswordResetEmail(
                              email: emailController.text.trim(),
                            );

                            if (mounted) {
                              _showSuccessMessage(
                                'Password reset email sent! Check your inbox.',
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              _showError(
                                'Failed to send reset email: ${e.toString()}',
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => isLoading = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Send Reset Email',
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Show success message
  void _showSuccessMessage(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.success,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.backgroundGradientStart,
              AppTheme.backgroundGradientEnd,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSm),
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: AppTheme.surfaceGradient),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: AppTheme.surfaceElevated.withOpacity(0.5),
                  width: 1,
                ),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/logo.png', height: 80),
                  const SizedBox(height: AppTheme.spaceMd),
                  Text(
                    'MyAI',
                    style: AppTheme.headlineLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    'Your Personal AI Assistant',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                  Text(
                    isLogin ? 'Welcome Back!' : 'Join MyAI',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isLogin
                        ? 'Sign in to continue'
                        : 'Create an account to get started',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppTheme.spaceLg), // Adjusted spacing
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: AppTheme.primaryBlue,
                            ),
                            suffixIcon: email.isNotEmpty && email.contains('@')
                                ? Icon(
                                    Icons.check_circle,
                                    color: AppTheme.success,
                                    size: 20,
                                  )
                                : null,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (val) =>
                              setState(() => email = val.trim()),
                          validator: (val) =>
                              val == null || val.isEmpty ? 'Enter email' : null,
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceMd),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: AppTheme.primaryBlue,
                            ),
                            suffixIcon: password.length >= 6
                                ? Icon(
                                    Icons.check_circle,
                                    color: AppTheme.success,
                                    size: 20,
                                  )
                                : null,
                          ),
                          obscureText: true,
                          onChanged: (val) => setState(() => password = val),
                          validator: (val) => val == null || val.length < 6
                              ? 'Password must be >= 6 chars'
                              : null,
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceLg),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.spaceMd,
                              ),
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLg,
                                ),
                              ),
                            ),
                            onPressed: _loading
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) {
                                      setState(() => _loading = false);
                                      return;
                                    }
                                    setState(() => _loading = true);
                                    User? user;
                                    try {
                                      user = isLogin
                                          ? await _auth.signIn(email, password)
                                          : await _auth.signUp(email, password);
                                    } catch (e) {
                                      if (!mounted) return;
                                      _showError(e.toString());
                                      setState(() => _loading = false);
                                      return;
                                    }

                                    if (!mounted) return;

                                    if (user == null) {
                                      _showError('Authentication failed');
                                      setState(() => _loading = false);
                                      return;
                                    }

                                    if (!user.emailVerified) {
                                      // prompt verify (push on top of tabs instead of replacing)
                                      // navigatorKey.currentState?.push(
                                      //   MaterialPageRoute(
                                      //     builder: (_) =>
                                      //         const VerifyEmailScreen(),
                                      //   ),
                                      // );
                                      // do not call onAuthenticated; wait for verification
                                      setState(() => _loading = false);
                                      return;
                                    }

                                    // If parent provided a callback, call it (embedded use)
                                    if (widget.onAuthenticated != null) {
                                      widget.onAuthenticated!();
                                      setState(() => _loading = false);
                                      return;
                                    }

                                    // navigatorKey.currentState
                                    //     ?.pushReplacementNamed('/ai');
                                    setState(() => _loading = false);
                                  },
                            child: _loading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    isLogin ? 'Login' : 'Sign Up',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceMd),
                        TextButton(
                          onPressed: _showForgotPasswordDialog,
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryBlue,
                          ),
                          child: Text(
                            'Forgot Password?',
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceSm),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textPrimary,
                          ),
                          child: Text(
                            isLogin
                                ? 'Don\'t have an account? Sign Up'
                                : 'Already have an account? Login',
                            style: AppTheme.bodyMedium,
                          ),
                          onPressed: () => setState(() => isLogin = !isLogin),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
