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

                // Study Plan Name Input
                Text(
                  'Study Plan Name',
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: AppTheme.spaceSm),
                TextField(
                  controller: _planNameCtrl,
                  enabled: !_isProcessing,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g., Superb Nutrition, Biology Revision Bot',
                    filled: true,
                    fillColor: AppTheme.primaryBlue.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide(
                        color: AppTheme.primaryBlue.withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide(
                        color: AppTheme.primaryBlue.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide(
                        color: AppTheme.primaryBlue,
                        width: 2,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.subject,
                      color: AppTheme.textSecondary,
                    ),
                    contentPadding: EdgeInsets.all(AppTheme.spaceMd),
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Study Plan Description Input
                Text(
                  'Study Plan Description',
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: AppTheme.spaceSm),
                TextField(
                  controller: _planDescriptionCtrl,
                  enabled: !_isProcessing,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 5,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText:
                        'Describe what you want to study and how you want to learn (Max 100 words)',
                    hintMaxLines: 2,
                    filled: true,
                    fillColor: AppTheme.primaryBlue.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide(
                        color: AppTheme.primaryBlue.withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide(
                        color: AppTheme.primaryBlue.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide(
                        color: AppTheme.primaryBlue,
                        width: 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.all(AppTheme.spaceMd),
                  ),
                  onChanged: (text) {
                    setState(() {}); // Update word count display
                  },
                ),
                SizedBox(height: AppTheme.spaceSm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Describe your learning goals',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${_getWordCount(_planDescriptionCtrl.text)}/100',
                      style: AppTheme.labelSmall.copyWith(
                        color: _getWordCount(_planDescriptionCtrl.text) > 100
                            ? Colors.red
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Study Bot Name Input
                Text(
                  'Study Bot Name',
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: AppTheme.spaceSm),
                TextField(
                  controller: _botNameCtrl,
                  enabled: !_isProcessing,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g., James, Dr. Nutri, Coach Ali',
                    filled: true,
                    fillColor: AppTheme.primaryBlue.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide(
                        color: AppTheme.primaryBlue.withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide(
                        color: AppTheme.primaryBlue.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide(
                        color: AppTheme.primaryBlue,
                        width: 2,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.person,
                      color: AppTheme.textSecondary,
                    ),
                    contentPadding: EdgeInsets.all(AppTheme.spaceMd),
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Education Level Dropdown
                Text(
                  'Education / Grade Level',
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: AppTheme.spaceSm),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedLevel,
                    underline: const SizedBox(),
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMd,
                      vertical: AppTheme.spaceSm,
                    ),
                    items: educationLevels.map((level) {
                      return DropdownMenuItem(
                        value: level,
                        child: Text(
                          level,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textPrimary,
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
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Create Study Bot Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isProcessing ? null : _handleCreateStudyBot,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    child: _isProcessing
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ),
                              SizedBox(width: AppTheme.spaceSm),
                              Text(
                                'Preparing...',
                                style: AppTheme.labelMedium.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'Create Study Bot',
                            style: AppTheme.labelMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Info Box
                Container(
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💡 What is a Study Bot?',
                        style: AppTheme.labelMedium.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: AppTheme.spaceSm),
                      Text(
                        'A Study Bot is your personal AI tutor, customized to your subject and learning level. '
                        'In Phase 1, you\'re setting up its identity and expertise. '
                        'Future phases will add teaching, quizzes, and progress tracking.',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
