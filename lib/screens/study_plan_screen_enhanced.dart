import 'package:flutter/material.dart';
import '../services/study_plan_service.dart';
import '../utils/globals.dart';
import 'study_plan_chat_screen.dart';
import '../utils/theme.dart';

class StudyPlanScreenEnhanced extends StatefulWidget {
  const StudyPlanScreenEnhanced({super.key});

  @override
  State<StudyPlanScreenEnhanced> createState() =>
      _StudyPlanScreenEnhancedState();
}

class _StudyPlanScreenEnhancedState extends State<StudyPlanScreenEnhanced>
    with SingleTickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  final _contextCtrl = TextEditingController();
  final _service = StudyPlanService();
  bool _starting = false;
  late AnimationController _animController;
  int _wordCount = 0;
  String _selectedTemplate = '';

  final Map<String, Map<String, String>> _templates = {
    'math': {
      'title': 'Mathematics Mastery',
      'context':
          'You are an expert mathematics tutor. Help me understand complex mathematical concepts through step-by-step explanations, real-world examples, and interactive problem-solving. Focus on building strong fundamentals and developing problem-solving skills.',
      'icon': '📐',
    },
    'science': {
      'title': 'Science Explorer',
      'context':
          'You are a passionate science educator. Guide me through scientific concepts with engaging explanations, experiments, and connections to real-world phenomena. Make learning interactive and curiosity-driven.',
      'icon': '🔬',
    },
    'language': {
      'title': 'Language Learning',
      'context':
          'You are a skilled language instructor. Help me master a new language through immersive conversations, grammar explanations, vocabulary building, and cultural insights. Make learning natural and engaging.',
      'icon': '🌍',
    },
    'coding': {
      'title': 'Programming Pro',
      'context':
          'You are an experienced programming mentor. Teach me coding concepts through practical examples, debugging techniques, best practices, and project-based learning. Focus on problem-solving and clean code.',
      'icon': '💻',
    },
    'history': {
      'title': 'History Journey',
      'context':
          'You are a knowledgeable history teacher. Take me through historical events with vivid storytelling, analyzing causes and effects, connecting past to present, and exploring multiple perspectives.',
      'icon': '📚',
    },
    'custom': {'title': 'Custom Study Plan', 'context': '', 'icon': '✨'},
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    _contextCtrl.addListener(_updateWordCount);
  }

  @override
  void dispose() {
    _animController.dispose();
    _titleCtrl.dispose();
    _contextCtrl.dispose();
    super.dispose();
  }

  void _updateWordCount() {
    final text = _contextCtrl.text.trim();
    final count = text.isEmpty
        ? 0
        : text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (count != _wordCount) {
      setState(() => _wordCount = count);
    }
  }

  void _applyTemplate(String key) {
    setState(() {
      _selectedTemplate = key;
      _titleCtrl.text = _templates[key]!['title']!;
      if (key != 'custom') {
        _contextCtrl.text = _templates[key]!['context']!;
      }
    });
  }

  Future<void> _startPlan() async {
    final title = _titleCtrl.text.trim();
    final context = _contextCtrl.text.trim();

    if (title.isEmpty || context.isEmpty) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Please provide both title and context'),
            ],
          ),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
        ),
      );
      return;
    }

    if (_wordCount < 20) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Context needs at least 20 words. Currently: $_wordCount words',
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
        ),
      );
      return;
    }

    setState(() => _starting = true);

    await _service.savePlan(title: title, context: context);

    if (!mounted) return;

    final plans = await _service.getPlans();
    if (plans.isNotEmpty) {
      final lastPlan = plans.last;
      final planId = lastPlan['id'] as String;

      setState(() => _starting = false);

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => StudyPlanChatScreen(
            planId: planId,
            planTitle: title,
            planContext: context,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppTheme.primaryGradient,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppTheme.glowShadow,
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Create Study Plan',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              SliverPadding(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Header Card
                    _buildHeaderCard(),
                    const SizedBox(height: AppTheme.spaceLg),

                    // Templates Grid
                    _buildTemplatesSection(),
                    const SizedBox(height: AppTheme.spaceLg),

                    // Title Input
                    _buildTitleInput(),
                    const SizedBox(height: AppTheme.spaceMd),

                    // Context Input
                    _buildContextInput(),
                    const SizedBox(height: AppTheme.spaceMd),

                    // Word Counter
                    _buildWordCounter(),
                    const SizedBox(height: AppTheme.spaceLg),

                    // Create Button
                    _buildCreateButton(),
                    const SizedBox(height: AppTheme.spaceXl),

                    // Tips Section
                    _buildTipsSection(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppTheme.surfaceGradient),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.surfaceElevated.withOpacity(0.5)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _animController.value * 2 * 3.14159,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppTheme.primaryGradient),
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.glowShadow,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            'AI-Powered Learning',
            style: AppTheme.headlineLarge.copyWith(color: AppTheme.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spaceXs),
          Text(
            'Create a personalized study plan with your AI tutor. Get instant help, practice problems, and track your progress.',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Quick Start Templates',
            style: AppTheme.headlineMedium.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: AppTheme.spaceMd,
          mainAxisSpacing: AppTheme.spaceMd,
          childAspectRatio: 1.3,
          children: _templates.entries
              .map((entry) => _buildTemplateCard(entry.key, entry.value))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(String key, Map<String, String> template) {
    final isSelected = _selectedTemplate == key;
    return GestureDetector(
      onTap: () => _applyTemplate(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: AppTheme.primaryGradient)
              : LinearGradient(colors: AppTheme.surfaceGradient),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBlue
                : AppTheme.surfaceElevated.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? AppTheme.glowShadow : AppTheme.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(template['icon']!, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              template['title']!,
              style: AppTheme.labelLarge.copyWith(
                color: isSelected ? Colors.white : AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleInput() {
    return TextFormField(
      controller: _titleCtrl,
      decoration: InputDecoration(
        labelText: 'Study Plan Title',
        hintText: 'e.g., Advanced Calculus, Spanish Basics...',
        prefixIcon: Icon(Icons.title, color: AppTheme.primaryBlue),
      ),
      style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
    );
  }

  Widget _buildContextInput() {
    return TextFormField(
      controller: _contextCtrl,
      decoration: InputDecoration(
        labelText: 'Study Context',
        hintText:
            'Describe what you want to learn, your goals, and how you want to study...',
        prefixIcon: Icon(Icons.description, color: AppTheme.primaryBlue),
        alignLabelWithHint: true,
      ),
      maxLines: 6,
      style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
    );
  }

  Widget _buildWordCounter() {
    final progress = (_wordCount / 20).clamp(0.0, 1.0);
    final color = _wordCount >= 20
        ? AppTheme.success
        : _wordCount >= 10
        ? AppTheme.warning
        : AppTheme.error;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppTheme.surfaceGradient),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Context Length',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '$_wordCount / 20 words',
                style: AppTheme.bodyMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppTheme.surfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _starting ? null : _startPlan,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.surfaceElevated,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
        ),
        child: _starting
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.rocket_launch, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Start Learning',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTipsSection() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppTheme.surfaceGradient),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.surfaceElevated.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: AppTheme.warning, size: 24),
              const SizedBox(width: 12),
              Text(
                'Pro Tips',
                style: AppTheme.headlineSmall.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          _buildTipItem(
            'Be specific about your learning goals and current level',
          ),
          _buildTipItem('Include examples of topics you want to cover'),
          _buildTipItem(
            'Mention your preferred learning style (visual, practice, etc.)',
          ),
          _buildTipItem(
            'Set a timeline or target to keep yourself accountable',
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: AppTheme.primaryGradient),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
