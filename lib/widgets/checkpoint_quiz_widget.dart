import 'package:flutter/material.dart';
import 'dart:async';
import '../services/checkpoint_quiz_service.dart';

class CheckpointQuizWidget extends StatefulWidget {
  final CheckpointQuiz quiz;
  final String botId;
  final String userId;
  final int moduleIndex;
  final int conceptIndex;
  final Function(CheckpointQuizResult) onCompleted;
  final VoidCallback onSkipped;

  const CheckpointQuizWidget({
    Key? key,
    required this.quiz,
    required this.botId,
    required this.userId,
    required this.moduleIndex,
    required this.conceptIndex,
    required this.onCompleted,
    required this.onSkipped,
  }) : super(key: key);

  @override
  State<CheckpointQuizWidget> createState() => _CheckpointQuizWidgetState();
}

class _CheckpointQuizWidgetState extends State<CheckpointQuizWidget> {
  late List<String?> userAnswers;
  int currentQuestionIndex = 0;
  bool isSubmitting = false;
  int timeRemaining = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    userAnswers = List<String?>.filled(widget.quiz.questions.length, null);
    timeRemaining = widget.quiz.timeLimitSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (timeRemaining > 0) {
        setState(() => timeRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _submitAnswers() async {
    setState(() => isSubmitting = true);

    try {
      // Get correct answers from quiz
      final correctAnswers = widget.quiz.questions
          .map((q) => q.correctOption ?? '')
          .toList();

      final service = CheckpointQuizService(
        backendUrl: 'http://your-backend-url',
      );
      final result = await service.submitQuizAnswers(
        botId: widget.botId,
        userId: widget.userId,
        moduleIndex: widget.moduleIndex,
        conceptIndex: widget.conceptIndex,
        answers: userAnswers.cast<String>(),
        correctAnswers: correctAnswers,
      );

      if (mounted) {
        setState(() => isSubmitting = false);
        widget.onCompleted(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting quiz: $e')));
      }
    }
  }

  void _nextQuestion() {
    if (currentQuestionIndex < widget.quiz.questions.length - 1) {
      setState(() => currentQuestionIndex++);
    }
  }

  void _previousQuestion() {
    if (currentQuestionIndex > 0) {
      setState(() => currentQuestionIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = widget.quiz.questions[currentQuestionIndex];
    final isAnswered = userAnswers[currentQuestionIndex] != null;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFF6366F1), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with title and timer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎯 Mastery Checkpoint: ${widget.quiz.concept}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Question ${currentQuestionIndex + 1}/${widget.quiz.questions.length}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: timeRemaining < 30
                      ? Colors.red[100]
                      : Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '⏱️ ${timeRemaining}s',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: timeRemaining < 30 ? Colors.red : Colors.blue,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Progress indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (currentQuestionIndex + 1) / widget.quiz.questions.length,
              minHeight: 6,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),

          SizedBox(height: 20),

          // Question text
          Text(
            currentQuestion.question,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),

          SizedBox(height: 16),

          // Question options
          if (currentQuestion.type == 'mcq' && currentQuestion.options != null)
            Column(
              spacing: 10,
              children: currentQuestion.options!.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final optionLabel = String.fromCharCode(
                  65 + index,
                ); // A, B, C, D

                return GestureDetector(
                  onTap: () {
                    setState(
                      () => userAnswers[currentQuestionIndex] = optionLabel,
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: userAnswers[currentQuestionIndex] == optionLabel
                          ? Color(0xFF6366F1)
                          : Colors.grey[100],
                      border: Border.all(
                        color: userAnswers[currentQuestionIndex] == optionLabel
                            ? Color(0xFF6366F1)
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color:
                                userAnswers[currentQuestionIndex] == optionLabel
                                ? Colors.white
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              optionLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    userAnswers[currentQuestionIndex] ==
                                        optionLabel
                                    ? Color(0xFF6366F1)
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  userAnswers[currentQuestionIndex] ==
                                      optionLabel
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            )
          else
            TextField(
              onChanged: (value) {
                userAnswers[currentQuestionIndex] = value;
              },
              decoration: InputDecoration(
                hintText: 'Type your answer here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                ),
              ),
              maxLines: 3,
            ),

          SizedBox(height: 20),

          // Navigation buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (currentQuestionIndex > 0)
                OutlinedButton.icon(
                  onPressed: _previousQuestion,
                  icon: Icon(Icons.arrow_back),
                  label: Text('Previous'),
                )
              else
                SizedBox.shrink(),
              Row(
                children: [
                  TextButton(
                    onPressed: widget.onSkipped,
                    child: Text('Skip Quiz'),
                  ),
                  SizedBox(width: 8),
                  if (currentQuestionIndex < widget.quiz.questions.length - 1)
                    ElevatedButton.icon(
                      onPressed: isAnswered ? _nextQuestion : null,
                      icon: Icon(Icons.arrow_forward),
                      label: Text('Next'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6366F1),
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: isSubmitting ? null : _submitAnswers,
                      icon: isSubmitting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Icon(Icons.check),
                      label: Text(isSubmitting ? 'Submitting...' : 'Submit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6366F1),
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget to display checkpoint quiz result
class CheckpointResultWidget extends StatelessWidget {
  final CheckpointQuizResult result;
  final VoidCallback onContinue;

  const CheckpointResultWidget({
    Key? key,
    required this.result,
    required this.onContinue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isPassed = result.passed;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPassed ? Colors.green[50] : Colors.orange[50],
        border: Border.all(
          color: isPassed ? Colors.green : Colors.orange,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Result icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isPassed ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Center(
              child: Text(
                isPassed ? '✅' : '📊',
                style: TextStyle(fontSize: 32),
              ),
            ),
          ),

          SizedBox(height: 16),

          // Score
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${result.score}/${result.totalQuestions}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isPassed ? Colors.green[700] : Colors.orange[700],
                ),
              ),
              SizedBox(width: 8),
              Text(
                '(${result.scorePercentage.toStringAsFixed(1)}%)',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Message
          Text(
            result.message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isPassed ? Colors.green[700] : Colors.orange[700],
            ),
          ),

          if (!isPassed) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Passing score: ',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    TextSpan(
                      text: '${result.passingThreshold.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          SizedBox(height: 20),

          // Continue button
          ElevatedButton(
            onPressed: onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: isPassed ? Colors.green : Colors.orange,
              minimumSize: Size(double.infinity, 44),
            ),
            child: Text(
              isPassed ? '🚀 Next Concept' : '📚 Review & Retake',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
