import 'package:flutter/material.dart';
import '../utils/theme.dart';

class StudyBotIdentityModal extends StatefulWidget {
  final String planName;
  final String planDescription;
  final Function(String botName, String educationLevel) onConfirm;

  const StudyBotIdentityModal({
    Key? key,
    required this.planName,
    required this.planDescription,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<StudyBotIdentityModal> createState() => _StudyBotIdentityModalState();
}

class _StudyBotIdentityModalState extends State<StudyBotIdentityModal> {
  final _botNameCtrl = TextEditingController();
  String _selectedLevel = 'Self-Learner / Other';
  bool _isCreating = false;

  static const List<String> educationLevels = [
    'Primary',
    'Junior Secondary',
    'Senior Secondary',
    'University',
    'Self-Learner / Other',
  ];

  @override
  void dispose() {
    _botNameCtrl.dispose();
    super.dispose();
  }

  void _handleConfirm() {
    final botName = _botNameCtrl.text.trim();

    if (botName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a name for your Study Bot'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    print(
      '[StudyBotIdentityModal] _handleConfirm called with botName=$botName, level=$_selectedLevel',
    );

    setState(() => _isCreating = true);

    // Return the result to parent using Navigator.pop
    print('[StudyBotIdentityModal] Returning result to parent');
    Navigator.of(
      context,
    ).pop({'botName': botName, 'educationLevel': _selectedLevel});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceCard,
            AppTheme.surfaceCard.withOpacity(0.95),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppTheme.spaceMd,
            right: AppTheme.spaceMd,
            top: AppTheme.spaceMd,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spaceMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: AppTheme.spaceMd),
              Text(
                'Define Your Study Bot',
                style: AppTheme.headlineSmall.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: AppTheme.spaceSm),
              Text(
                'Give your tutor a name and set their expertise level',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              SizedBox(height: AppTheme.spaceLg),

              // Study Plan Summary
              Container(
                padding: EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Study Plan',
                      style: AppTheme.labelSmall.copyWith(
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: AppTheme.spaceSm),
                    Text(
                      widget.planName,
                      style: AppTheme.headlineSmall.copyWith(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: AppTheme.spaceSm),
                    Text(
                      widget.planDescription,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppTheme.spaceLg),

              // Study Bot Name Field
              Text(
                'Study Bot Name',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: AppTheme.spaceSm),
              TextField(
                controller: _botNameCtrl,
                enabled: !_isCreating,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g., James, Dr. Nutri, Coach Bio',
                  hintStyle: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                  filled: true,
                  fillColor: AppTheme.primaryBlue.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.primaryBlue.withOpacity(0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.primaryBlue.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.primaryBlue,
                      width: 2,
                    ),
                  ),
                  contentPadding: EdgeInsets.all(AppTheme.spaceMd),
                ),
              ),
              SizedBox(height: AppTheme.spaceLg),

              // Education Level Selector
              Text(
                'Education / Grade Level',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: AppTheme.spaceSm),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedLevel,
                  underline: const SizedBox(),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMd,
                    vertical: AppTheme.spaceSm,
                  ),
                  items: educationLevels.map((level) {
                    return DropdownMenuItem(
                      value: level,
                      child: Text(
                        level,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: _isCreating
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedLevel = value);
                          }
                        },
                  dropdownColor: AppTheme.surfaceCard,
                ),
              ),
              SizedBox(height: AppTheme.spaceLg),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isCreating
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: AppTheme.spaceMd,
                        ),
                        side: BorderSide(
                          color: AppTheme.primaryBlue.withOpacity(0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTheme.labelMedium.copyWith(
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isCreating ? null : _handleConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        padding: EdgeInsets.symmetric(
                          vertical: AppTheme.spaceMd,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isCreating
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withOpacity(0.8),
                                ),
                              ),
                            )
                          : Text(
                              'Create Study Bot',
                              style: AppTheme.labelMedium.copyWith(
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppTheme.spaceSm),
            ],
          ),
        ),
      ),
    );
  }
}
