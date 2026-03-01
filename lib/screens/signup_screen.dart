import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/theme.dart';
import 'email_verification_screen.dart';

/// Sign-up screen with username, email, password fields
/// Features inline validation, loading states, and detailed error handling
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Validation states for real-time feedback
  bool _usernameValid = false;
  bool _emailValid = false;
  bool _passwordValid = false;
  String? _usernameError;
  String? _emailError;
  String? _passwordError;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();

    // Add listeners for real-time validation
    _usernameController.addListener(_validateUsername);
    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateUsername() {
    final username = _usernameController.text.trim();
    setState(() {
      if (username.isEmpty) {
        _usernameValid = false;
        _usernameError = null;
      } else if (username.length < 3) {
        _usernameValid = false;
        _usernameError = 'Username must be at least 3 characters';
      } else if (username.length > 20) {
        _usernameValid = false;
        _usernameError = 'Username must be less than 20 characters';
      } else if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
        _usernameValid = false;
        _usernameError = 'Only letters, numbers, and underscores allowed';
      } else {
        _usernameValid = true;
        _usernameError = null;
      }
    });
  }

  void _validateEmail() {
    final email = _emailController.text.trim();
    setState(() {
      if (email.isEmpty) {
        _emailValid = false;
        _emailError = null;
      } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        _emailValid = false;
        _emailError = 'Please enter a valid email address';
      } else {
        _emailValid = true;
        _emailError = null;
      }
    });
  }

  void _validatePassword() {
    final password = _passwordController.text;
    setState(() {
      if (password.isEmpty) {
        _passwordValid = false;
        _passwordError = null;
      } else if (password.length < 8) {
        _passwordValid = false;
        _passwordError = 'Password must be at least 8 characters';
      } else if (!RegExp(r'[A-Z]').hasMatch(password)) {
        _passwordValid = false;
        _passwordError = 'Password must contain at least one uppercase letter';
      } else if (!RegExp(r'[a-z]').hasMatch(password)) {
        _passwordValid = false;
        _passwordError = 'Password must contain at least one lowercase letter';
      } else if (!RegExp(r'[0-9]').hasMatch(password)) {
        _passwordValid = false;
        _passwordError = 'Password must contain at least one number';
      } else if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
        _passwordValid = false;
        _passwordError = 'Password must contain at least one special character';
      } else {
        _passwordValid = true;
        _passwordError = null;
      }
    });
  }

  bool get _isFormValid => _usernameValid && _emailValid && _passwordValid;

  Future<void> _handleSignUp() async {
    if (!_isFormValid) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final username = _usernameController.text.trim();

      // Create user with Firebase
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      if (credential.user != null) {
        // Update Firebase display name
        await credential.user!.updateDisplayName(username);

        // Send verification email
        try {
          await credential.user!.sendEmailVerification();
        } catch (e) {
          // Log but continue - user can resend from verification screen
        }

        if (!mounted) return;

        // Navigate to email verification screen
        // Username will be saved after email is verified
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                EmailVerificationScreen(email: email, username: username),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getFirebaseErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Try logging in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Sign up failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.backgroundGradientStart,
              AppTheme.backgroundGradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Back button
                  IconButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/signup-choice');
                    },
                    icon: Icon(
                      Icons.arrow_back_ios_rounded,
                      color: AppTheme.textPrimary,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surfaceCard,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Header
                  Text(
                    'Complete Your Profile',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your details to get started',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Username field
                        _buildTextField(
                          controller: _usernameController,
                          label: 'Username',
                          hint: 'Choose a username',
                          icon: Icons.person_outline_rounded,
                          isValid: _usernameValid,
                          errorText: _usernameError,
                          textInputAction: TextInputAction.next,
                        ),

                        const SizedBox(height: 24),

                        // Email field
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'Enter your email',
                          icon: Icons.email_outlined,
                          isValid: _emailValid,
                          errorText: _emailError,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                        ),

                        const SizedBox(height: 24),

                        // Password field
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hint:
                              '8+ chars, uppercase, lowercase, number, special char',
                          icon: Icons.lock_outline_rounded,
                          isValid: _passwordValid,
                          errorText: _passwordError,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _handleSignUp(),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ),

                        // Password requirements
                        const SizedBox(height: 16),
                        _buildPasswordRequirements(),

                        const SizedBox(height: 32),

                        // Error message
                        if (_errorMessage != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.error.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: AppTheme.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: AppTheme.error,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Sign up button
                        _buildSignUpButton(),

                        const SizedBox(height: 32),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isValid,
    String? errorText,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Widget? suffixIcon,
    void Function(String)? onSubmitted,
  }) {
    final hasContent = controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: errorText != null
                  ? AppTheme.error.withOpacity(0.5)
                  : isValid
                  ? AppTheme.success.withOpacity(0.5)
                  : AppTheme.surfaceElevated,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.textPrimary
                  : Color(0xFF374151),
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 16),
              prefixIcon: Icon(icon, color: AppTheme.textTertiary),
              suffixIcon:
                  suffixIcon ??
                  (hasContent
                      ? Icon(
                          isValid ? Icons.check_circle : Icons.cancel,
                          color: isValid ? AppTheme.success : AppTheme.error,
                          size: 20,
                        )
                      : null),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              errorText,
              style: TextStyle(color: AppTheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildPasswordRequirements() {
    final password = _passwordController.text;
    final hasMinLength = password.length >= 8;
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRequirement('At least 8 characters', hasMinLength),
        _buildRequirement('Contains an uppercase letter', hasUppercase),
        _buildRequirement('Contains a lowercase letter', hasLowercase),
        _buildRequirement('Contains a number', hasNumber),
        _buildRequirement('Contains a special character', hasSpecialChar),
      ],
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? AppTheme.success : AppTheme.textTertiary,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? AppTheme.success : AppTheme.textTertiary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: _isFormValid && !_isLoading
            ? LinearGradient(colors: AppTheme.primaryGradient)
            : null,
        color: _isFormValid && !_isLoading ? null : AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isFormValid && !_isLoading
            ? [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isFormValid && !_isLoading ? _handleSignUp : null,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Create Account',
                    style: TextStyle(
                      color: _isFormValid
                          ? Colors.white
                          : AppTheme.textTertiary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
