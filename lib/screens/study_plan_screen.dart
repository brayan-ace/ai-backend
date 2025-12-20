import 'package:flutter/material.dart';
import '../services/study_plan_service.dart';
import '../utils/globals.dart';
import 'study_plan_chat_screen.dart';
import '../utils/theme.dart';

class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({super.key});

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  final _titleCtrl = TextEditingController();
  final _contextCtrl = TextEditingController();
  final _service = StudyPlanService();
  bool _starting = false;

  Future<void> _startPlan() async {
    final title = _titleCtrl.text.trim();
    final context = _contextCtrl.text.trim();

    if (title.isEmpty || context.isEmpty) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Please provide title and context')),
      );
      return;
    }

    // Validate context has at least 20 words
    final wordCount = context
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    if (wordCount < 20) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            'Context must be at least 20 words. Currently: $wordCount words',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _starting = true);

    // Save the plan
    await _service.savePlan(title: title, context: context);

    setState(() => _starting = false);

    if (!mounted) return;

    // Get the plan ID (most recent)
    final plans = await _service.getPlans();
    if (plans.isNotEmpty) {
      final lastPlan = plans.last;
      final planId = lastPlan['id'] as String;

      // Navigate to the chat screen for this plan
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

  Future<void> _showLoadPlanDialog() async {
    final plans = await _service.getPlans();

    if (!mounted) return;

    if (plans.isEmpty) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('No saved study plans yet'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.surfaceElevated,
                AppTheme.backgroundGradientEnd,
              ],
            ),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXl),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
                decoration: BoxDecoration(
                  color: AppTheme.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: AppTheme.accentGradient,
                      ).createShader(bounds),
                      child: Icon(Icons.school, color: Colors.white, size: 28),
                    ),
                    SizedBox(width: AppTheme.spaceSm),
                    Text(
                      'Load Study Plan',
                      style: AppTheme.headlineMedium.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppTheme.spaceMd),
              // Plans list
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceSm),
                  itemCount: plans.length,
                  itemBuilder: (ctx, index) {
                    final plan = plans[index];
                    final title = plan['title'] ?? 'Untitled';
                    final planContext = plan['context'] ?? '';
                    final planId = plan['id'];

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceSm,
                        vertical: AppTheme.spaceXs,
                      ),
                      child: Dismissible(
                        key: Key(planId),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          return await _showDeletePlanConfirmDialog(title);
                        },
                        onDismissed: (direction) {
                          _deletePlan(planId, title);
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: AppTheme.spaceMd),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.red.withOpacity(0.1), Colors.red],
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                          ),
                          child: Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _loadPlan(planId, title, planContext);
                          },
                          onLongPress: () {
                            _showPlanOptions(planId, title, planContext);
                          },
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          child: Container(
                            padding: EdgeInsets.all(AppTheme.spaceMd),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppTheme.glassGradient,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd,
                              ),
                              border: Border.all(
                                color: AppTheme.surfaceElevated.withOpacity(
                                  0.5,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(AppTheme.spaceSm),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: AppTheme.primaryGradient,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSm,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.school,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: AppTheme.spaceMd),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: AppTheme.bodyLarge.copyWith(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        planContext,
                                        style: AppTheme.bodySmall.copyWith(
                                          color: AppTheme.textTertiary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: AppTheme.textTertiary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _loadPlan(String planId, String title, String planContext) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => StudyPlanChatScreen(
          planId: planId,
          planTitle: title,
          planContext: planContext,
        ),
      ),
    );
  }

  /// Show plan options menu
  void _showPlanOptions(String planId, String title, String planContext) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.surfaceElevated,
                AppTheme.backgroundGradientEnd,
              ],
            ),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXl),
            ),
          ),
          padding: EdgeInsets.all(AppTheme.spaceMd),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Text(
                  title,
                  style: AppTheme.headlineSmall.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppTheme.spaceLg),
                // Options
                _buildOptionTile(
                  icon: Icons.edit,
                  title: 'Rename Plan',
                  color: AppTheme.primaryBlue,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRenamePlanDialog(planId, title, planContext);
                  },
                ),
                _buildOptionTile(
                  icon: Icons.delete,
                  title: 'Delete Plan',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeletePlanConfirmDialog(title).then((confirm) {
                      if (confirm == true) {
                        _deletePlan(planId, title);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build option tile for bottom sheet
  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: AppTheme.spaceSm,
        ),
        margin: EdgeInsets.only(bottom: AppTheme.spaceXs),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: AppTheme.glassGradient),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spaceSm),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: AppTheme.spaceMd),
            Text(
              title,
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
            ),
            Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  /// Show rename plan dialog
  Future<void> _showRenamePlanDialog(
    String planId,
    String currentTitle,
    String planContext,
  ) async {
    final titleController = TextEditingController(text: currentTitle);
    return showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: Text(
            'Rename Study Plan',
            style: AppTheme.headlineSmall.copyWith(color: AppTheme.textPrimary),
          ),
          content: TextField(
            controller: titleController,
            autofocus: true,
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter new name',
              hintStyle: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textTertiary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(color: AppTheme.primaryBlue),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(color: AppTheme.surfaceElevated),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newTitle = titleController.text.trim();
                if (newTitle.isNotEmpty) {
                  Navigator.pop(ctx);
                  try {
                    await _service.updatePlan(id: planId, title: newTitle);
                    if (!mounted) return;
                    scaffoldMessengerKey.currentState?.showSnackBar(
                      SnackBar(
                        content: Text('✓ Plan renamed'),
                        backgroundColor: AppTheme.primaryBlue,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    setState(() {}); // Refresh the UI
                  } catch (e) {
                    if (!mounted) return;
                    scaffoldMessengerKey.currentState?.showSnackBar(
                      SnackBar(
                        content: Text('Error renaming: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
              ),
              child: Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  /// Show delete confirmation dialog
  Future<bool?> _showDeletePlanConfirmDialog(String title) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: Text(
                  'Delete Plan?',
                  style: AppTheme.headlineSmall.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "$title"? This will also delete all chat history. This action cannot be undone.',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  /// Delete a study plan
  Future<void> _deletePlan(String planId, String title) async {
    try {
      await _service.deletePlan(planId);
      if (!mounted) return;
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('🗑️ "$title" deleted'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {}); // Refresh the UI
    } catch (e) {
      if (!mounted) return;
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Error deleting: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contextCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Scaffold(
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
          title: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: AppTheme.accentGradient,
            ).createShader(bounds),
            child: Text(
              'Create Study Plan',
              style: AppTheme.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          centerTitle: true,
          actions: [
            Container(
              margin: EdgeInsets.only(right: AppTheme.spaceSm),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: AppTheme.glassGradient),
              ),
              child: IconButton(
                icon: Icon(Icons.history, color: AppTheme.textPrimary),
                tooltip: 'Load Previous Plan',
                onPressed: _showLoadPlanDialog,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: AppTheme.spaceSm),

                // Step 1 Card
                Container(
                  padding: EdgeInsets.all(AppTheme.spaceMd),
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
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(AppTheme.spaceSm),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppTheme.primaryGradient,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm,
                              ),
                              boxShadow: AppTheme.glowShadow,
                            ),
                            child: Text(
                              '1',
                              style: AppTheme.labelLarge.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: AppTheme.spaceSm),
                          Text(
                            'Name your study plan',
                            style: AppTheme.headlineMedium.copyWith(
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppTheme.spaceMd),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          border: Border.all(
                            color: AppTheme.surfaceElevated,
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _titleCtrl,
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'e.g., Biology 101, Math Calculus',
                            labelStyle: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textTertiary,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(AppTheme.spaceMd),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Step 2 Card
                Container(
                  padding: EdgeInsets.all(AppTheme.spaceMd),
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
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(AppTheme.spaceSm),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppTheme.accentGradient,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm,
                              ),
                              boxShadow: AppTheme.accentGlow,
                            ),
                            child: Text(
                              '2',
                              style: AppTheme.labelLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: AppTheme.spaceSm),
                          Text(
                            'Describe what you want',
                            style: AppTheme.headlineMedium.copyWith(
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppTheme.spaceSm),
                      Text(
                        'Examples: "Act as a biology professor teaching cellular respiration", "You are a math genius specializing in calculus"',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      SizedBox(height: AppTheme.spaceMd),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          border: Border.all(
                            color: AppTheme.surfaceElevated,
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _contextCtrl,
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Describe the AI role and context...',
                            labelStyle: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textTertiary,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(AppTheme.spaceMd),
                          ),
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppTheme.spaceXl),

                // Step 3: Futuristic Start Button
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _starting
                          ? [AppTheme.textTertiary, AppTheme.textTertiary]
                          : AppTheme.primaryGradient,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: _starting ? null : AppTheme.glowShadow,
                  ),
                  child: ElevatedButton(
                    onPressed: _starting ? null : _startPlan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      ),
                    ),
                    child: _starting
                        ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.rocket_launch,
                                color: Colors.black,
                                size: 24,
                              ),
                              SizedBox(width: AppTheme.spaceSm),
                              Text(
                                'Start Study Plan',
                                style: AppTheme.labelLarge.copyWith(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
