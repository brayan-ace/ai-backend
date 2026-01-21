import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/theme.dart';
import '../services/user_profile_service.dart';
import '../services/auth_services.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final UserProfileService _userProfileService = UserProfileService.instance;
  final AuthService _authService = AuthService();
  
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isEditingUsername = false;
  bool _isEditingEmail = false;
  bool _isLoading = false;
  bool _showPasswordFields = false;
  
  String? _originalUsername;
  String? _originalEmail;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    await _userProfileService.init();
    
    final user = FirebaseAuth.instance.currentUser;
    final username = await _userProfileService.getDisplayName();
    
    setState(() {
      _usernameController.text = username;
      _emailController.text = user?.email ?? '';
      _originalUsername = username;
      _originalEmail = user?.email;
    });
  }

  Future<void> _saveUsername() async {
    if (_usernameController.text.trim().isEmpty) {
      _showError('Username cannot be empty');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _userProfileService.saveUsername(_usernameController.text.trim());
      
      if (success) {
        setState(() {
          _isEditingUsername = false;
          _originalUsername = _usernameController.text.trim();
        });
        _showSuccess('Username updated successfully');
      } else {
        _showError('Failed to update username');
      }
    } catch (e) {
      _showError('Error updating username: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveEmail() async {
    final newEmail = _emailController.text.trim();
    
    if (newEmail.isEmpty) {
      _showError('Email cannot be empty');
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(newEmail)) {
      _showError('Please enter a valid email address');
      return;
    }

    if (_passwordController.text.isEmpty) {
      setState(() => _showPasswordFields = true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('No user logged in');
        return;
      }

      // Create credential with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _passwordController.text,
      );

      // Reauthenticate user
      await user.reauthenticateWithCredential(credential);

      // Update email
      await user.updateEmail(newEmail);
      
      // Send verification email
      await user.sendEmailVerification();

      setState(() {
        _isEditingEmail = false;
        _showPasswordFields = false;
        _originalEmail = newEmail;
        _passwordController.clear();
      });

      _showSuccess('Email updated. Please check your inbox for verification.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        _showError('Current password is incorrect');
      } else if (e.code == 'email-already-in-use') {
        _showError('This email is already in use');
      } else {
        _showError('Error updating email: ${e.message}');
      }
    } catch (e) {
      _showError('Error updating email: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _cancelUsernameEdit() {
    setState(() {
      _usernameController.text = _originalUsername ?? '';
      _isEditingUsername = false;
    });
  }

  void _cancelEmailEdit() {
    setState(() {
      _emailController.text = _originalEmail ?? '';
      _isEditingEmail = false;
      _showPasswordFields = false;
      _passwordController.clear();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSectionHeader(String text) => Padding(
    padding: EdgeInsets.fromLTRB(
      AppTheme.spaceMd,
      AppTheme.spaceLg,
      AppTheme.spaceMd,
      AppTheme.spaceSm,
    ),
    child: Text(
      text.toUpperCase(),
      style: AppTheme.labelMedium.copyWith(
        color: AppTheme.textTertiary,
        letterSpacing: 1.5,
      ),
    ),
  );

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppTheme.spaceSm),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppTheme.surfaceGradient),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.surfaceElevated.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: AppTheme.glassGradient),
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.surfaceElevated.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
            ),
          ),
          title: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: AppTheme.primaryGradient,
            ).createShader(bounds),
            child: Text(
              'Profile',
              style: AppTheme.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.only(bottom: AppTheme.spaceLg),
            children: [
              // Profile Header
              Padding(
                padding: EdgeInsets.all(AppTheme.spaceMd),
                child: Container(
                  padding: EdgeInsets.all(AppTheme.spaceLg),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppTheme.primaryGradient,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: AppTheme.glowShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          color: Colors.black,
                          size: 40,
                        ),
                      ),
                      SizedBox(width: AppTheme.spaceLg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profile Settings',
                              style: AppTheme.headlineMedium.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: AppTheme.spaceXs),
                            Text(
                              'Manage your account information',
                              style: AppTheme.bodyMedium.copyWith(
                                color: Colors.black.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Username Section
              _buildSectionHeader('Username'),
              _buildCard(
                children: [
                  Padding(
                    padding: EdgeInsets.all(AppTheme.spaceMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Username',
                          style: AppTheme.labelLarge.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        SizedBox(height: AppTheme.spaceSm),
                        Text(
                          'Used to greet you throughout the app',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        SizedBox(height: AppTheme.spaceMd),
                        if (_isEditingUsername) ...[
                          TextField(
                            controller: _usernameController,
                            style: AppTheme.bodyLarge.copyWith(
                              color: AppTheme.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter username',
                              hintStyle: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textTertiary,
                              ),
                              filled: true,
                              fillColor: AppTheme.surfaceElevated.withOpacity(0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          SizedBox(height: AppTheme.spaceMd),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _saveUsername,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryBlue,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black,
                                          ),
                                        )
                                      : Text('Save'),
                                ),
                              ),
                              SizedBox(width: AppTheme.spaceSm),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _cancelUsernameEdit,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: AppTheme.textTertiary),
                                  ),
                                  child: Text('Cancel'),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _usernameController.text,
                                  style: AppTheme.bodyLarge.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => setState(() => _isEditingUsername = true),
                                icon: Icon(Icons.edit, color: AppTheme.primaryBlue),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // Email Section
              _buildSectionHeader('Email'),
              _buildCard(
                children: [
                  Padding(
                    padding: EdgeInsets.all(AppTheme.spaceMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email Address',
                          style: AppTheme.labelLarge.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        SizedBox(height: AppTheme.spaceSm),
                        Text(
                          'Email changes require re-authentication',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        SizedBox(height: AppTheme.spaceMd),
                        if (_isEditingEmail) ...[
                          TextField(
                            controller: _emailController,
                            style: AppTheme.bodyLarge.copyWith(
                              color: AppTheme.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter new email',
                              hintStyle: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textTertiary,
                              ),
                              filled: true,
                              fillColor: AppTheme.surfaceElevated.withOpacity(0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          if (_showPasswordFields) ...[
                            SizedBox(height: AppTheme.spaceMd),
                            Text(
                              'Current Password',
                              style: AppTheme.labelLarge.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            SizedBox(height: AppTheme.spaceSm),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter current password',
                                hintStyle: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.textTertiary,
                                ),
                                filled: true,
                                fillColor: AppTheme.surfaceElevated.withOpacity(0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: AppTheme.spaceMd),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _saveEmail,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryBlue,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black,
                                          ),
                                        )
                                      : Text('Save'),
                                ),
                              ),
                              SizedBox(width: AppTheme.spaceSm),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _cancelEmailEdit,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: AppTheme.textTertiary),
                                  ),
                                  child: Text('Cancel'),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _emailController.text,
                                  style: AppTheme.bodyLarge.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => setState(() => _isEditingEmail = true),
                                icon: Icon(Icons.edit, color: AppTheme.primaryBlue),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: AppTheme.spaceLg),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
