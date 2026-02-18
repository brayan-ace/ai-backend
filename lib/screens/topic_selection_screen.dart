import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../utils/app_localizations.dart';

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
  }) {
    return GestureDetector(
      onTap: onTap,
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
                AppTheme.surfaceCardFromContext(context),
                AppTheme.surfaceCardFromContext(context).withOpacity(0.6),
              ],
            ),
            border: Border.all(
              color: AppTheme.primaryBlue.withOpacity(0.15),
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
                        AppTheme.primaryBlue.withOpacity(0.3),
                        AppTheme.accentBlue.withOpacity(0.2),
                      ],
                    ),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    _getIconForTopic(title),
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppTheme.textPrimaryFromContext(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: AppTheme.textSecondaryFromContext(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showArrow) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppTheme.primaryBlue,
                  ),
                ],
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
              onTap: () => setState(() => _selectedLevel = 'SAT'),
            ),
            const SizedBox(height: 12),
            _buildTopicCard(
              'GCE A-Levels',
              subtitle: localize.t('topicSelection.gceDescription'),
              showArrow: true,
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
