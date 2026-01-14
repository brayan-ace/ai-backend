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

  void _showEditModuleDialog(int moduleIndex) {
    final module = _editablePlan['modules'][moduleIndex];
    final controller = TextEditingController(text: module['title']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Module'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Module title',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
    final modules = _editablePlan['modules'] as List? ?? [];
    final planTitle = _editablePlan['title'] as String? ?? 'Study Plan';

    return Scaffold(
      backgroundColor: AppTheme.backgroundDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Study Plan',
          style: AppTheme.headlineSmall.copyWith(color: AppTheme.textPrimary),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: AppTheme.textSecondary),
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
                  colors: [
                    AppTheme.primaryBlue.withOpacity(0.1),
                    AppTheme.primaryBlue.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📚 Study Plan Editor',
                    style: AppTheme.headlineMedium.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: AppTheme.spaceSm),
                  Text(
                    planTitle,
                    style: AppTheme.headlineSmall.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: AppTheme.spaceMd),
                  Text(
                    'Customize your learning journey by editing modules and objectives below.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
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
                        color: AppTheme.textTertiary,
                      ),
                      SizedBox(height: AppTheme.spaceMd),
                      Text(
                        'No modules in this plan',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: AppTheme.spaceSm),
                      Text(
                        'Add modules to start building your study plan',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textTertiary,
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
                    color: AppTheme.surfaceCard,
                    margin: EdgeInsets.only(bottom: AppTheme.spaceMd),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      side: BorderSide.none,
                    ),
                    elevation: 2,
                    child: Column(
                      children: [
                        // Enhanced module header with gradient
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(AppTheme.spaceMd),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryBlue.withOpacity(0.08),
                                AppTheme.primaryBlue.withOpacity(0.04),
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
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              PopupMenuButton(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditModuleDialog(moduleIndex);
                                  } else if (value == 'delete') {
                                    _deleteModule(moduleIndex);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 18),
                                        SizedBox(width: 8),
                                        Text('Rename'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
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

                        // Enhanced objectives section
                        if (objectives.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceMd,
                              vertical: AppTheme.spaceSm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
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
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: AppTheme.spaceMd),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(AppTheme.spaceSm),
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
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: objectives.length,
                                    itemBuilder: (context, objectiveIndex) {
                                      final objective =
                                          objectives[objectiveIndex];
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          bottom: AppTheme.spaceSm,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 20,
                                              height: 20,
                                              margin: EdgeInsets.only(
                                                right: AppTheme.spaceMd,
                                              ),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppTheme.primaryBlue
                                                    .withOpacity(0.1),
                                                border: Border.all(
                                                  color: AppTheme.primaryBlue
                                                      .withOpacity(0.3),
                                                  width: 1,
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
                                                      color:
                                                          AppTheme.textPrimary,
                                                      height: 1.5,
                                                    ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.close,
                                                size: 18,
                                                color: Colors.redAccent,
                                              ),
                                              onPressed: () {
                                                _deleteSubtopic(
                                                  moduleIndex,
                                                  objectiveIndex,
                                                );
                                              },
                                              constraints: const BoxConstraints(
                                                minHeight: 30,
                                                minWidth: 30,
                                              ),
                                              padding: EdgeInsets.zero,
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
                  colors: [
                    AppTheme.primaryBlue.withOpacity(0.08),
                    AppTheme.primaryBlue.withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(0.3),
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
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: AppTheme.spaceSm),
                        Text(
                          'Your changes will be saved and the bot will adjust its teaching strategy based on your updated plan. Your progress and chat history will be preserved.',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
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
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.surfaceElevated, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        padding: EdgeInsets.symmetric(
                          vertical: AppTheme.spaceMd,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          side: BorderSide(
                            color: AppTheme.textTertiary,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTheme.labelMedium.copyWith(
                          color: AppTheme.textPrimary,
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

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      widget.onSave(_editablePlan);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}
