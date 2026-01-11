import 'package:flutter/material.dart';
import '../utils/theme.dart';

typedef ExplanationRequestCallback =
    Future<String?> Function(
      int questionIndex,
      String questionText,
      String answerText,
      String currentExplanation,
    );

class QuizArtifactWidget extends StatefulWidget {
  final Map<String, dynamic> quizData;
  final ExplanationRequestCallback? onExplainAnswer;

  const QuizArtifactWidget({
    Key? key,
    required this.quizData,
    this.onExplainAnswer,
  }) : super(key: key);

  @override
  State<QuizArtifactWidget> createState() => _QuizArtifactWidgetState();
}

class _QuizArtifactWidgetState extends State<QuizArtifactWidget> {
  int _currentTab = 0;
  final PageController _pageController = PageController();
  late Map<int, String> _currentExplanations = {};

  @override
  void initState() {
    super.initState();
    final answers = widget.quizData['answers'] as List<dynamic>? ?? [];
    for (int i = 0; i < answers.length; i++) {
      final answer = answers[i] as Map<String, dynamic>? ?? {};
      final explanation = answer['explanation'] as String? ?? '';
      _currentExplanations[i] = explanation;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.quizData['questions'] as List<dynamic>? ?? [];
    final answers = widget.quizData['answers'] as List<dynamic>? ?? [];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundDeep,
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
                  ),
                ),
                Expanded(
                  child: _buildTabButton(label: 'Answers', index: 1, icon: '✅'),
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
                _buildQuestionsTab(questions),
                _buildAnswersTab(answers),
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
  }) {
    final isActive = _currentTab == index;
    return GestureDetector(
      onTap: () {
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
                      : AppTheme.textSecondary,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionsTab(List<dynamic> questions) {
    if (questions.isEmpty) {
      return Center(
        child: Text(
          'No questions available',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
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
        final text = question['text'] as String? ?? '';
        final options = question['options'] as List<dynamic>? ?? [];

        return Padding(
          padding: EdgeInsets.only(bottom: AppTheme.spaceMd),
          child: Card(
            color: AppTheme.surfaceElevated,
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
                      Text(
                        'Q${index + 1}',
                        style: AppTheme.labelMedium.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: AppTheme.spaceSm),
                      Expanded(
                        child: Text(
                          type.toUpperCase(),
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
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
                      color: AppTheme.textPrimary,
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
                            child: Text(
                              '${String.fromCharCode(65 + i)}. ${options[i]}',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary,
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

  Widget _buildAnswersTab(List<dynamic> answers) {
    if (answers.isEmpty) {
      return Center(
        child: Text(
          'No answers available',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppTheme.spaceMd),
      itemCount: answers.length,
      itemBuilder: (context, index) {
        final answer = answers[index] as Map<String, dynamic>?;
        if (answer == null) return SizedBox.shrink();

        final answerText = answer['answer'] as String? ?? '';
        final explanation = answer['explanation'] as String? ?? '';
        final type = answer['type'] as String? ?? 'unknown';

        return Padding(
          padding: EdgeInsets.only(bottom: AppTheme.spaceMd),
          child: Card(
            color: AppTheme.surfaceElevated,
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
                            color: AppTheme.textSecondary,
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
                            color: AppTheme.textPrimary,
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
                        color: AppTheme.textSecondary,
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
