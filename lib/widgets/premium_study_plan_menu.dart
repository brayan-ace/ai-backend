/// Premium Study Plan Hamburger Menu Widget
/// A beautiful, animated study plan viewer with glassmorphism effects

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../models/study_bot_state.dart';
import '../utils/theme.dart';

class PremiumColors {
  static const Color darkBg = Color(0xFF0a0a0a);
  static const Color darkBg2 = Color(0xFF1a1a2e);
  static const Color accentGradient1 = Color(0xFF6366f1);
  static const Color accentGradient2 = Color(0xFF8b5cf6);
  static const Color accentGradient3 = Color(0xFF3b82f6);
  static const Color cardBg = Color(0xFF111827);
  static const Color successGreen = Color(0xFF10b981);
  static const Color warningOrange = Color(0xFFf59e0b);
}

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
    _progressAnimation = Tween<double>(
      begin: 0,
      end: widget.progressPercentage / 100,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));
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
    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PremiumColors.darkBg,
              PremiumColors.darkBg2,
              PremiumColors.cardBg,
            ],
          ),
        ),
        child: Column(
          children: [
            _buildPremiumHeader(),
            Expanded(
              child: widget.tableOfContents == null ||
                      widget.tableOfContents!.isEmpty
                  ? _buildEmptyState()
                  : _buildModulesList(),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    final totalModules = widget.tableOfContents?.length ?? 0;
    final completedCount = widget.completedModules?.length ?? 0;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PremiumColors.accentGradient2.withOpacity(0.3),
            PremiumColors.accentGradient1.withOpacity(0.2),
            PremiumColors.accentGradient3.withOpacity(0.1),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: PremiumColors.accentGradient1.withOpacity(0.3),
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
                            colors: [
                              PremiumColors.accentGradient2,
                              PremiumColors.accentGradient1,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: PremiumColors.accentGradient2.withOpacity(0.4),
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
                                color: Colors.white,
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
                                  color: Colors.white54,
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
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.white70),
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
            _buildAnimatedProgressCard(totalModules, completedCount),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedProgressCard(int totalModules, int completedCount) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
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
                          Colors.white.withOpacity(0.1),
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
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Complete',
                          style: TextStyle(
                            color: Colors.white54,
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
                  iconColor: PremiumColors.successGreen,
                  label: 'Completed',
                  value: '$completedCount modules',
                ),
                SizedBox(height: 8),
                _buildStatRow(
                  icon: Icons.pending,
                  iconColor: PremiumColors.warningOrange,
                  label: 'Remaining',
                  value: '${totalModules - completedCount} modules',
                ),
                SizedBox(height: 8),
                _buildStatRow(
                  icon: Icons.play_circle_fill,
                  iconColor: PremiumColors.accentGradient1,
                  label: 'Current',
                  value: 'Module ${widget.currentModule + 1}',
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
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 14),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(color: Colors.white54, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 80) return PremiumColors.successGreen;
    if (percentage >= 50) return PremiumColors.accentGradient1;
    if (percentage >= 25) return PremiumColors.warningOrange;
    return PremiumColors.accentGradient2;
  }

  Widget _buildEmptyState() {
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
                  colors: [
                    PremiumColors.accentGradient2.withOpacity(0.2),
                    PremiumColors.accentGradient1.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_outlined,
                size: 48,
                color: PremiumColors.accentGradient1,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Study Plan Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Your personalized study plan will appear here once your AI tutor creates one for you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: PremiumColors.accentGradient1.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: PremiumColors.accentGradient1.withOpacity(0.3),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: PremiumColors.accentGradient1,
                    size: 20,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Say "Create a study plan"',
                    style: TextStyle(
                      color: PremiumColors.accentGradient1,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'to get started',
                    style: TextStyle(
                      color: PremiumColors.accentGradient1,
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

  Widget _buildModulesList() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: widget.tableOfContents!.length,
      itemBuilder: (context, index) {
        final toc = widget.tableOfContents![index];
        final isCompleted = widget.completedModules?.contains(index) ?? false;
        final isCurrent = widget.currentModule == index;

        return _buildModuleCard(toc, index, isCompleted, isCurrent);
      },
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
                  PremiumColors.accentGradient1.withOpacity(0.15),
                  PremiumColors.accentGradient2.withOpacity(0.1),
                ]
              : isCompleted
                  ? [
                      PremiumColors.successGreen.withOpacity(0.1),
                      PremiumColors.successGreen.withOpacity(0.05),
                    ]
                  : [
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.02),
                    ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? PremiumColors.accentGradient1.withOpacity(0.4)
              : isCompleted
                  ? PremiumColors.successGreen.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: PremiumColors.accentGradient1.withOpacity(0.2),
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
                              _buildTag(
                                toc.estimatedTime,
                                Icons.access_time,
                              ),
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
                      PremiumColors.successGreen,
                      PremiumColors.successGreen.withOpacity(0.8),
                    ],
                  )
                : isCurrent
                    ? LinearGradient(
                        colors: [
                          PremiumColors.accentGradient2,
                          PremiumColors.accentGradient1,
                        ],
                      )
                    : null,
            color: !isCompleted && !isCurrent
                ? Colors.white.withOpacity(0.1)
                : null,
            shape: BoxShape.circle,
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: PremiumColors.accentGradient1
                          .withOpacity(_pulseAnimation.value * 0.5),
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
          Text(
            text,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
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
                        PremiumColors.accentGradient1.withOpacity(0.15),
                        PremiumColors.accentGradient2.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: PremiumColors.accentGradient1.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    subtopic,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.transparent,
          ],
        ),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
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
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildFooterButton(
                icon: Icons.edit,
                label: 'Edit Plan',
                onTap: widget.tableOfContents != null &&
                        widget.tableOfContents!.isNotEmpty
                    ? () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context);
                        widget.onEditPlan?.call();
                      }
                    : null,
                isPrimary: true,
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
                    colors: [
                      PremiumColors.accentGradient2,
                      PremiumColors.accentGradient1,
                    ],
                  )
                : null,
            color: !isPrimary
                ? Colors.white.withOpacity(0.08)
                : !isEnabled
                    ? Colors.white.withOpacity(0.05)
                    : null,
            borderRadius: BorderRadius.circular(12),
            border: !isPrimary
                ? Border.all(color: Colors.white.withOpacity(0.2))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isEnabled ? Colors.white : Colors.white38,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isEnabled ? Colors.white : Colors.white38,
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
