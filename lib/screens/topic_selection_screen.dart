import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/theme.dart';
import '../utils/app_localizations.dart';
import '../services/premium_service.dart';

class TopicSelectionScreen extends StatefulWidget {
  final Function(String selectedTopic) onTopicSelected;

  const TopicSelectionScreen({required this.onTopicSelected, super.key});

  @override
  State<TopicSelectionScreen> createState() => _TopicSelectionScreenState();
}

class _TopicSelectionScreenState extends State<TopicSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _selectedLevel;
  String? _selectedSubject;
  bool _isPremium = false;
  bool _isLoadingPremiumStatus = true;

  final Map<String, List<String>> satTopics = {
    'English': [
      'Information and Ideas',
      'Craft and Structure',
      'Expression of Ideas',
      'Standard English Conventions',
    ],
  };

  final List<String> gceTopics = [
    'Mathematics',
    'English Language',
    'English Literature',
    'Physics',
    'Chemistry',
    'Biology',
    'History',
    'Geography',
    'Economics',
    'Accounting',
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();

    _loadPremiumStatus();
  }

  Future<void> _loadPremiumStatus() async {
    try {
      final premiumService = PremiumService.instance;
      await premiumService.init();
      final isPrem = await premiumService.isPremium();
      if (mounted) {
        setState(() {
          _isPremium = isPrem;
          _isLoadingPremiumStatus = false;
        });
      }
    } catch (e) {
      print('[TopicSelectionScreen] Error loading premium status: $e');
      if (mounted) {
        setState(() {
          _isLoadingPremiumStatus = false;
          _isPremium = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Widget _buildTopBar(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceCardFromContext(context),
            AppTheme.backgroundGradientEndFromContext(context),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primaryBlue.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_selectedLevel != null)
            GestureDetector(
              onTap: () => setState(() {
                _selectedSubject = null;
                if (_selectedLevel != null && _selectedLevel != 'GCE') {
                  _selectedLevel = null;
                }
              }),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
          if (_selectedLevel != null) const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: AppTheme.textPrimaryFromContext(context),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicCard(
    String title, {
    String? subtitle,
    required VoidCallback onTap,
    bool showArrow = false,
    bool isLocked = false,
  }) {
    return GestureDetector(
      onTap: isLocked ? _showPremiumUpgradeDialog : onTap,
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: _slideAnimation.value * 20,
            child: FadeTransition(opacity: _fadeAnimation, child: child),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.surfaceCardFromContext(
                  context,
                ).withOpacity(isLocked ? 0.5 : 1),
                AppTheme.surfaceCardFromContext(
                  context,
                ).withOpacity(isLocked ? 0.3 : 0.6),
              ],
            ),
            border: Border.all(
              color: isLocked
                  ? Colors.grey.withOpacity(0.3)
                  : AppTheme.primaryBlue.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryBlue.withOpacity(isLocked ? 0.15 : 0.3),
                        AppTheme.accentBlue.withOpacity(isLocked ? 0.1 : 0.2),
                      ],
                    ),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(
                        isLocked ? 0.15 : 0.3,
                      ),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        _getIconForTopic(title),
                        color: AppTheme.primaryBlue.withOpacity(
                          isLocked ? 0.5 : 1,
                        ),
                        size: 24,
                      ),
                      if (isLocked)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.shade600,
                              border: Border.all(
                                color: Colors.red.shade900,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.lock,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: AppTheme.textPrimaryFromContext(
                                  context,
                                ).withOpacity(isLocked ? 0.6 : 1),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          if (isLocked) ...[const SizedBox(width: 8)],
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: AppTheme.textSecondaryFromContext(
                              context,
                            ).withOpacity(isLocked ? 0.5 : 1),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showArrow && !isLocked) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppTheme.primaryBlue,
                  ),
                ],
                if (isLocked)
                  Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: Colors.red.shade600,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForTopic(String topic) {
    if (topic.contains('Mathematics')) return Icons.calculate;
    if (topic.contains('English')) return Icons.school;
    if (topic.contains('Literature')) return Icons.menu_book;
    if (topic.contains('Physics')) return Icons.science;
    if (topic.contains('Chemistry')) return Icons.analytics;
    if (topic.contains('Biology')) return Icons.biotech;
    if (topic.contains('History')) return Icons.history;
    if (topic.contains('Geography')) return Icons.public;
    if (topic.contains('Economics')) return Icons.trending_up;
    if (topic.contains('Accounting')) return Icons.account_balance;
    if (topic == 'Maths') return Icons.calculate;
    if (topic == 'English') return Icons.language;
    if (topic.contains('Algebra')) return Icons.functions;
    if (topic.contains('Geometry')) return Icons.crop_3_2;
    if (topic.contains('Trigonometry')) return Icons.timeline;
    if (topic.contains('Probability')) return Icons.bar_chart;
    if (topic.contains('Exponential')) return Icons.show_chart;
    if (topic.contains('Grammar')) return Icons.spellcheck;
    if (topic.contains('Vocabulary')) return Icons.description;
    if (topic.contains('Reading')) return Icons.menu_book;
    if (topic.contains('Author')) return Icons.edit;
    return Icons.topic;
  }

  void _showPremiumUpgradeDialog() {
    final localize = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1a1a2e)
            : Colors.white,
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2196F3).withOpacity(0.2),
                      const Color(0xFF1976D2).withOpacity(0.2),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFF2196F3),
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                localize.t('premium.unlockExamBoards'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                localize.t('premium.accessAllExamBoardsDesc'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black54,
                ),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _launchUrl('https://nexasmartai.org/premium');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    localize.t('premium.upgradeNow'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  localize.t('common.cancel'),
                  style: const TextStyle(
                    color: Color(0xFF2196F3),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('[TopicSelectionScreen] Error launching URL: $e');
    }
  }

  Widget _buildLevelSelection() {
    final localize = AppLocalizations.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              localize.t('topicSelection.selectExamBoard'),
              style: TextStyle(
                color: AppTheme.textSecondaryFromContext(context),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            _buildTopicCard(
              'SAT',
              subtitle: localize.t('topicSelection.satDescription'),
              showArrow: true,
              isLocked: !_isPremium,
              onTap: () => setState(() => _selectedLevel = 'SAT'),
            ),
            const SizedBox(height: 12),
            _buildTopicCard(
              'GCE A-Levels',
              subtitle: localize.t('topicSelection.gceDescription'),
              showArrow: true,
              isLocked: !_isPremium,
              onTap: () => setState(() => _selectedLevel = 'GCE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectSelection() {
    if (_selectedLevel == 'SAT') {
      final localize = AppLocalizations.of(context);
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text(
                localize.t('topicSelection.selectSatSubject'),
                style: TextStyle(
                  color: AppTheme.textSecondaryFromContext(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              _buildTopicCard(
                'English',
                subtitle: localize.t('topicSelection.englishDescription'),
                showArrow: true,
                onTap: () => setState(() => _selectedSubject = 'English'),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox.shrink();
  }

  Widget _buildTopicsDisplay() {
    if (_selectedLevel == 'GCE') {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              ...gceTopics.map((topic) {
                return Column(
                  children: [
                    _buildTopicCard(
                      topic,
                      onTap: () {
                        widget.onTopicSelected(topic);
                        Navigator.of(context).pop(topic);
                      },
                    ),
                    if (topic != gceTopics.last) const SizedBox(height: 8),
                  ],
                );
              }).toList(),
            ],
          ),
        ),
      );
    } else if (_selectedLevel == 'SAT' && _selectedSubject != null) {
      final topics = satTopics[_selectedSubject]!;
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              ...topics.map((topic) {
                final fullTopic = '$_selectedSubject - $topic';
                return Column(
                  children: [
                    _buildTopicCard(
                      topic,
                      onTap: () {
                        widget.onTopicSelected(fullTopic);
                        Navigator.of(context).pop(fullTopic);
                      },
                    ),
                    if (topic != topics.last) const SizedBox(height: 8),
                  ],
                );
              }).toList(),
            ],
          ),
        ),
      );
    }
    return SizedBox.shrink();
  }

  String _getScreenTitle() {
    final localize = AppLocalizations.of(context);
    if (_selectedLevel == null) {
      return localize.t('topicSelection.chooseExamBoard');
    } else if (_selectedLevel == 'SAT' && _selectedSubject == null) {
      return localize.t('topicSelection.chooseSatSubject');
    } else if (_selectedLevel == 'GCE') {
      return localize.t('topicSelection.selectGceTopic');
    } else if (_selectedLevel == 'SAT' && _selectedSubject != null) {
      return localize.t('topicSelection.selectSatTopic');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGradientStartFromContext(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCardFromContext(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.primaryBlue.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: AppTheme.primaryBlue,
            ),
          ),
        ),
        title: Text(
          AppLocalizations.of(context).t('topicSelection.title'),
          style: TextStyle(
            color: AppTheme.textPrimaryFromContext(context),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildTopBar(_getScreenTitle()),
            if (_selectedLevel == null)
              _buildLevelSelection()
            else if (_selectedLevel == 'SAT' && _selectedSubject == null)
              _buildSubjectSelection()
            else
              _buildTopicsDisplay(),
          ],
        ),
      ),
    );
  }
}
