import 'package:flutter/material.dart';
import '../utils/theme.dart';

typedef ExplanationRequestCallback =
    Future<String?> Function(
      int questionIndex,
      String questionText,
      String answerText,
      String currentExplanation,
    );

typedef ScoreUpdateCallback =
    void Function(int correctAnswers, int totalQuestions, double percentage);

class QuizArtifactWidget extends StatefulWidget {
  final Map<String, dynamic> quizData;
  final ExplanationRequestCallback? onExplainAnswer;
  final ScoreUpdateCallback? onScoreUpdate;

  const QuizArtifactWidget({
    Key? key,
    required this.quizData,
    this.onExplainAnswer,
    this.onScoreUpdate,
  }) : super(key: key);

  @override
  State<QuizArtifactWidget> createState() => _QuizArtifactWidgetState();
}

class _QuizArtifactWidgetState extends State<QuizArtifactWidget> {
  int _currentTab = 0;
  final PageController _pageController = PageController();
  late Map<int, String> _currentExplanations = {};
  late Map<int, String> _selectedAnswers = {}; // Track user's selected answers

  @override
  void initState() {
    super.initState();
    final answers = widget.quizData['answers'] as List<dynamic>? ?? [];
    for (int i = 0; i < answers.length; i++) {
      final answer = answers[i] as Map<String, dynamic>? ?? {};
      final explanation = answer['explanation'] as String? ?? '';
      _currentExplanations[i] = explanation;
    }
    // Initialize selected answers map
    final questions = widget.quizData['questions'] as List<dynamic>? ?? [];
    for (int i = 0; i < questions.length; i++) {
      _selectedAnswers[i] = '';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final questions = widget.quizData['questions'] as List<dynamic>? ?? [];
    final answers = widget.quizData['answers'] as List<dynamic>? ?? [];

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.surfaceCard : Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isDarkMode
              ? AppTheme.primaryBlue.withOpacity(0.2)
              : Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.backgroundDeep : Color(0xFFF3F4F6),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusMd),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    label: 'Questions',
                    index: 0,
                    icon: '❓',
                    isDarkMode: isDarkMode,
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    label: 'Answers',
                    index: 1,
                    icon: '✅',
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            ),
          ),
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentTab = index;
                });
              },
              children: [
                _buildQuestionsTab(questions, isDarkMode),
                _buildAnswersTab(answers, isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required int index,
    required String icon,
    required bool isDarkMode,
  }) {
    final isActive = _currentTab == index;
    return GestureDetector(
      onTap: () {
        // Prevent navigation to answers tab if questions not answered
        if (index == 1 && !_allQuestionsAnswered()) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please answer all questions first'),
              backgroundColor: AppTheme.error,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        // Calculate and send score when navigating to answers
        if (index == 1 && _allQuestionsAnswered()) {
          _calculateAndSendScore();
        }
        _pageController.animateToPage(
          index,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: AppTheme.spaceMd,
          horizontal: AppTheme.spaceSm,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppTheme.primaryBlue : Colors.transparent,
              width: isActive ? 3 : 0,
            ),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: TextStyle(fontSize: 18)),
              SizedBox(height: 4),
              Text(
                label,
                style: AppTheme.labelMedium.copyWith(
                  color: isActive
                      ? AppTheme.primaryBlue
                      : (isDarkMode
                            ? AppTheme.textSecondary
                            : Color(0xFF6B7280)),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _allQuestionsAnswered() {
    final questions = widget.quizData['questions'] as List<dynamic>? ?? [];
    for (int i = 0; i < questions.length; i++) {
      if ((_selectedAnswers[i] ?? '').isEmpty) {
        return false;
      }
    }
    return true;
  }

  void _calculateAndSendScore() {
    final questions = widget.quizData['questions'] as List<dynamic>? ?? [];
    final answers = widget.quizData['answers'] as List<dynamic>? ?? [];
    
    int correctCount = 0;
    for (int i = 0; i < questions.length; i++) {
      final answer = answers[i] as Map<String, dynamic>?;
      if (answer == null) continue;
      
      final correctAnswer = (answer['correct_answer'] as String?) ?? (answer['answer'] as String?) ?? '';
      final userAnswer = _selectedAnswers[i] ?? '';
      
      if (correctAnswer.isNotEmpty && userAnswer.isNotEmpty && correctAnswer.toLowerCase() == userAnswer.toLowerCase()) {
        correctCount++;
      }
    }
    
    final total = questions.length;
    final percentage = total > 0 ? (correctCount / total * 100).round() : 0;
    
    // Call the score update callback
    widget.onScoreUpdate?.call(correctCount, total, percentage.toDouble());
    
    print('[QuizArtifactWidget] Quiz Score: $correctCount/$total (${percentage}%)');
  }

  Widget _buildQuestionsTab(List<dynamic> questions, bool isDarkMode) {
    if (questions.isEmpty) {
      return Center(
        child: Text(
          'No questions available',
          style: AppTheme.bodyMedium.copyWith(
            color: isDarkMode ? AppTheme.textSecondary : Color(0xFF6B7280),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppTheme.spaceMd),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final question = questions[index] as Map<String, dynamic>?;
        if (question == null) return SizedBox.shrink();

        final type = question['type'] as String? ?? 'unknown';
        // Support both 'question' and 'text' field names
        final text =
            (question['question'] as String?) ??
            (question['text'] as String?) ??
            '';
        final options =
            (question['options'] as List<dynamic>?)?.cast<String>() ?? [];

        if (text.isEmpty) {
          print('[QuizArtifactWidget] Warning: Question $index has empty text');
          return SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.only(bottom: AppTheme.spaceMd),
          child: Card(
            color: isDarkMode ? AppTheme.surfaceElevated : Color(0xFFFAFAFA),
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                        child: Text(
                          'Q${index + 1}',
                          style: AppTheme.labelSmall.copyWith(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: AppTheme.spaceSm),
                      Expanded(
                        child: Text(
                          type.toUpperCase(),
                          style: AppTheme.bodySmall.copyWith(
                            color: isDarkMode
                                ? AppTheme.textSecondary
                                : Color(0xFF6B7280),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppTheme.spaceSm),
                  Text(
                    text,
                    style: AppTheme.bodyMedium.copyWith(
                      color: isDarkMode
                          ? AppTheme.textPrimary
                          : Color(0xFF1F2937),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (type == 'mcq' && options.isNotEmpty) ...[
                    SizedBox(height: AppTheme.spaceMd),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < options.length; i++)
                          Padding(
                            padding: EdgeInsets.only(bottom: AppTheme.spaceSm),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedAnswers[index] = options[i];
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppTheme.spaceMd,
                                  vertical: AppTheme.spaceSm,
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedAnswers[index] == options[i]
                                      ? AppTheme.primaryBlue.withOpacity(0.2)
                                      : (isDarkMode
                                            ? AppTheme.surfaceCard
                                            : Color(0xFFFFFFFF)),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSm,
                                  ),
                                  border: Border.all(
                                    color: _selectedAnswers[index] == options[i]
                                        ? AppTheme.primaryBlue
                                        : (isDarkMode
                                              ? AppTheme.textSecondary
                                                    .withOpacity(0.3)
                                              : Color(0xFFE5E7EB)),
                                    width: _selectedAnswers[index] == options[i]
                                        ? 2
                                        : 1,
                                  ),
                                ),
                                child: Text(
                                  '${String.fromCharCode(65 + i)}. ${options[i]}',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: _selectedAnswers[index] == options[i]
                                        ? AppTheme.primaryBlue
                                        : (isDarkMode
                                              ? AppTheme.textSecondary
                                              : Color(0xFF6B7280)),
                                    fontWeight:
                                        _selectedAnswers[index] == options[i]
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnswersTab(List<dynamic> answers, bool isDarkMode) {
    if (answers.isEmpty) {
      return Center(
        child: Text(
          'No answers available',
          style: AppTheme.bodyMedium.copyWith(
            color: isDarkMode ? AppTheme.textSecondary : Color(0xFF6B7280),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppTheme.spaceMd),
      itemCount: answers.length,
      itemBuilder: (context, index) {
        final answer = answers[index] as Map<String, dynamic>?;
        if (answer == null) return SizedBox.shrink();

        // Support both field name variations
        final answerText =
            (answer['answer'] as String?) ??
            (answer['correct_answer'] as String?) ??
            '';
        final explanation =
            (answer['explanation'] as String?) ??
            (answer['reason'] as String?) ??
            '';
        final type = answer['type'] as String? ?? 'unknown';

        if (answerText.isEmpty) {
          print('[QuizArtifactWidget] Warning: Answer $index has empty text');
          return SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.only(bottom: AppTheme.spaceMd),
          child: Card(
            color: isDarkMode ? AppTheme.surfaceElevated : Color(0xFFFAFAFA),
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                        child: Text(
                          'Q${index + 1}',
                          style: AppTheme.labelSmall.copyWith(
                            color: AppTheme.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: AppTheme.spaceSm),
                      Expanded(
                        child: Text(
                          type.toUpperCase(),
                          style: AppTheme.bodySmall.copyWith(
                            color: isDarkMode
                                ? AppTheme.textSecondary
                                : Color(0xFF6B7280),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppTheme.spaceMd),
                  Container(
                    padding: EdgeInsets.all(AppTheme.spaceSm),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(
                        color: AppTheme.success.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Correct Answer:',
                          style: AppTheme.labelSmall.copyWith(
                            color: AppTheme.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          answerText,
                          style: AppTheme.bodySmall.copyWith(
                            color: isDarkMode
                                ? AppTheme.textPrimary
                                : Color(0xFF1F2937),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (explanation.isNotEmpty) ...[
                    SizedBox(height: AppTheme.spaceMd),
                    Text(
                      '💡 Explanation:',
                      style: AppTheme.labelSmall.copyWith(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _currentExplanations[index] ?? explanation,
                      style: AppTheme.bodySmall.copyWith(
                        color: isDarkMode
                            ? AppTheme.textSecondary
                            : Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: AppTheme.spaceMd),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onExplainAnswer != null
                            ? () => _requestDeepExplanation(
                                index,
                                answerText,
                                answerText,
                                _currentExplanations[index] ?? explanation,
                              )
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue.withOpacity(
                            0.15,
                          ),
                          foregroundColor: AppTheme.primaryBlue,
                          padding: EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceMd,
                            vertical: AppTheme.spaceSm,
                          ),
                          side: BorderSide(
                            color: AppTheme.primaryBlue.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.help_outline, size: 16),
                            SizedBox(width: 8),
                            Text('I don\'t understand this'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _requestDeepExplanation(
    int questionIndex,
    String questionText,
    String answerText,
    String currentExplanation,
  ) async {
    final newExplanation = await widget.onExplainAnswer?.call(
      questionIndex,
      questionText,
      answerText,
      currentExplanation,
    );

    if (newExplanation != null && newExplanation.isNotEmpty) {
      setState(() {
        _currentExplanations[questionIndex] = newExplanation;
      });
    }
  }
}
