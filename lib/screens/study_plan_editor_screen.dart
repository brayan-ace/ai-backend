import 'package:flutter/material.dart';
import '../utils/theme.dart';

class StudyPlanEditorScreen extends StatefulWidget {
  final Map<String, dynamic> studyPlan;
  final Function(Map<String, dynamic>) onSave;

  const StudyPlanEditorScreen({
    Key? key,
    required this.studyPlan,
    required this.onSave,
  }) : super(key: key);

  @override
  State<StudyPlanEditorScreen> createState() => _StudyPlanEditorScreenState();
}

class _StudyPlanEditorScreenState extends State<StudyPlanEditorScreen> {
  late Map<String, dynamic> _editablePlan;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Create a deep copy of the study plan
    _editablePlan = _deepCopy(widget.studyPlan);
  }

  Map<String, dynamic> _deepCopy(Map<String, dynamic> original) {
    final copy = Map<String, dynamic>.from(original);
    if (copy.containsKey('modules') && copy['modules'] is List) {
      copy['modules'] = (copy['modules'] as List)
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();
    }
    return copy;
  }

  void _renameModule(int moduleIndex, String newTitle) {
    setState(() {
      if (_editablePlan['modules'] != null &&
          moduleIndex < _editablePlan['modules'].length) {
        _editablePlan['modules'][moduleIndex]['title'] = newTitle;
      }
    });
  }

  void _deleteModule(int moduleIndex) {
    setState(() {
      if (_editablePlan['modules'] != null) {
        _editablePlan['modules'].removeAt(moduleIndex);
      }
    });
  }

  void _deleteSubtopic(int moduleIndex, int subtopicIndex) {
    setState(() {
      if (_editablePlan['modules'] != null &&
          moduleIndex < _editablePlan['modules'].length) {
        final module = _editablePlan['modules'][moduleIndex];
        if (module['objectives'] != null &&
            subtopicIndex < module['objectives'].length) {
          module['objectives'].removeAt(subtopicIndex);
        }
      }
    });
  }

  void _showEditModuleDialog(int moduleIndex, bool isDarkMode) {
    final module = _editablePlan['modules'][moduleIndex];
    final controller = TextEditingController(text: module['title']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Rename Module',
          style: TextStyle(color: _getTextColor(isDarkMode)),
        ),
        backgroundColor: isDarkMode ? Color(0xFF1F2937) : Colors.white,
        content: TextField(
          controller: controller,
          style: TextStyle(color: _getTextColor(isDarkMode)),
          cursorColor: AppTheme.primaryBlue,
          decoration: InputDecoration(
            hintText: 'Module title',
            hintStyle: TextStyle(color: _getSecondaryTextColor(isDarkMode)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide(color: _getBorderColor(isDarkMode)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
            ),
            filled: true,
            fillColor: isDarkMode ? Color(0xFF111827) : Color(0xFFF9FAFB),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: _getSecondaryTextColor(isDarkMode)),
            ),
          ),
          TextButton(
            onPressed: () {
              _renameModule(moduleIndex, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final modules = _editablePlan['modules'] as List? ?? [];
    final planTitle = _editablePlan['title'] as String? ?? 'Study Plan';

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.backgroundDeep : Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: isDarkMode ? AppTheme.backgroundDeep : Colors.white,
        elevation: isDarkMode ? 0 : 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _getTextColor(isDarkMode)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Study Plan',
          style: AppTheme.headlineSmall.copyWith(
            color: _getTextColor(isDarkMode),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.info_outline,
              color: _getSecondaryTextColor(isDarkMode),
            ),
            onPressed: () {
              // Show info about editing
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Edit your study plan modules and objectives'),
                  backgroundColor: AppTheme.primaryBlue,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced header with gradient background
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppTheme.spaceXl),
              margin: EdgeInsets.only(bottom: AppTheme.spaceLg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode
                      ? [
                          AppTheme.primaryBlue.withOpacity(0.2),
                          AppTheme.primaryBlue.withOpacity(0.08),
                        ]
                      : [
                          AppTheme.primaryBlue.withOpacity(0.1),
                          AppTheme.primaryBlue.withOpacity(0.05),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(
                    isDarkMode ? 0.3 : 0.2,
                  ),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📚 Study Plan Editor',
                    style: AppTheme.headlineMedium.copyWith(
                      color: _getTextColor(isDarkMode),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: AppTheme.spaceSm),
                  Text(
                    planTitle,
                    style: AppTheme.headlineSmall.copyWith(
                      color: _getTextColor(isDarkMode),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: AppTheme.spaceMd),
                  Text(
                    'Customize your learning journey by editing modules and objectives below.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: _getSecondaryTextColor(isDarkMode),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            // Modules with enhanced styling
            if (modules.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppTheme.spaceXl),
                  child: Column(
                    children: [
                      Icon(
                        Icons.library_books_outlined,
                        size: 60,
                        color: _getTertiaryTextColor(isDarkMode),
                      ),
                      SizedBox(height: AppTheme.spaceMd),
                      Text(
                        'No modules in this plan',
                        style: AppTheme.bodyLarge.copyWith(
                          color: _getSecondaryTextColor(isDarkMode),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: AppTheme.spaceSm),
                      Text(
                        'Add modules to start building your study plan',
                        style: AppTheme.bodySmall.copyWith(
                          color: _getTertiaryTextColor(isDarkMode),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: modules.length,
                itemBuilder: (context, moduleIndex) {
                  final module = modules[moduleIndex];
                  final moduleTitle =
                      module['title'] as String? ?? 'Untitled Module';
                  final objectives = module['objectives'] as List? ?? [];

                  return Card(
                    color: isDarkMode ? Color(0xFF1F2937) : Colors.white,
                    margin: EdgeInsets.only(bottom: AppTheme.spaceMd),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      side: BorderSide(
                        color: isDarkMode
                            ? _getBorderColor(isDarkMode)
                            : AppTheme.primaryBlue.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    elevation: isDarkMode ? 1 : 3,
                    child: Column(
                      children: [
                        // Enhanced module header with gradient
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(AppTheme.spaceMd),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDarkMode
                                  ? [
                                      AppTheme.primaryBlue.withOpacity(0.15),
                                      AppTheme.primaryBlue.withOpacity(0.08),
                                    ]
                                  : [
                                      AppTheme.primaryBlue.withOpacity(0.25),
                                      AppTheme.primaryBlue.withOpacity(0.15),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(AppTheme.radiusLg),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                margin: EdgeInsets.only(
                                  right: AppTheme.spaceMd,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: AppTheme.accentGradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.menu_book_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  moduleTitle,
                                  style: AppTheme.bodyLarge.copyWith(
                                    color: _getTextColor(isDarkMode),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              PopupMenuButton(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditModuleDialog(
                                      moduleIndex,
                                      isDarkMode,
                                    );
                                  } else if (value == 'delete') {
                                    _deleteModule(moduleIndex);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.edit,
                                          size: 18,
                                          color: _getTextColor(isDarkMode),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Rename',
                                          style: TextStyle(
                                            color: _getTextColor(isDarkMode),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 8),
                                        const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Enhanced objectives section with better theme styling
                        if (objectives.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceMd,
                              vertical: AppTheme.spaceSm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(AppTheme.spaceSm),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Color(0xFF111827).withOpacity(0.5)
                                        : Color(0xFFDEEBFF),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMd,
                                    ),
                                    border: Border.all(
                                      color: AppTheme.primaryBlue.withOpacity(
                                        isDarkMode ? 0.3 : 0.4,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        size: 18,
                                        color: AppTheme.primaryBlue,
                                      ),
                                      SizedBox(width: AppTheme.spaceSm),
                                      Text(
                                        'Learning Objectives',
                                        style: AppTheme.bodyMedium.copyWith(
                                          color: _getTextColor(isDarkMode),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: AppTheme.spaceMd),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(AppTheme.spaceMd),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Color(0xFF0F172A).withOpacity(0.6)
                                        : Color(0xFFF0F7FF),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMd,
                                    ),
                                    border: Border.all(
                                      color: isDarkMode
                                          ? _getBorderColor(isDarkMode)
                                          : AppTheme.primaryBlue.withOpacity(
                                              0.25,
                                            ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: objectives.length,
                                    itemBuilder: (context, objectiveIndex) {
                                      final objective =
                                          objectives[objectiveIndex];
                                      return Container(
                                        margin: EdgeInsets.only(
                                          bottom:
                                              objectiveIndex <
                                                  objectives.length - 1
                                              ? AppTheme.spaceMd
                                              : 0,
                                        ),
                                        padding: EdgeInsets.all(
                                          AppTheme.spaceSm,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDarkMode
                                              ? Color(
                                                  0xFF1F2937,
                                                ).withOpacity(0.6)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusMd,
                                          ),
                                          border: Border.all(
                                            color: _getBorderColor(
                                              isDarkMode,
                                            ).withOpacity(0.5),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 24,
                                              margin: EdgeInsets.only(
                                                right: AppTheme.spaceMd,
                                              ),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  colors: [
                                                    AppTheme.primaryBlue
                                                        .withOpacity(0.3),
                                                    AppTheme.primaryBlue
                                                        .withOpacity(0.15),
                                                  ],
                                                ),
                                                border: Border.all(
                                                  color: AppTheme.primaryBlue
                                                      .withOpacity(
                                                        isDarkMode ? 0.5 : 0.4,
                                                      ),
                                                  width: 2,
                                                ),
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  Icons.circle,
                                                  size: 8,
                                                  color: AppTheme.primaryBlue,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                objective,
                                                style: AppTheme.bodyMedium
                                                    .copyWith(
                                                      color: _getTextColor(
                                                        isDarkMode,
                                                      ),
                                                      height: 1.5,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.close,
                                                size: 18,
                                                color: isDarkMode
                                                    ? Color(0xFFFF6B6B)
                                                    : Colors.redAccent,
                                              ),
                                              onPressed: () {
                                                _deleteSubtopic(
                                                  moduleIndex,
                                                  objectiveIndex,
                                                );
                                              },
                                              constraints: const BoxConstraints(
                                                minHeight: 32,
                                                minWidth: 32,
                                              ),
                                              padding: EdgeInsets.zero,
                                              tooltip: 'Delete objective',
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                        SizedBox(height: AppTheme.spaceSm),
                      ],
                    ),
                  );
                },
              ),

            SizedBox(height: AppTheme.spaceLg),

            // Enhanced info box with better styling
            Container(
              padding: EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode
                      ? [
                          AppTheme.primaryBlue.withOpacity(0.15),
                          AppTheme.primaryBlue.withOpacity(0.08),
                        ]
                      : [
                          AppTheme.primaryBlue.withOpacity(0.08),
                          AppTheme.primaryBlue.withOpacity(0.04),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(
                    isDarkMode ? 0.4 : 0.3,
                  ),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    margin: EdgeInsets.only(right: AppTheme.spaceMd),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppTheme.accentGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💡 What happens when you save?',
                          style: AppTheme.bodyLarge.copyWith(
                            color: _getTextColor(isDarkMode),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: AppTheme.spaceSm),
                        Text(
                          'Your changes will be saved and the bot will adjust its teaching strategy based on your updated plan. Your progress and chat history will be preserved.',
                          style: AppTheme.bodyMedium.copyWith(
                            color: _getSecondaryTextColor(isDarkMode),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppTheme.spaceXl),

            // Enhanced Save and Cancel buttons
            Container(
              padding: EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: isDarkMode ? Color(0xFF1F2937) : Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: _getBorderColor(isDarkMode),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode
                            ? Colors.transparent
                            : Colors.transparent,
                        padding: EdgeInsets.symmetric(
                          vertical: AppTheme.spaceMd,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          side: BorderSide(
                            color: isDarkMode
                                ? Color(0xFF4B5563)
                                : AppTheme.textTertiary,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTheme.labelMedium.copyWith(
                          color: _getTextColor(isDarkMode),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        disabledBackgroundColor: AppTheme.primaryBlue
                            .withOpacity(0.5),
                        padding: EdgeInsets.symmetric(
                          vertical: AppTheme.spaceMd,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                        ),
                      ),
                      child: _isSaving
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
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save, color: Colors.white, size: 18),
                                SizedBox(width: AppTheme.spaceSm),
                                Text(
                                  'Save Changes',
                                  style: AppTheme.labelMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppTheme.spaceMd),
          ],
        ),
      ),
    );
  }

  // Theme color helper functions
  Color _getTextColor(bool isDarkMode) {
    return isDarkMode ? Colors.white : Color(0xFF1F2937);
  }

  Color _getSecondaryTextColor(bool isDarkMode) {
    return isDarkMode ? Color(0xFFD1D5DB) : Color(0xFF6B7280);
  }

  Color _getTertiaryTextColor(bool isDarkMode) {
    return isDarkMode ? Color(0xFF9CA3AF) : Color(0xFF9CA3AF);
  }

  Color _getBorderColor(bool isDarkMode) {
    return isDarkMode ? Color(0xFF374151) : Color(0xFFE5E7EB);
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      // Call the onSave callback with the edited plan
      // This should trigger _savePlanChanges in the parent screen
      await widget.onSave(_editablePlan);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Study plan changes saved!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Give time for the snackbar to be seen
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving plan: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}
