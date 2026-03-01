import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/theme.dart';
import 'email_verification_screen.dart';

/// Google Username Confirmation Screen
/// Shown after user signs in with Google to confirm/set their username
class GoogleUsernameConfirmationScreen extends StatefulWidget {
  final User user;
  final String? photoUrl;

  const GoogleUsernameConfirmationScreen({
    super.key,
    required this.user,
    this.photoUrl,
  });

  @override
  State<GoogleUsernameConfirmationScreen> createState() =>
      _GoogleUsernameConfirmationScreenState();
}

class _GoogleUsernameConfirmationScreenState
    extends State<GoogleUsernameConfirmationScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  bool _isLoading = false;
  bool _usernameValid = false;
  String? _usernameError;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );
    _fadeController.forward();

    // Pre-fill username from Google display name if available
    if (widget.user.displayName != null &&
        widget.user.displayName!.isNotEmpty) {
      _usernameController.text = widget.user.displayName!
          .replaceAll(' ', '_')
          .toLowerCase();
      _validateUsername();
    }

    _usernameController.addListener(_validateUsername);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _usernameController.dispose();
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

  Future<void> _handleConfirm() async {
    if (!_usernameValid) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final username = _usernameController.text.trim();

      // Update the Firebase user's display name with the confirmed username
      await widget.user.updateDisplayName(username);

      // Refresh the user to get updated data
      await widget.user.reload();

      if (!mounted) return;

      // For Google sign-in, email is typically already verified
      // Check if email is verified, if so go directly to app
      if (widget.user.emailVerified) {
        print(
          '[GoogleUsernameConfirm] Email already verified via Google, navigating to app',
        );
        Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
      } else {
        // If not verified (edge case), show email verification screen
        try {
          await widget.user.sendEmailVerification();
        } catch (e) {
          print('Error sending verification email: $e');
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(
              email: widget.user.email ?? '',
              username: username,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
      print('Error updating username: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),

                    // Back button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () {
                          Navigator.pop(context);
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
                    ),

                    const SizedBox(height: 48),

                    // Profile Picture
                    if (widget.photoUrl != null && widget.photoUrl!.isNotEmpty)
                      ClipOval(
                        child: Image.network(
                          widget.photoUrl!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar();
                          },
                        ),
                      )
                    else
                      _buildDefaultAvatar(),

                    const SizedBox(height: 32),

                    // Header
                    Text(
                      'Complete Your Profile',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a username to get started',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Email Display (Read-only)
                    _buildEmailDisplay(),

                    const SizedBox(height: 24),

                    // Username Field
                    _buildUsernameField(),

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

                    // Confirm button
                    _buildConfirmButton(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.primaryBlueDark],
        ),
      ),
      child: Center(
        child: Icon(Icons.person_rounded, size: 50, color: Colors.white),
      ),
    );
  }

  Widget _buildEmailDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceElevated, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Email',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.email_outlined, color: AppTheme.textTertiary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.user.email ?? '',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                ),
              ),
              Icon(Icons.check_circle, color: AppTheme.success, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameField() {
    final hasContent = _usernameController.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Username',
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
              color: _usernameError != null
                  ? AppTheme.error.withOpacity(0.5)
                  : _usernameValid
                  ? AppTheme.success.withOpacity(0.5)
                  : AppTheme.surfaceElevated,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: _usernameController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleConfirm(),
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Choose a username',
              hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 16),
              prefixIcon: Icon(
                Icons.person_outline_rounded,
                color: AppTheme.textTertiary,
              ),
              suffixIcon: hasContent
                  ? Icon(
                      _usernameValid ? Icons.check_circle : Icons.cancel,
                      color: _usernameValid ? AppTheme.success : AppTheme.error,
                      size: 20,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
        if (_usernameError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _usernameError!,
              style: TextStyle(color: AppTheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildConfirmButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: _usernameValid && !_isLoading
            ? LinearGradient(colors: AppTheme.primaryGradient)
            : null,
        color: _usernameValid && !_isLoading ? null : AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _usernameValid && !_isLoading
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
          onTap: _usernameValid && !_isLoading ? _handleConfirm : null,
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
                    'Complete Sign Up',
                    style: TextStyle(
                      color: _usernameValid
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
