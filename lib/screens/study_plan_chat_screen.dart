import 'package:flutter/material.dart';
import '../utils/theme.dart';

class StudyPlanChatScreen extends StatelessWidget {
  final String planId;
  final String planTitle;
  final String planContext;

  const StudyPlanChatScreen({
    Key? key,
    required this.planId,
    required this.planTitle,
    required this.planContext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          planTitle,
          style: AppTheme.headlineSmall.copyWith(color: AppTheme.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Study Plan Context',
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: AppTheme.spaceSm),
            Text(
              planContext,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
            ),
            Spacer(),
            Center(
              child: Text(
                'Chat UI coming soon',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
            SizedBox(height: AppTheme.spaceMd),
          ],
        ),
      ),
    );
  }
}
