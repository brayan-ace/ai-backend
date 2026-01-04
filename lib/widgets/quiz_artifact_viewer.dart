import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';
import '../models/quiz_models.dart';

class QuizArtifactViewer extends StatefulWidget {
  final QuizArtifact artifact;

  const QuizArtifactViewer({super.key, required this.artifact});

  @override
  State<QuizArtifactViewer> createState() => _QuizArtifactViewerState();
}

class _QuizArtifactViewerState extends State<QuizArtifactViewer> {
  bool _showAnswers = false;
  int _currentQuestionIndex = 0;
  final Map<int, String> _userAnswers = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        leading: IconButton(
          icon: Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.artifact.title,
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${widget.artifact.numQuestions} Questions • ${widget.artifact.gradeLevel}',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          if (widget.artifact.includeAnswers)
            IconButton(
              icon: Icon(
                _showAnswers ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.primaryBlue,
              ),
              onPressed: () => setState(() => _showAnswers = !_showAnswers),
              tooltip: _showAnswers ? 'Hide Answers' : 'Show Answers',
            ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppTheme.textPrimary),
            color: AppTheme.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            onSelected: (value) {
              if (value == 'export') {
                _exportQuiz();
              } else if (value == 'reset') {
                _resetQuiz();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.share, color: AppTheme.primaryBlue, size: 20),
                    SizedBox(width: AppTheme.spaceSm),
                    Text('Share Quiz'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: AppTheme.accentBlue, size: 20),
                    SizedBox(width: AppTheme.spaceSm),
                    Text('Reset Answers'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
          child: Column(
            children: [
              // Progress indicator
              Container(
                padding: EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: AppTheme.glassGradient),
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.surfaceElevated.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: List.generate(
                    widget.artifact.questions.length,
                    (index) => Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          gradient: index <= _currentQuestionIndex
                              ? LinearGradient(colors: AppTheme.accentGradient)
                              : null,
                          color: index <= _currentQuestionIndex
                              ? null
                              : AppTheme.surfaceElevated.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Quiz content
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(AppTheme.spaceLg),
                  children: [
                    ...widget.artifact.questions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final question = entry.value;
                      return _buildQuestionCard(index, question);
                    }),
                    SizedBox(height: AppTheme.spaceLg),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, QuizQuestion question) {
    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spaceLg),
      padding: EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppTheme.surfaceGradient),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.surfaceElevated.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question number and text
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceSm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: AppTheme.accentGradient),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  'Q${index + 1}',
                  style: AppTheme.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: Text(
                  question.question,
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spaceMd),

          // Options for MCQ
          if (question.options != null) ...[
            ...question.options!.asMap().entries.map((optEntry) {
              final optIndex = optEntry.key;
              final option = optEntry.value;
              final optionLetter = String.fromCharCode(
                65 + optIndex,
              ); // A, B, C, D
              final isSelected = _userAnswers[index] == optionLetter;
              final isCorrect = question.correctAnswer == optionLetter;
              final showCorrect = _showAnswers && isCorrect;
              final showWrong = _showAnswers && isSelected && !isCorrect;

              return GestureDetector(
                onTap: _showAnswers
                    ? null
                    : () {
                        setState(() {
                          _userAnswers[index] = optionLetter;
                        });
                      },
                child: Container(
                  margin: EdgeInsets.only(bottom: AppTheme.spaceSm),
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: showCorrect
                          ? [
                              AppTheme.primaryBlue.withOpacity(0.2),
                              AppTheme.primaryBlueDark.withOpacity(0.2),
                            ]
                          : showWrong
                          ? [
                              AppTheme.error.withOpacity(0.2),
                              AppTheme.error.withOpacity(0.1),
                            ]
                          : isSelected
                          ? AppTheme.accentGradient
                                .map((c) => c.withOpacity(0.2))
                                .toList()
                          : AppTheme.glassGradient,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: showCorrect
                          ? AppTheme.primaryBlue
                          : showWrong
                          ? AppTheme.error
                          : isSelected
                          ? AppTheme.accentBlue
                          : AppTheme.surfaceElevated.withOpacity(0.5),
                      width: showCorrect || showWrong || isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: showCorrect
                              ? AppTheme.primaryBlue
                              : showWrong
                              ? AppTheme.error
                              : isSelected
                              ? AppTheme.accentBlue
                              : AppTheme.surfaceElevated,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            optionLetter,
                            style: AppTheme.labelLarge.copyWith(
                              color: showCorrect || showWrong || isSelected
                                  ? Colors.white
                                  : AppTheme.textTertiary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: AppTheme.spaceSm),
                      Expanded(
                        child: Text(
                          option,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (showCorrect)
                        Icon(Icons.check_circle, color: AppTheme.primaryBlue),
                      if (showWrong) Icon(Icons.cancel, color: AppTheme.error),
                    ],
                  ),
                ),
              );
            }),
          ] else ...[
            // Text input for full text questions
            Container(
              padding: EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: AppTheme.glassGradient),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppTheme.surfaceElevated.withOpacity(0.5),
                ),
              ),
              child: TextField(
                maxLines: 4,
                enabled: !_showAnswers,
                decoration: InputDecoration(
                  hintText: 'Type your answer here...',
                  hintStyle: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                  border: InputBorder.none,
                ),
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimary,
                ),
                onChanged: (value) {
                  setState(() {
                    _userAnswers[index] = value;
                  });
                },
              ),
            ),
          ],

          // Show answer and explanation if enabled
          if (_showAnswers && question.correctAnswer != null) ...[
            SizedBox(height: AppTheme.spaceMd),
            Container(
              padding: EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue.withOpacity(0.1),
                    AppTheme.primaryBlueDark.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: AppTheme.primaryBlue,
                        size: 20,
                      ),
                      SizedBox(width: AppTheme.spaceXs),
                      Text(
                        'Correct Answer: ${question.correctAnswer}',
                        style: AppTheme.labelLarge.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (question.explanation != null) ...[
                    SizedBox(height: AppTheme.spaceXs),
                    Text(
                      question.explanation!,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final answeredCount = _userAnswers.length;
    final totalQuestions = widget.artifact.questions.length;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppTheme.accentGradient),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.accentGlow,
      ),
      child: ElevatedButton(
        onPressed: _showAnswers ? null : _submitQuiz,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.all(AppTheme.spaceMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 24),
            SizedBox(width: AppTheme.spaceSm),
            Text(
              _showAnswers
                  ? 'Showing Answers'
                  : 'Submit Quiz ($answeredCount/$totalQuestions)',
              style: AppTheme.labelLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitQuiz() {
    if (_userAnswers.length < widget.artifact.questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please answer all questions before submitting'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Calculate score if answers are available
    if (widget.artifact.includeAnswers) {
      int correct = 0;
      for (int i = 0; i < widget.artifact.questions.length; i++) {
        if (_userAnswers[i] == widget.artifact.questions[i].correctAnswer) {
          correct++;
        }
      }

      final percentage = (correct / widget.artifact.questions.length * 100)
          .round();

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(AppTheme.spaceLg),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: AppTheme.surfaceGradient),
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(
                color: AppTheme.surfaceElevated.withOpacity(0.5),
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(AppTheme.spaceLg),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppTheme.accentGradient),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.star, color: Colors.white, size: 48),
                ),
                SizedBox(height: AppTheme.spaceMd),
                Text(
                  'Quiz Complete!',
                  style: AppTheme.headlineMedium.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: AppTheme.spaceXs),
                Text(
                  'Your Score: $correct/${widget.artifact.questions.length}',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                SizedBox(height: AppTheme.spaceXs),
                Text(
                  '$percentage%',
                  style: AppTheme.headlineLarge.copyWith(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _showAnswers = true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceLg,
                      vertical: AppTheme.spaceMd,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: Text('Review Answers'),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quiz submitted successfully!'),
          backgroundColor: AppTheme.primaryBlue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _resetQuiz() {
    setState(() {
      _userAnswers.clear();
      _showAnswers = false;
      _currentQuestionIndex = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Quiz reset! Start fresh.'),
        backgroundColor: AppTheme.accentBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _exportQuiz() {
    final buffer = StringBuffer();
    buffer.writeln(widget.artifact.title);
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (int i = 0; i < widget.artifact.questions.length; i++) {
      final question = widget.artifact.questions[i];
      buffer.writeln('Question ${i + 1}: ${question.question}');

      if (question.options != null) {
        for (int j = 0; j < question.options!.length; j++) {
          final letter = String.fromCharCode(65 + j);
          buffer.writeln('$letter) ${question.options![j]}');
        }
      }

      if (widget.artifact.includeAnswers && question.correctAnswer != null) {
        buffer.writeln('\nAnswer: ${question.correctAnswer}');
        if (question.explanation != null) {
          buffer.writeln('Explanation: ${question.explanation}');
        }
      }

      buffer.writeln();
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Quiz copied to clipboard!'),
          ],
        ),
        backgroundColor: AppTheme.primaryBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
