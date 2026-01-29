/// Premium Study Plan Hamburger Menu Widget
/// A beautiful, animated study plan viewer with glassmorphism effects

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/study_bot_state.dart';
import '../utils/theme.dart';

class PremiumStudyPlanMenu extends StatefulWidget {
  final List<TableOfContentsItem>? tableOfContents;
  final int currentModule;
  final List<int>? completedModules;
  final Function(int, String)? onModuleEdit;
  final Function(int)? onModuleTap;
  final VoidCallback? onClose;
  final VoidCallback? onEditPlan;
  final double progressPercentage;
  final int? planVersion;
  final String? planTitle;
  final BuildContext context; // Add context for theme access

  const PremiumStudyPlanMenu({
    Key? key,
    this.tableOfContents,
    this.currentModule = 0,
    this.completedModules,
    this.onModuleEdit,
    this.onModuleTap,
    this.onClose,
    this.onEditPlan,
    this.progressPercentage = 0.0,
    this.planVersion,
    this.planTitle,
    required this.context, // Make context required
  }) : super(key: key);

  @override
  State<PremiumStudyPlanMenu> createState() => _PremiumStudyPlanMenuState();
}

class _PremiumStudyPlanMenuState extends State<PremiumStudyPlanMenu>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  late List<bool> _expandedModules;

  // Theme helper
  Color getTextColor(bool isDarkMode) =>
      isDarkMode ? Colors.white : Color(0xFF1F2937);
  Color getSecondaryTextColor(bool isDarkMode) =>
      isDarkMode ? Colors.white54 : Color(0xFF6B7280);
  Color getCardBackground(bool isDarkMode) =>
      isDarkMode ? Colors.white.withOpacity(0.08) : Color(0xFFF9FAFB);
  Color getCardBorder(bool isDarkMode) =>
      isDarkMode ? Colors.white.withOpacity(0.1) : Color(0xFFE5E7EB);
  Color getBgOpacity10(bool isDarkMode) => isDarkMode
      ? Colors.white.withOpacity(0.1)
      : Color(0xFF1F2937).withOpacity(0.1);
  Color getBgOpacity05(bool isDarkMode) => isDarkMode
      ? Colors.white.withOpacity(0.05)
      : Color(0xFF1F2937).withOpacity(0.05);

  @override
  void initState() {
    super.initState();
    _expandedModules = List<bool>.filled(
      widget.tableOfContents?.length ?? 0,
      false,
    );

    // Progress animation
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _progressAnimation =
        Tween<double>(begin: 0, end: widget.progressPercentage / 100).animate(
          CurvedAnimation(
            parent: _progressController,
            curve: Curves.easeOutCubic,
          ),
        );
    _progressController.forward();

    // Pulse animation for current module
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
                    AppTheme.backgroundGradientStartFromContext(widget.context),
                    AppTheme.backgroundGradientEndFromContext(widget.context),
                    AppTheme.surfaceCardFromContext(widget.context),
                  ]
                : [Color(0xFFF5F7FA), Color(0xFFF0F4F8), Color(0xFFE8F0FA)],
          ),
        ),
        child: Column(
          children: [
            _buildPremiumHeader(isDarkMode),
            Expanded(
              child:
                  widget.tableOfContents == null ||
                      widget.tableOfContents!.isEmpty
                  ? _buildEmptyState(isDarkMode)
                  : _buildModulesList(isDarkMode),
            ),
            _buildFooter(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(bool isDarkMode) {
    final totalModules = widget.tableOfContents?.length ?? 0;
    final completedCount = widget.completedModules?.length ?? 0;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  AppTheme.primaryBlue.withOpacity(0.3),
                  AppTheme.accentBlue.withOpacity(0.2),
                  AppTheme.accentBlue.withOpacity(0.1),
                ]
              : [
                  AppTheme.primaryBlue.withOpacity(0.1),
                  AppTheme.accentBlue.withOpacity(0.05),
                  Color(0xFFE0E9FF).withOpacity(0.5),
                ],
        ),
        border: Border(
          bottom: BorderSide(
            color: isDarkMode
                ? AppTheme.primaryBlue.withOpacity(0.3)
                : Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primaryBlue, AppTheme.accentBlue],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.auto_stories,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Study Plan',
                              style: TextStyle(
                                color: getTextColor(isDarkMode),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.planVersion != null)
                              Text(
                                'Version ${widget.planVersion}',
                                style: TextStyle(
                                  color: getSecondaryTextColor(isDarkMode),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Color(0xFF1F2937).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDarkMode ? Colors.white70 : Color(0xFF6B7280),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      widget.onClose?.call();
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            // Animated circular progress
            _buildAnimatedProgressCard(
              totalModules,
              completedCount,
              isDarkMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedProgressCard(
    int totalModules,
    int completedCount,
    bool isDarkMode,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.04)]
              : [
                  Color(0xFFF9FAFB).withOpacity(0.8),
                  Color(0xFFF3F4F6).withOpacity(0.6),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: getCardBorder(isDarkMode), width: 1),
      ),
      child: Row(
        children: [
          // Animated circular progress
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background circle
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 8,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDarkMode
                              ? Colors.white.withOpacity(0.1)
                              : Color(0xFFE5E7EB),
                        ),
                      ),
                    ),
                    // Progress circle
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: _progressAnimation.value,
                        strokeWidth: 8,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getProgressColor(widget.progressPercentage),
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    // Percentage text
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(widget.progressPercentage).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: getTextColor(isDarkMode),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Complete',
                          style: TextStyle(
                            color: getSecondaryTextColor(isDarkMode),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(width: 20),
          // Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow(
                  icon: Icons.check_circle,
                  iconColor: AppTheme.success,
                  label: 'Completed',
                  value: '$completedCount modules',
                  isDarkMode: isDarkMode,
                ),
                SizedBox(height: 8),
                _buildStatRow(
                  icon: Icons.pending,
                  iconColor: AppTheme.warning,
                  label: 'Remaining',
                  value: '${totalModules - completedCount} modules',
                  isDarkMode: isDarkMode,
                ),
                SizedBox(height: 8),
                _buildStatRow(
                  icon: Icons.play_circle_fill,
                  iconColor: AppTheme.primaryBlue,
                  label: 'Current',
                  value: 'Module ${widget.currentModule + 1}',
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDarkMode,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 14),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: getSecondaryTextColor(isDarkMode),
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: getTextColor(isDarkMode),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 80) return AppTheme.success;
    if (percentage >= 50) return AppTheme.primaryBlue;
    if (percentage >= 25) return AppTheme.warning;
    return AppTheme.accentBlue;
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode
                      ? [
                          AppTheme.primaryBlue.withOpacity(0.2),
                          AppTheme.accentBlue.withOpacity(0.1),
                        ]
                      : [
                          AppTheme.primaryBlue.withOpacity(0.1),
                          AppTheme.accentBlue.withOpacity(0.05),
                        ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_outlined,
                size: 48,
                color: AppTheme.primaryBlue,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Study Plan Yet',
              style: TextStyle(
                color: getTextColor(isDarkMode),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Your personalized study plan will appear here once your AI tutor creates one for you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: getSecondaryTextColor(isDarkMode),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(
                  isDarkMode ? 0.1 : 0.05,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(
                    isDarkMode ? 0.3 : 0.2,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Say "Create a study plan"',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'to get started',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModulesList(bool isDarkMode) {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.04)]
              : [
                  Color(0xFFF9FAFB).withOpacity(0.8),
                  Color(0xFFF3F4F6).withOpacity(0.6),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: getCardBorder(isDarkMode), width: 1),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [
                        AppTheme.accentBlue.withOpacity(0.2),
                        AppTheme.primaryBlue.withOpacity(0.1),
                      ]
                    : [
                        AppTheme.accentBlue.withOpacity(0.1),
                        AppTheme.primaryBlue.withOpacity(0.05),
                      ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.checklist, color: AppTheme.primaryBlue, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.planTitle ?? 'Study Plan',
                    style: TextStyle(
                      color: getTextColor(isDarkMode),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.completedModules?.length ?? 0}/${widget.tableOfContents?.length ?? 0} Complete',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Scrollable study plan content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    widget.tableOfContents?.asMap().entries.map((entry) {
                      final index = entry.key;
                      final toc = entry.value;
                      final isCompleted =
                          widget.completedModules?.contains(index) ?? false;
                      final isCurrent = widget.currentModule == index;

                      return _buildStudyPlanItem(
                        toc,
                        index,
                        isCompleted,
                        isCurrent,
                        isDarkMode,
                      );
                    }).toList() ??
                    [],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard(
    TableOfContentsItem toc,
    int index,
    bool isCompleted,
    bool isCurrent,
  ) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCurrent
              ? [
                  AppTheme.primaryBlue.withOpacity(0.15),
                  AppTheme.accentBlue.withOpacity(0.1),
                ]
              : isCompleted
              ? [
                  AppTheme.success.withOpacity(0.1),
                  AppTheme.success.withOpacity(0.05),
                ]
              : [
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.02),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? AppTheme.primaryBlue.withOpacity(0.4)
              : isCompleted
              ? AppTheme.success.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.2),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _expandedModules[index] = !_expandedModules[index];
            });
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Status indicator with animation
                    _buildStatusIndicator(index, isCompleted, isCurrent),
                    SizedBox(width: 14),
                    // Module info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            toc.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildTag(toc.estimatedTime, Icons.access_time),
                              _buildTag(
                                toc.difficultyLevel,
                                Icons.signal_cellular_alt,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Expand icon
                    AnimatedRotation(
                      turns: _expandedModules[index] ? 0.5 : 0,
                      duration: Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
                // Expanded content
                AnimatedCrossFade(
                  firstChild: SizedBox.shrink(),
                  secondChild: _buildExpandedContent(toc),
                  crossFadeState: _expandedModules[index]
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: Duration(milliseconds: 200),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(int index, bool isCompleted, bool isCurrent) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: isCompleted
                ? LinearGradient(
                    colors: [
                      AppTheme.success,
                      AppTheme.success.withOpacity(0.8),
                    ],
                  )
                : isCurrent
                ? LinearGradient(
                    colors: [AppTheme.accentBlue, AppTheme.primaryBlue],
                  )
                : null,
            color: !isCompleted && !isCurrent
                ? Colors.white.withOpacity(0.1)
                : null,
            shape: BoxShape.circle,
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withOpacity(
                        _pulseAnimation.value * 0.5,
                      ),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, color: Colors.white, size: 20)
                : isCurrent
                ? Icon(Icons.play_arrow, color: Colors.white, size: 20)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildTag(String text, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 12),
          SizedBox(width: 4),
          Text(text, style: TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(TableOfContentsItem toc) {
    return Padding(
      padding: EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          if (toc.description.isNotEmpty) ...[
            Text(
              toc.description,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            SizedBox(height: 12),
          ],
          // Subtopics
          if (toc.subtopics.isNotEmpty) ...[
            Text(
              'Key Topics',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: toc.subtopics.map((subtopic) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryBlue.withOpacity(0.15),
                        AppTheme.accentBlue.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    subtopic,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudyPlanItem(
    TableOfContentsItem toc,
    int index,
    bool isCompleted,
    bool isCurrent,
    bool isDarkMode,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isCurrent
            ? LinearGradient(
                colors: isDarkMode
                    ? [
                        AppTheme.primaryBlue.withOpacity(0.15),
                        AppTheme.accentBlue.withOpacity(0.1),
                      ]
                    : [
                        AppTheme.primaryBlue.withOpacity(0.08),
                        AppTheme.accentBlue.withOpacity(0.05),
                      ],
              )
            : isCompleted
            ? LinearGradient(
                colors: isDarkMode
                    ? [
                        AppTheme.success.withOpacity(0.1),
                        AppTheme.success.withOpacity(0.05),
                      ]
                    : [
                        AppTheme.success.withOpacity(0.08),
                        AppTheme.success.withOpacity(0.04),
                      ],
              )
            : LinearGradient(
                colors: isDarkMode
                    ? [
                        Colors.white.withOpacity(0.05),
                        Colors.white.withOpacity(0.02),
                      ]
                    : [
                        Color(0xFFF9FAFB).withOpacity(0.5),
                        Color(0xFFF3F4F6).withOpacity(0.3),
                      ],
              ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? (isDarkMode
                    ? AppTheme.primaryBlue.withOpacity(0.4)
                    : AppTheme.primaryBlue.withOpacity(0.3))
              : isCompleted
              ? (isDarkMode
                    ? AppTheme.success.withOpacity(0.3)
                    : AppTheme.success.withOpacity(0.2))
              : (isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Color(0xFFE5E7EB)),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          Container(
            margin: EdgeInsets.only(top: 2),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: isCompleted
                    ? LinearGradient(
                        colors: [
                          AppTheme.success,
                          AppTheme.success.withOpacity(0.8),
                        ],
                      )
                    : isCurrent
                    ? LinearGradient(
                        colors: [AppTheme.accentBlue, AppTheme.primaryBlue],
                      )
                    : null,
                color: !isCompleted && !isCurrent
                    ? (isDarkMode
                          ? Colors.white.withOpacity(0.2)
                          : Color(0xFF1F2937).withOpacity(0.1))
                    : null,
                shape: BoxShape.circle,
                border: !isCompleted && !isCurrent
                    ? Border.all(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.3)
                            : Color(0xFFD1D5DB),
                        width: 2,
                      )
                    : null,
              ),
              child: Center(
                child: isCompleted
                    ? Icon(Icons.check, color: Colors.white, size: 16)
                    : isCurrent
                    ? Icon(Icons.play_arrow, color: Colors.white, size: 16)
                    : SizedBox.shrink(),
              ),
            ),
          ),
          SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  toc.title,
                  style: TextStyle(
                    color: getTextColor(isDarkMode),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: AppTheme.success,
                    decorationThickness: 2,
                  ),
                ),
                SizedBox(height: 8),
                // Description/Objective
                Text(
                  toc.description ??
                      'Complete this module to advance your learning',
                  style: TextStyle(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.8)
                        : Color(0xFF6B7280),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 8),
                // Tags
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildInfoChip(
                      toc.estimatedTime ?? '30 min',
                      Icons.access_time,
                      isCompleted,
                      isDarkMode,
                    ),
                    _buildInfoChip(
                      toc.difficultyLevel ?? 'Medium',
                      Icons.signal_cellular_alt,
                      isCompleted,
                      isDarkMode,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tap to focus
          if (!isCompleted)
            IconButton(
              icon: Icon(
                Icons.arrow_forward,
                color: isCurrent
                    ? AppTheme.primaryBlue
                    : (isDarkMode
                          ? Colors.white.withOpacity(0.5)
                          : Color(0xFF9CA3AF)),
                size: 20,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                widget.onModuleTap?.call(index);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    String text,
    IconData icon,
    bool isCompleted,
    bool isDarkMode,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppTheme.success.withOpacity(0.2)
            : (isDarkMode
                  ? Colors.white.withOpacity(0.08)
                  : Color(0xFFE5E7EB).withOpacity(0.5)),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCompleted
              ? AppTheme.success.withOpacity(0.3)
              : (isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isCompleted
                ? AppTheme.success
                : (isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : Color(0xFF6B7280)),
            size: 12,
          ),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: isCompleted
                  ? AppTheme.success
                  : (isDarkMode
                        ? Colors.white.withOpacity(0.8)
                        : Color(0xFF6B7280)),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [Colors.white.withOpacity(0.05), Colors.transparent]
              : [Color(0xFFF9FAFB).withOpacity(0.5), Colors.transparent],
        ),
        border: Border(
          top: BorderSide(color: getCardBorder(isDarkMode), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _buildFooterButton(
                icon: Icons.close,
                label: 'Close',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                isPrimary: false,
                isDarkMode: isDarkMode,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildFooterButton(
                icon: Icons.edit,
                label: 'Edit Plan',
                onTap:
                    widget.tableOfContents != null &&
                        widget.tableOfContents!.isNotEmpty
                    ? () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context);
                        widget.onEditPlan?.call();
                      }
                    : null,
                isPrimary: true,
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool isPrimary,
    required bool isDarkMode,
  }) {
    final isEnabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: isPrimary && isEnabled
                ? LinearGradient(
                    colors: [AppTheme.accentBlue, AppTheme.primaryBlue],
                  )
                : null,
            color: !isPrimary
                ? (isDarkMode
                      ? Colors.white.withOpacity(0.08)
                      : Color(0xFFF3F4F6))
                : !isEnabled
                ? (isDarkMode
                      ? Colors.white.withOpacity(0.05)
                      : Color(0xFFE5E7EB).withOpacity(0.5))
                : null,
            borderRadius: BorderRadius.circular(12),
            border: !isPrimary
                ? Border.all(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.2)
                        : Color(0xFFD1D5DB),
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isEnabled
                    ? (isPrimary ? Colors.white : getTextColor(isDarkMode))
                    : (isDarkMode ? Colors.white38 : Color(0xFFC1C5CA)),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isEnabled
                      ? (isPrimary ? Colors.white : getTextColor(isDarkMode))
                      : (isDarkMode ? Colors.white38 : Color(0xFFC1C5CA)),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
