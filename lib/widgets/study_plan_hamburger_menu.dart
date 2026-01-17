/// Study Plan Hamburger Menu Widget
/// Displays the full study plan and allows for real-time editing

import 'package:flutter/material.dart';
import '../models/study_bot_state.dart';
import '../utils/theme.dart';

class StudyPlanHamburgerMenu extends StatefulWidget {
  final List<TableOfContentsItem>? tableOfContents;
  final int currentModule;
  final List<int>? completedModules;
  final Function(int, String)? onModuleEdit;
  final VoidCallback? onClose;
  final double progressPercentage;

  const StudyPlanHamburgerMenu({
    Key? key,
    this.tableOfContents,
    this.currentModule = 0,
    this.completedModules,
    this.onModuleEdit,
    this.onClose,
    this.progressPercentage = 0.0,
  }) : super(key: key);

  @override
  State<StudyPlanHamburgerMenu> createState() => _StudyPlanHamburgerMenuState();
}

class _StudyPlanHamburgerMenuState extends State<StudyPlanHamburgerMenu> {
  late List<bool> _expandedModules;

  @override
  void initState() {
    super.initState();
    _expandedModules = List<bool>.filled(
      widget.tableOfContents?.length ?? 0,
      false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: AppTheme.backgroundDeep,
        child: Column(
          children: [
            // Header with progress
            Container(
              padding: EdgeInsets.all(AppTheme.spaceLg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue,
                    AppTheme.primaryBlue.withOpacity(0.7),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '📚 Study Plan',
                          style: AppTheme.headlineSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onClose?.call();
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: AppTheme.spaceMd),
                    // Progress bar in header
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Overall Progress',
                              style: AppTheme.bodySmall.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              '${widget.progressPercentage.toStringAsFixed(0)}%',
                              style: AppTheme.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppTheme.spaceSm),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: widget.progressPercentage / 100,
                            minHeight: 6,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Modules list
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(AppTheme.spaceMd),
                itemCount: widget.tableOfContents?.length ?? 0,
                itemBuilder: (context, index) {
                  final toc = widget.tableOfContents![index];
                  final isCompleted =
                      widget.completedModules?.contains(index) ?? false;
                  final isCurrent = widget.currentModule == index;

                  return Card(
                    color: isCurrent
                        ? AppTheme.primaryBlue.withOpacity(0.1)
                        : isCompleted
                        ? Colors.green.withOpacity(0.05)
                        : AppTheme.surfaceCard,
                    child: ExpansionTile(
                      onExpansionChanged: (expanded) {
                        setState(() => _expandedModules[index] = expanded);
                      },
                      title: Row(
                        children: [
                          // Status indicator
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Colors.green
                                  : isCurrent
                                  ? AppTheme.primaryBlue
                                  : AppTheme.surfaceElevated,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                isCompleted
                                    ? '✓'
                                    : isCurrent
                                    ? '▶'
                                    : '${toc.moduleNumber}',
                                style: TextStyle(
                                  color: isCompleted || isCurrent
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: AppTheme.spaceMd),
                          // Module info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  toc.title,
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isCurrent
                                        ? AppTheme.primaryBlue
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${toc.estimatedTime} • ${toc.difficultyLevel}',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: EdgeInsets.all(AppTheme.spaceMd),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                toc.description,
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                              SizedBox(height: AppTheme.spaceMd),
                              Text(
                                'Subtopics:',
                                style: AppTheme.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: AppTheme.spaceSm),
                              ...toc.subtopics.map((subtopic) {
                                return Padding(
                                  padding: EdgeInsets.only(
                                    left: AppTheme.spaceMd,
                                    bottom: AppTheme.spaceSm,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        '•',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: AppTheme.spaceSm),
                                      Expanded(
                                        child: Text(
                                          subtopic,
                                          style: AppTheme.bodySmall.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Footer action buttons
            Container(
              padding: EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.surfaceElevated, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: BorderSide(color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                  SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement edit plan functionality
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
