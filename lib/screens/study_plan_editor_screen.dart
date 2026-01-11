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
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan title
            Text(
              planTitle,
              style: AppTheme.headlineMedium.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppTheme.spaceMd),

            // Modules
            if (modules.isEmpty)
              Center(
                child: Text(
                  'No modules in this plan',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
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
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      side: BorderSide.none,
                    ),
                    child: Column(
                      children: [
                        // Module header
                        ListTile(
                          title: Text(
                            '📚 $moduleTitle',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: PopupMenuButton(
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
                        ),

                        // Subtopics/Objectives
                        if (objectives.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceMd,
                              vertical: AppTheme.spaceSm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '📝 Learning Objectives:',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: AppTheme.spaceSm),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
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
                                          Expanded(
                                            child: Text(
                                              '• $objective',
                                              style: AppTheme.bodySmall
                                                  .copyWith(
                                                    color: AppTheme.textPrimary,
                                                  ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              size: 18,
                                              color: Colors.red,
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

            // Info box
            Container(
              padding: EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 What happens when you save?',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppTheme.spaceSm),
                  Text(
                    'Your changes will be saved and the bot will adjust its teaching strategy based on your updated plan. Your progress and chat history will be preserved.',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppTheme.spaceLg),

            // Save and Cancel buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceCard,
                      padding: EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        side: BorderSide(
                          color: AppTheme.primaryBlue.withOpacity(0.3),
                        ),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppTheme.labelMedium.copyWith(
                        color: AppTheme.textPrimary,
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
                      disabledBackgroundColor: AppTheme.primaryBlue.withOpacity(
                        0.5,
                      ),
                      padding: EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
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
                        : Text(
                            'Save Changes',
                            style: AppTheme.labelMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
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
