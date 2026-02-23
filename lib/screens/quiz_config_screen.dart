import 'package:flutter/material.dart';
import '../utils/theme.dart';

class QuizConfigScreen extends StatefulWidget {
  final String moduleName;
  final Function(Map<String, dynamic>) onStartQuiz;

  const QuizConfigScreen({
    Key? key,
    required this.moduleName,
    required this.onStartQuiz,
  }) : super(key: key);

  @override
  State<QuizConfigScreen> createState() => _QuizConfigScreenState();
}

class _QuizConfigScreenState extends State<QuizConfigScreen> {
  // Question type selection
  String _questionType = 'mcq'; // MCQ only

  // Number of questions
  int _mcqCount = 5;
  int _textCount = 3;

  // Web search toggle
  bool _useWebSearch = true;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDarkMode ? AppTheme.backgroundDeep : Color(0xFFFAFAFA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              '🎯 Quiz Configuration',
              style: AppTheme.headlineSmall.copyWith(
                color: isDarkMode ? AppTheme.textPrimary : Color(0xFF1F2937),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppTheme.spaceSm),
            Text(
              'Module: ${widget.moduleName}',
              style: AppTheme.bodySmall.copyWith(
                color: isDarkMode ? AppTheme.textSecondary : Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: AppTheme.spaceMd),

            // Question Type Selection
            Text(
              'Quiz Type',
              style: AppTheme.labelMedium.copyWith(
                color: isDarkMode ? AppTheme.textPrimary : Color(0xFF1F2937),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppTheme.spaceSm),
            Container(
              padding: EdgeInsets.all(AppTheme.spaceSm),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(
                  isDarkMode ? 0.15 : 0.1,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.primaryBlue, width: 2),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                  SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: Text(
                      'Multiple Choice Questions (MCQ)',
                      style: AppTheme.bodyMedium.copyWith(
                        color: isDarkMode
                            ? AppTheme.textPrimary
                            : Color(0xFF1F2937),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppTheme.spaceMd),

            // Number of questions
            Text(
              'Number of Questions',
              style: AppTheme.labelMedium.copyWith(
                color: isDarkMode ? AppTheme.textPrimary : Color(0xFF1F2937),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppTheme.spaceSm),
            _buildNumberSlider(
              label: 'MCQ Count: $_mcqCount',
              value: _mcqCount.toDouble(),
              min: 1,
              max: 10,
              onChanged: (value) {
                setState(() => _mcqCount = value.toInt());
              },
            ),
            SizedBox(height: AppTheme.spaceMd),

            // Removed text questions section as only MCQ is supported

            // Web Search Toggle
            Container(
              padding: EdgeInsets.all(AppTheme.spaceSm),
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.surfaceCard : Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🔍 Web Search for Context',
                          style: AppTheme.bodyMedium.copyWith(
                            color: isDarkMode
                                ? AppTheme.textPrimary
                                : Color(0xFF1F2937),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Enhance questions with latest information',
                          style: AppTheme.bodySmall.copyWith(
                            color: isDarkMode
                                ? AppTheme.textSecondary
                                : Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _useWebSearch,
                    onChanged: (value) {
                      setState(() => _useWebSearch = value);
                    },
                    activeColor: AppTheme.primaryBlue,
                    activeTrackColor: AppTheme.primaryBlue.withOpacity(0.3),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppTheme.spaceLg),

            // Summary
            Container(
              padding: EdgeInsets.all(AppTheme.spaceSm),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(
                  isDarkMode ? 0.1 : 0.05,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📊 Quiz Summary',
                    style: AppTheme.bodyMedium.copyWith(
                      color: isDarkMode
                          ? AppTheme.textPrimary
                          : Color(0xFF1F2937),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: AppTheme.spaceSm),

                  Text(
                    '• $_mcqCount multiple choice questions',
                    style: AppTheme.bodySmall.copyWith(
                      color: isDarkMode
                          ? AppTheme.textSecondary
                          : Color(0xFF6B7280),
                    ),
                  ),

                  SizedBox(height: 4),
                  Text(
                    _useWebSearch
                        ? '• Enhanced with web search'
                        : '• Using module content only',
                    style: AppTheme.bodySmall.copyWith(
                      color: isDarkMode
                          ? AppTheme.textSecondary
                          : Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppTheme.spaceMd),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode
                          ? AppTheme.surfaceCard
                          : Color(0xFFF3F4F6),
                      padding: EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppTheme.labelMedium.copyWith(
                        color: isDarkMode
                            ? AppTheme.textPrimary
                            : Color(0xFF1F2937),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleStartQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    child: Text(
                      'Start Quiz',
                      style: AppTheme.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
        ),
        SizedBox(height: AppTheme.spaceSm),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          activeColor: AppTheme.primaryBlue,
          inactiveColor: AppTheme.primaryBlue.withOpacity(0.2),
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _handleStartQuiz() {
    final config = {
      'questionType': 'mcq',
      'mcqCount': _mcqCount,
      'textCount': 0,
      'useWebSearch': _useWebSearch,
    };

    // Close dialog and pass config to parent callback
    // Parent (chat screen) will handle loading state and quiz generation
    widget.onStartQuiz(config);
    Navigator.pop(context);
  }
}
