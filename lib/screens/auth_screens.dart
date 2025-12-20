import 'package:flutter/material.dart';
import '../services/auth_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/globals.dart';
import '../utils/theme.dart';
import 'verify_email_screen.dart';

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
                                      navigatorKey.currentState?.push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const VerifyEmailScreen(),
                                        ),
                                      );
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

                                    navigatorKey.currentState
                                        ?.pushReplacementNamed('/ai');
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
                          onPressed: () {
                            // TODO: Implement forgot password functionality
                            _showError(
                              'Forgot password functionality not yet implemented.',
                            );
                          },
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
