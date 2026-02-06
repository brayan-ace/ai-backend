import 'package:flutter/material.dart';
import '../utils/globals.dart';
import '../utils/theme.dart';
import '../utils/app_localizations.dart';
import 'bot_processing_screen.dart';
import 'recent_study_bots_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BotCreationScreen extends StatefulWidget {
  const BotCreationScreen({super.key});

  @override
  State<BotCreationScreen> createState() => _BotCreationScreenState();
}

// Premium color palette
class PremiumColors {
  static const Color darkBg = Color(0xFF0a0a0a); // Pure black
  static const Color darkBg2 = Color(0xFF1a1a2e); // Deep blue-black
  static const Color accentGradient1 = Color(0xFF2196F3); // Blue
  static const Color accentGradient2 = Color(0xFF1976D2); // Darker blue
  static const Color accentGradient3 = Color(0xFF3b82f6); // Blue
  static const Color cardBg = Color(0xFF111827); // Very dark gray
  static const Color focusBorder = Color(0xFF4f46e5); // Focus blue
  static const Color successGreen = Color(0xFF10b981); // Success green
}

class _BotCreationScreenState extends State<BotCreationScreen>
    with TickerProviderStateMixin {
  final _planNameCtrl = TextEditingController();
  final _planDescriptionCtrl = TextEditingController();
  final _botNameCtrl = TextEditingController();
  String _selectedLevel = 'Self-Learner / Other';
  bool _isProcessing = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const List<String> educationLevels = [
    'Primary',
    'Junior Secondary',
    'Senior Secondary',
    'University',
    'Self-Learner / Other',
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _planNameCtrl.dispose();
    _planDescriptionCtrl.dispose();
    _botNameCtrl.dispose();
    super.dispose();
  }

  // Validate plan description word count
  int _getWordCount(String text) {
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  // Premium loading state with smooth animations
  void _showLoadingState() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.surfaceCardFromContext(context),
                AppTheme.backgroundGradientEndFromContext(context),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.primaryBlue.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.2),
                blurRadius: 24,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Premium loading spinner
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [AppTheme.accentBlue, AppTheme.primaryBlue],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.backgroundGradientStartFromContext(
                            context,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [AppTheme.primaryBlue, AppTheme.accentBlue],
                ).createShader(bounds),
                child: Text(
                  AppLocalizations.of(
                    context,
                  ).t('botCreation.craftingBotTitle'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(
                  context,
                ).t('botCreation.analyzeGoalsMessage'),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.6),
                  letterSpacing: 0.3,
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
    print('[BotCreationScreen] Handler entry point reached');

    final planName = _planNameCtrl.text.trim();
    final planDescription = _planDescriptionCtrl.text.trim();

    try {
      print(
        '[BotCreationScreen] _handleStudyBotCreation called with botName=$botName, educationLevel=$educationLevel',
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
        '[BotCreationScreen] Navigating to BotProcessingScreen with userId=$userId, botName=$botName',
      );

      // Navigate to processing screen
      print('[BotCreationScreen] Checking if mounted: $mounted');
      if (!mounted) {
        print('[BotCreationScreen] Widget not mounted, returning');
        return;
      }

      print(
        '[BotCreationScreen] About to call Navigator.of(context).pushReplacement',
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

      print('[BotCreationScreen] Navigation initiated');

      // Clear form for next use
      _planNameCtrl.clear();
      _planDescriptionCtrl.clear();
      _botNameCtrl.clear();
    } catch (e) {
      print('[BotCreationScreen] Error in _handleStudyBotCreation: $e');
      print('[BotCreationScreen] Stack trace: ${StackTrace.current}');
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
    print('[BotCreationScreen] _handleCreateStudyBot entry');
    final planName = _planNameCtrl.text.trim();
    final planDescription = _planDescriptionCtrl.text.trim();
    final botName = _botNameCtrl.text.trim();

    // Validate plan name
    if (planName.isEmpty) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        _buildPremiumSnackBar(
          AppLocalizations.of(context).t('botCreation.errorTopicRequired'),
        ),
      );
      return;
    }

    // Validate plan description
    if (planDescription.isEmpty) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        _buildPremiumSnackBar(
          AppLocalizations.of(context).t('botCreation.errorGoalsRequired'),
        ),
      );
      return;
    }

    // Validate description word count (max 100 words)
    final wordCount = _getWordCount(planDescription);
    if (wordCount > 100) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        _buildPremiumSnackBar(
          '${AppLocalizations.of(context).t('botCreation.errorWordLimit')} ($wordCount used)',
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    // Validate bot name
    if (botName.isEmpty) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        _buildPremiumSnackBar(
          AppLocalizations.of(context).t('botCreation.errorNameRequired'),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Show loading state
      print('[BotCreationScreen] Showing loading dialog');
      _showLoadingState();

      // Simulate analysis/preparation
      await Future.delayed(const Duration(milliseconds: 1200));

      if (!mounted) {
        print('[BotCreationScreen] Not mounted after delay');
        return;
      }

      // Close loading dialog
      try {
        print('[BotCreationScreen] Closing loading dialog');
        Navigator.of(context).pop();
      } catch (popErr) {
        print('[BotCreationScreen] Error closing dialog: $popErr');
      }

      print('[BotCreationScreen] Calling _handleStudyBotCreation');
      await _handleStudyBotCreation(botName, _selectedLevel);
    } catch (e, st) {
      print('[BotCreationScreen] Error in _handleCreateStudyBot: $e');
      print(st);
      scaffoldMessengerKey.currentState?.showSnackBar(
        _buildPremiumSnackBar(
          '${AppLocalizations.of(context).t('botCreation.errorGeneric')}: $e',
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // Build premium SnackBar
  SnackBar _buildPremiumSnackBar(
    String message, {
    Color backgroundColor = const Color(0xFF4f46e5),
  }) {
    return SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    );
  }

  // Get localized education levels
  // Get localized label for education level
  String _getLocalizedLevelLabel(String level) {
    final map = {
      'Primary': () =>
          AppLocalizations.of(context).t('botCreation.educationLevelPrimary'),
      'Junior Secondary': () =>
          AppLocalizations.of(context).t('botCreation.educationLevelJunior'),
      'Senior Secondary': () =>
          AppLocalizations.of(context).t('botCreation.educationLevelSenior'),
      'University': () => AppLocalizations.of(
        context,
      ).t('botCreation.educationLevelUniversity'),
      'Self-Learner / Other': () =>
          AppLocalizations.of(context).t('botCreation.educationLevelOther'),
    };
    return map[level]?.call() ?? level;
  }

  // Build premium text field
  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    VoidCallback? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceCardFromContext(context),
            AppTheme.surfaceCardFromContext(context).withOpacity(0.6),
          ],
        ),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        onChanged: (_) => onChanged?.call(),
        style: TextStyle(
          color: AppTheme.textPrimaryFromContext(context),
          fontSize: 15,
          letterSpacing: 0.2,
        ),
        cursorColor: AppTheme.primaryBlue,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: AppTheme.textSecondaryFromContext(context),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
          prefixIcon: Icon(icon, color: AppTheme.primaryBlue, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppTheme.primaryBlue.withOpacity(0.15),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = _getWordCount(_planDescriptionCtrl.text);
    final wordPercentage = (wordCount / 100).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppTheme.backgroundGradientStartFromContext(context),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [AppTheme.primaryBlue, AppTheme.accentBlue],
          ).createShader(bounds),
          child: Text(
            AppLocalizations.of(context).t('botCreation.pageTitle'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue.withOpacity(0.2),
                    AppTheme.accentBlue.withOpacity(0.2),
                  ],
                ),
              ),
              child: Icon(Icons.history, color: AppTheme.primaryBlue, size: 18),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RecentStudyBotsScreen(),
                ),
              );
            },
            tooltip: AppLocalizations.of(
              context,
            ).t('botCreation.recentBotsTooltip'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.backgroundGradientStartFromContext(context),
                  AppTheme.backgroundGradientEndFromContext(context),
                ],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 100,
                bottom: 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Premium hero text
                  Container(
                    margin: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(
                            context,
                          ).t('botCreation.personalizedLearning'),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimaryFromContext(context),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).t('botCreation.designMentorSubtitle'),
                          style: TextStyle(
                            fontSize: 15,
                            color: AppTheme.textSecondaryFromContext(context),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Input Section 1: Study Topic
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 20,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primaryBlue,
                                      AppTheme.accentBlue,
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                AppLocalizations.of(
                                  context,
                                ).t('botCreation.whatWillStudy'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimaryFromContext(
                                    context,
                                  ),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildPremiumTextField(
                          controller: _planNameCtrl,
                          label: AppLocalizations.of(
                            context,
                          ).t('botCreation.studyTopicLabel'),
                          icon: Icons.book_rounded,
                        ),
                      ],
                    ),
                  ),

                  // Input Section 2: Learning Goals
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 20,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: LinearGradient(
                                    colors: [
                                      PremiumColors.accentGradient2,
                                      PremiumColors.accentGradient3,
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                AppLocalizations.of(
                                  context,
                                ).t('botCreation.yourLearningGoals'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimaryFromContext(
                                    context,
                                  ),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildPremiumTextField(
                          controller: _planDescriptionCtrl,
                          label: AppLocalizations.of(
                            context,
                          ).t('botCreation.masterLabel'),
                          icon: Icons.lightbulb_rounded,
                          maxLines: 4,
                          onChanged: () => setState(() {}),
                        ),
                      ],
                    ),
                  ),

                  // Word count indicator with animation
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          PremiumColors.cardBg,
                          PremiumColors.cardBg.withOpacity(0.5),
                        ],
                      ),
                      border: Border.all(
                        color: wordPercentage > 0.9
                            ? Colors.orange.withOpacity(0.3)
                            : PremiumColors.accentGradient1.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppLocalizations.of(
                                context,
                              ).t('botCreation.wordCount'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.7),
                                letterSpacing: 0.2,
                              ),
                            ),
                            Text(
                              '$wordCount ${AppLocalizations.of(context).t('botCreation.maxWords')} 100',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: wordPercentage > 0.9
                                    ? Colors.orange
                                    : PremiumColors.accentGradient1,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: wordPercentage,
                            minHeight: 6,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              wordPercentage > 0.9
                                  ? Colors.orange
                                  : PremiumColors.accentGradient1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Input Section 3: Bot Name
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 20,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: LinearGradient(
                                    colors: [
                                      PremiumColors.accentGradient3,
                                      PremiumColors.accentGradient1,
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                AppLocalizations.of(
                                  context,
                                ).t('botCreation.nameMentor'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimaryFromContext(
                                    context,
                                  ),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildPremiumTextField(
                          controller: _botNameCtrl,
                          label: AppLocalizations.of(
                            context,
                          ).t('botCreation.botNameLabel'),
                          icon: Icons.psychology_rounded,
                        ),
                      ],
                    ),
                  ),

                  // Input Section 4: Education Level
                  Container(
                    margin: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 20,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: LinearGradient(
                                    colors: [
                                      PremiumColors.accentGradient1,
                                      PremiumColors.accentGradient2,
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                AppLocalizations.of(
                                  context,
                                ).t('botCreation.yourLevel'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                PremiumColors.cardBg,
                                PremiumColors.cardBg.withOpacity(0.6),
                              ],
                            ),
                            border: Border.all(
                              color: PremiumColors.accentGradient1.withOpacity(
                                0.2,
                              ),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedLevel,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              border: InputBorder.none,
                              prefixIcon: Icon(
                                Icons.school_rounded,
                                color: PremiumColors.accentGradient1,
                                size: 22,
                              ),
                              suffixIcon: Icon(
                                Icons.expand_more,
                                color: PremiumColors.accentGradient1
                                    .withOpacity(0.6),
                              ),
                            ),
                            dropdownColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? PremiumColors.cardBg
                                : Colors.white,
                            style: TextStyle(
                              fontSize: 15,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                              letterSpacing: 0.2,
                            ),
                            items: educationLevels
                                .map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      _getLocalizedLevelLabel(value),
                                      style: TextStyle(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  );
                                })
                                .toList(),
                            onChanged: _isProcessing
                                ? null
                                : (String? newValue) {
                                    setState(() {
                                      _selectedLevel = newValue!;
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Premium CTA Button
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          PremiumColors.accentGradient1,
                          PremiumColors.accentGradient2,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: PremiumColors.accentGradient1.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isProcessing ? null : _handleCreateStudyBot,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isProcessing)
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              const SizedBox(width: 12),
                              Text(
                                _isProcessing
                                    ? AppLocalizations.of(
                                        context,
                                      ).t('botCreation.creatingBotButton')
                                    : AppLocalizations.of(
                                        context,
                                      ).t('botCreation.createBotButton'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Feature highlights section
                  Container(
                    margin: const EdgeInsets.only(top: 40),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          PremiumColors.darkBg2.withOpacity(0.5),
                          PremiumColors.cardBg.withOpacity(0.3),
                        ],
                      ),
                      border: Border.all(
                        color: PremiumColors.accentGradient1.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildFeatureRow(
                          '🧠',
                          AppLocalizations.of(
                            context,
                          ).t('botCreation.adaptiveLearning'),
                          AppLocalizations.of(
                            context,
                          ).t('botCreation.learnsPaceStyle'),
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureRow(
                          '⚡',
                          AppLocalizations.of(
                            context,
                          ).t('botCreation.instantInsights'),
                          AppLocalizations.of(
                            context,
                          ).t('botCreation.getSolutionsSeconds'),
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureRow(
                          '📈',
                          AppLocalizations.of(
                            context,
                          ).t('botCreation.progressTracking'),
                          AppLocalizations.of(
                            context,
                          ).t('botCreation.monitorGrowth'),
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

  // Build feature row widget
  Widget _buildFeatureRow(String emoji, String title, String subtitle) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
