import 'package:flutter/material.dart';
import '../utils/globals.dart';
import '../utils/theme.dart';
import 'bot_processing_screen.dart';
import 'recent_study_bots_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({super.key});

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  final _planNameCtrl = TextEditingController();
  final _planDescriptionCtrl = TextEditingController();
  final _botNameCtrl = TextEditingController();
  String _selectedLevel = 'Self-Learner / Other';
  bool _isProcessing = false;

  static const List<String> educationLevels = [
    'Primary',
    'Junior Secondary',
    'Senior Secondary',
    'University',
    'Self-Learner / Other',
  ];

  @override
  void dispose() {
    _planNameCtrl.dispose();
    _planDescriptionCtrl.dispose();
    _botNameCtrl.dispose();
    super.dispose();
  }

  // Validate plan description word count
  int _getWordCount(String text) {
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  // Show loading state during bot identity collection
  void _showLoadingState() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(AppTheme.spaceLg),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryBlue,
                  ),
                ),
              ),
              SizedBox(height: AppTheme.spaceMd),
              Text(
                'Preparing your Study Bot...',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Handle Study Bot creation
  Future<void> _handleStudyBotCreation(
    String botName,
    String educationLevel,
  ) async {
    print('[StudyPlanScreen] Handler entry point reached');

    final planName = _planNameCtrl.text.trim();
    final planDescription = _planDescriptionCtrl.text.trim();

    try {
      print(
        '[StudyPlanScreen] _handleStudyBotCreation called with botName=$botName, educationLevel=$educationLevel',
      );

      // Determine user ID (use FirebaseAuth if available)
      String userId = 'local_user';
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null && uid.isNotEmpty) userId = uid;
      } catch (_) {
        // ignore and keep fallback
      }

      // Use planName as topic fallback
      final topic = planName;

      print(
        '[StudyPlanScreen] Navigating to BotProcessingScreen with userId=$userId, botName=$botName',
      );

      // Navigate to processing screen
      print('[StudyPlanScreen] Checking if mounted: $mounted');
      if (!mounted) {
        print('[StudyPlanScreen] Widget not mounted, returning');
        return;
      }

      print(
        '[StudyPlanScreen] About to call Navigator.of(context).pushReplacement',
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BotProcessingScreen(
            name: botName,
            description: planDescription,
            topic: topic,
            gradeLevel: educationLevel,
            userId: userId,
          ),
        ),
      );

      print('[StudyPlanScreen] Navigation initiated');

      // Clear form for next use
      _planNameCtrl.clear();
      _planDescriptionCtrl.clear();
      _botNameCtrl.clear();
    } catch (e) {
      print('[StudyPlanScreen] Error in _handleStudyBotCreation: $e');
      print('[StudyPlanScreen] Stack trace: ${StackTrace.current}');
      if (!mounted) return;
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Error creating Study Bot: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Handle Create Study Bot button tap - validate all fields and navigate
  Future<void> _handleCreateStudyBot() async {
    print('[StudyPlanScreen] _handleCreateStudyBot entry');
    final planName = _planNameCtrl.text.trim();
    final planDescription = _planDescriptionCtrl.text.trim();
    final botName = _botNameCtrl.text.trim();

    // Validate plan name
    if (planName.isEmpty) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Please enter a Study Plan name'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validate plan description
    if (planDescription.isEmpty) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Please enter a Study Plan description'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validate description word count (max 100 words)
    final wordCount = _getWordCount(planDescription);
    if (wordCount > 100) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            'Description must be 100 words or less. Currently: $wordCount words',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Validate bot name
    if (botName.isEmpty) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Please enter a name for your Study Bot'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Show loading state
      print('[StudyPlanScreen] Showing loading dialog');
      _showLoadingState();

      // Simulate analysis/preparation
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) {
        print('[StudyPlanScreen] Not mounted after delay');
        return;
      }

      // Close loading dialog
      try {
        print('[StudyPlanScreen] Closing loading dialog');
        Navigator.of(context).pop();
      } catch (popErr) {
        print('[StudyPlanScreen] Error closing dialog: $popErr');
      }

      print('[StudyPlanScreen] Calling _handleStudyBotCreation');
      await _handleStudyBotCreation(botName, _selectedLevel);
    } catch (e, st) {
      print('[StudyPlanScreen] Error in _handleCreateStudyBot: $e');
      print(st);
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ✨ PREMIUM UI BUILDER METHODS

  /// Build premium input label with emoji
  Widget _buildPremiumInputLabel(String label) {
    return Text(
      label,
      style: AppTheme.labelMedium.copyWith(
        color: AppTheme.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }

  /// Build premium text field with gradient border on focus
  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required bool enabled,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        style: AppTheme.bodyMedium.copyWith(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textSecondary.withOpacity(0.6),
          ),
          filled: true,
          fillColor: AppTheme.primaryBlue.withOpacity(0.04),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 12),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppTheme.primaryBlue.withOpacity(0.15),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppTheme.primaryBlue.withOpacity(0.15),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  /// Build premium text area for descriptions
  Widget _buildPremiumTextArea({
    required TextEditingController controller,
    required String hintText,
    required bool enabled,
    required Function(String) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        maxLines: 4,
        textAlignVertical: TextAlignVertical.top,
        style: AppTheme.bodyMedium.copyWith(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textSecondary.withOpacity(0.6),
          ),
          filled: true,
          fillColor: AppTheme.primaryBlue.withOpacity(0.04),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppTheme.primaryBlue.withOpacity(0.15),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppTheme.primaryBlue.withOpacity(0.15),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
        onChanged: onChanged,
      ),
    );
  }

  /// Build premium dropdown
  Widget _buildPremiumDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.15)),
          borderRadius: BorderRadius.circular(12),
          color: AppTheme.primaryBlue.withOpacity(0.04),
        ),
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedLevel,
          underline: const SizedBox(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          items: educationLevels.map((level) {
            return DropdownMenuItem(
              value: level,
              child: Text(
                level,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onChanged: _isProcessing
              ? null
              : (value) {
                  if (value != null) {
                    setState(() => _selectedLevel = value);
                  }
                },
          dropdownColor: AppTheme.surfaceCard,
          icon: Icon(Icons.expand_more_rounded, color: AppTheme.primaryBlue),
        ),
      ),
    );
  }

  /// Build premium create button with gradient
  Widget _buildPremiumCreateButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: _isProcessing ? null : _handleCreateStudyBot,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isProcessing
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Creating Bot...',
                    style: AppTheme.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Text(
                '✨ Create Study Bot',
                style: AppTheme.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }

  /// Build premium info box
  Widget _buildPremiumInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withOpacity(0.1),
            AppTheme.primaryBlue.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.lightbulb_rounded,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'About Your Study Bot',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your Study Bot becomes your personalized AI mentor. It learns your preferred style and adapts lessons to your pace.',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDeep,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Recent Bots Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: AppTheme.primaryGradient,
                          ).createShader(bounds),
                          child: Icon(
                            Icons.school,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        SizedBox(width: AppTheme.spaceSm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Study Bot',
                              style: AppTheme.headlineSmall.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Set up your AI study companion',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.history,
                          color: AppTheme.primaryBlue,
                          size: 24,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RecentStudyBotsScreen(),
                            ),
                          );
                        },
                        tooltip: 'View Recent Study Bots',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Header
                Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: AppTheme.primaryGradient,
                      ).createShader(bounds),
                      child: Icon(Icons.school, color: Colors.white, size: 32),
                    ),
                    SizedBox(width: AppTheme.spaceSm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Study Bot',
                          style: AppTheme.headlineSmall.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Set up your AI study companion',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Phase Indicator
                Container(
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryBlue.withOpacity(0.15),
                        AppTheme.primaryBlue.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '1',
                          style: AppTheme.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: AppTheme.spaceSm),
                      Expanded(
                        child: Text(
                          'Phase 1: Define Your Study Bot Identity',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),

                // ✨ PREMIUM FORM SECTION
                // Study Plan Name Input - Premium Style
                _buildPremiumInputLabel('📚 Study Topic'),
                SizedBox(height: AppTheme.spaceSm),
                _buildPremiumTextField(
                  controller: _planNameCtrl,
                  hintText: 'e.g., Advanced Biology, Quantum Physics',
                  icon: Icons.subject_rounded,
                  enabled: !_isProcessing,
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Study Plan Description Input - Premium Style
                _buildPremiumInputLabel('📝 Learning Goals'),
                SizedBox(height: AppTheme.spaceSm),
                _buildPremiumTextArea(
                  controller: _planDescriptionCtrl,
                  hintText: 'What do you want to master? (100 word max)',
                  enabled: !_isProcessing,
                  onChanged: (text) => setState(() {}),
                ),
                SizedBox(height: AppTheme.spaceSm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Detail your learning vision',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceSm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getWordCount(_planDescriptionCtrl.text) > 100
                            ? Colors.red.withOpacity(0.15)
                            : AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_getWordCount(_planDescriptionCtrl.text)}/100',
                        style: AppTheme.labelSmall.copyWith(
                          color: _getWordCount(_planDescriptionCtrl.text) > 100
                              ? Colors.red
                              : AppTheme.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Study Bot Name Input - Premium Style
                _buildPremiumInputLabel('🤖 Bot Name'),
                SizedBox(height: AppTheme.spaceSm),
                _buildPremiumTextField(
                  controller: _botNameCtrl,
                  hintText: 'e.g., Alex, Dr. Scholar, Coach Pro',
                  icon: Icons.person_rounded,
                  enabled: !_isProcessing,
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Education Level Dropdown - Premium Style
                _buildPremiumInputLabel('🎓 Education Level'),
                SizedBox(height: AppTheme.spaceSm),
                _buildPremiumDropdown(),
                SizedBox(height: AppTheme.spaceLg),

                // Create Study Bot Button - Premium Style with Gradient
                _buildPremiumCreateButton(),
                SizedBox(height: AppTheme.spaceLg),

                // Info Box - Premium Style
                _buildPremiumInfoBox(),
                SizedBox(height: AppTheme.spaceLg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
