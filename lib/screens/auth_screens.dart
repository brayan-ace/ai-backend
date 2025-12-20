import 'package:flutter/material.dart';
import '../services/auth_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/globals.dart';
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF42A5F5),
              Color(0xFF880E4F),
            ], // Example gradient colors
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      height: 80,
                    ), // Placeholder for logo
                    const SizedBox(height: 16),
                    Text(
                      isLogin ? 'Welcome Back!' : 'Join MyAI',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isLogin
                          ? 'Sign in to continue'
                          : 'Create an account to get started',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 24),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.8),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (val) =>
                                setState(() => email = val.trim()),
                            validator: (val) => val == null || val.isEmpty
                                ? 'Enter email'
                                : null,
                          ),
                          const SizedBox(height: 16), // Increased spacing
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.8),
                            ),
                            obscureText: true,
                            onChanged: (val) => setState(() => password = val),
                            validator: (val) => val == null || val.length < 6
                                ? 'Password must be >= 6 chars'
                                : null,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(fontSize: 18),
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
                                            ? await _auth.signIn(
                                                email,
                                                password,
                                              )
                                            : await _auth.signUp(
                                                email,
                                                password,
                                              );
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
                                      height:
                                          24, // Increased size for better visibility
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors
                                            .white, // Changed color for contrast
                                      ),
                                    )
                                  : Text(isLogin ? 'Login' : 'Sign Up'),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // TODO: Implement forgot password functionality
                              _showError(
                                'Forgot password functionality not yet implemented.',
                              );
                            },
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(color: Colors.blueAccent),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            child: Text(
                              isLogin
                                  ? 'Don\'t have an account? Sign Up'
                                  : 'Already have an account? Login',
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
      ),
    );
  }
}
