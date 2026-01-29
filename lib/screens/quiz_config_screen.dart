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
  String _questionType = 'both'; // 'mcq', 'text', 'both'

  // Number of questions
  int _mcqCount = 5;
  int _textCount = 3;

  // Web search toggle
  bool _useWebSearch = true;

  bool _isLoading = false;

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
              'Question Types',
              style: AppTheme.labelMedium.copyWith(
                color: isDarkMode ? AppTheme.textPrimary : Color(0xFF1F2937),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppTheme.spaceSm),

            // Radio buttons for question type
            _buildRadioTile(
              title: 'Multiple Choice Questions (MCQ)',
              value: 'mcq',
              groupValue: _questionType,
              onChanged: (value) {
                setState(() => _questionType = value!);
              },
              isDarkMode: isDarkMode,
            ),
            SizedBox(height: AppTheme.spaceSm),
            _buildRadioTile(
              title: 'Full Text Questions',
              value: 'text',
              groupValue: _questionType,
              onChanged: (value) {
                setState(() => _questionType = value!);
              },
              isDarkMode: isDarkMode,
            ),
            SizedBox(height: AppTheme.spaceSm),
            _buildRadioTile(
              title: 'Both MCQ and Text',
              value: 'both',
              groupValue: _questionType,
              onChanged: (value) {
                setState(() => _questionType = value!);
              },
              isDarkMode: isDarkMode,
            ),

            SizedBox(height: AppTheme.spaceMd),

            // Number of questions
            if (_questionType == 'mcq' || _questionType == 'both') ...[
              Text(
                'MCQ Questions',
                style: AppTheme.labelMedium.copyWith(
                  color: isDarkMode ? AppTheme.textPrimary : Color(0xFF1F2937),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: AppTheme.spaceSm),
              _buildNumberSlider(
                label: 'Number of MCQs: $_mcqCount',
                value: _mcqCount.toDouble(),
                min: 1,
                max: 10,
                onChanged: (value) {
                  setState(() => _mcqCount = value.toInt());
                },
              ),
              SizedBox(height: AppTheme.spaceMd),
            ],

            if (_questionType == 'text' || _questionType == 'both') ...[
              Text(
                'Text Questions',
                style: AppTheme.labelMedium.copyWith(
                  color: isDarkMode ? AppTheme.textPrimary : Color(0xFF1F2937),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: AppTheme.spaceSm),
              _buildNumberSlider(
                label: 'Number of Text Questions: $_textCount',
                value: _textCount.toDouble(),
                min: 1,
                max: 10,
                onChanged: (value) {
                  setState(() => _textCount = value.toInt());
                },
              ),
              SizedBox(height: AppTheme.spaceMd),
            ],

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
                  if (_questionType == 'mcq') ...[
                    Text(
                      '• $_mcqCount multiple choice questions',
                      style: AppTheme.bodySmall.copyWith(
                        color: isDarkMode
                            ? AppTheme.textSecondary
                            : Color(0xFF6B7280),
                      ),
                    ),
                  ] else if (_questionType == 'text') ...[
                    Text(
                      '• $_textCount text questions',
                      style: AppTheme.bodySmall.copyWith(
                        color: isDarkMode
                            ? AppTheme.textSecondary
                            : Color(0xFF6B7280),
                      ),
                    ),
                  ] else ...[
                    Text(
                      '• $_mcqCount MCQ + $_textCount text questions',
                      style: AppTheme.bodySmall.copyWith(
                        color: isDarkMode
                            ? AppTheme.textSecondary
                            : Color(0xFF6B7280),
                      ),
                    ),
                  ],
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
                    onPressed: _isLoading ? null : _handleStartQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      disabledBackgroundColor: AppTheme.primaryBlue.withOpacity(
                        0.5,
                      ),
                      padding: EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
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

  Widget _buildRadioTile({
    required String title,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
    required bool isDarkMode,
  }) {
    return InkWell(
      onTap: () => onChanged(value),
      child: Container(
        padding: EdgeInsets.all(AppTheme.spaceSm),
        decoration: BoxDecoration(
          color: groupValue == value
              ? AppTheme.primaryBlue.withOpacity(isDarkMode ? 0.15 : 0.1)
              : (isDarkMode ? AppTheme.surfaceCard : Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: groupValue == value
                ? AppTheme.primaryBlue
                : AppTheme.primaryBlue.withOpacity(0.2),
            width: groupValue == value ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: AppTheme.primaryBlue,
            ),
            Expanded(
              child: Text(
                title,
                style: AppTheme.bodyMedium.copyWith(
                  color: isDarkMode ? AppTheme.textPrimary : Color(0xFF1F2937),
                  fontWeight: groupValue == value
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
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
    setState(() => _isLoading = true);

    final config = {
      'questionType': _questionType,
      'mcqCount': _questionType == 'mcq' || _questionType == 'both'
          ? _mcqCount
          : 0,
      'textCount': _questionType == 'text' || _questionType == 'both'
          ? _textCount
          : 0,
      'useWebSearch': _useWebSearch,
    };

    widget.onStartQuiz(config);
    Navigator.pop(context);
  }
}
