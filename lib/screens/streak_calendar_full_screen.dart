import 'package:flutter/material.dart';
import '../services/study_activity_service.dart';
import '../services/streak_calendar_service.dart';
import '../utils/theme.dart';
import '../utils/app_localizations.dart';
import '../widgets/streak_calendar_grid.dart';

/// Premium full-screen streak calendar with heavy animations
class StreakCalendarFullScreen extends StatefulWidget {
  const StreakCalendarFullScreen({Key? key}) : super(key: key);

  @override
  State<StreakCalendarFullScreen> createState() =>
      _StreakCalendarFullScreenState();
}

class _StreakCalendarFullScreenState extends State<StreakCalendarFullScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerSlideController;
  late AnimationController _flameGlowController;
  late AnimationController _statsSlideController;
  late AnimationController _gridSlideController;

  late Animation<Offset> _headerSlideAnimation;
  late Animation<double> _flameGlowAnimation;
  late Animation<Offset> _statsSlideAnimation;
  late Animation<Offset> _gridSlideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Header slide down animation
    _headerSlideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _headerSlideAnimation =
        Tween<Offset>(begin: Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _headerSlideController,
            curve: Curves.easeOut,
          ),
        );

    // Flame glow breathing animation
    _flameGlowController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _flameGlowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _flameGlowController, curve: Curves.easeInOut),
    );

    // Stats slide up animation
    _statsSlideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _statsSlideAnimation = Tween<Offset>(begin: Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _statsSlideController, curve: Curves.easeOut),
        );

    // Grid slide up animation (staggered)
    _gridSlideController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _gridSlideAnimation = Tween<Offset>(begin: Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _gridSlideController, curve: Curves.easeOut),
        );

    // Start animations with stagger
    _headerSlideController.forward();
    Future.delayed(Duration(milliseconds: 200), () {
      if (mounted) _statsSlideController.forward();
    });
    Future.delayed(Duration(milliseconds: 400), () {
      if (mounted) _gridSlideController.forward();
    });
  }

  @override
  void dispose() {
    _headerSlideController.dispose();
    _flameGlowController.dispose();
    _statsSlideController.dispose();
    _gridSlideController.dispose();
    super.dispose();
  }

  String _formatLastActivity(DateTime? dateTime) {
    if (dateTime == null) return 'Never';

    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String icon,
    required String label,
    required String value,
    required bool isPrimary,
  }) {
    final primaryColor = AppTheme.primaryBlue;
    final accentColor = AppTheme.accentBlue;

    return GestureDetector(
      onTap: () {
        _statsSlideController.reverse().then((_) {
          _statsSlideController.forward();
        });
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withOpacity(0.4), width: 1),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.2),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPrimary
                ? [primaryColor, accentColor.withOpacity(0.8)]
                : [AppTheme.primaryBlueDark, primaryColor],
          ),
        ),
        child: Column(
          children: [
            Text(icon, style: TextStyle(fontSize: 40)),
            SizedBox(height: 12),
            Text(
              value,
              style: AppTheme.headlineLargeFromContext(
                context,
              ).copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: AppTheme.labelSmallFromContext(
                context,
              ).copyWith(color: Colors.white.withOpacity(0.8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCardsContent(
    BuildContext context,
    StudyStats stats,
    bool isDark,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            icon: '🔥',
            label: AppLocalizations.of(context).t('streak.currentStreak'),
            value: '${stats.currentStreak}',
            isPrimary: true,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            context,
            icon: '⭐',
            label: AppLocalizations.of(context).t('streak.longestStreak'),
            value: '${stats.longestStreak}',
            isPrimary: false,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return FutureBuilder<StudyStats>(
      future: StudyActivityService().getStudyStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(height: 200, child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        final primaryColor = AppTheme.primaryBlue;
        final accentColor = AppTheme.accentBlue;

        return Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor.withOpacity(0.1),
                primaryColor.withOpacity(0.05),
              ],
            ),
            border: Border.all(color: accentColor.withOpacity(0.2), width: 1),
          ),
          child: Column(
            children: [
              // Flame emoji with breathing glow
              AnimatedBuilder(
                animation: _flameGlowAnimation,
                builder: (context, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow effect
                      Container(
                        width: 130 + (_flameGlowAnimation.value * 20),
                        height: 130 + (_flameGlowAnimation.value * 20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(
                                _flameGlowAnimation.value,
                              ),
                              blurRadius: 40 + (_flameGlowAnimation.value * 20),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      ),
                      // Flame emoji
                      Text('🔥', style: TextStyle(fontSize: 100)),
                    ],
                  );
                },
              ),
              SizedBox(height: 24),
              // Streak count and message
              Text(
                '${stats.currentStreak}',
                style: AppTheme.displayLargeFromContext(
                  context,
                ).copyWith(color: accentColor),
              ),
              SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).t('streak.daysInARow'),
                style: AppTheme.bodyLargeFromContext(
                  context,
                ).copyWith(color: AppTheme.textSecondaryFromContext(context)),
              ),
              SizedBox(height: 16),
              // Last activity time
              Text(
                'Last activity: ${_formatLastActivity(stats.lastStudyTime)}',
                style: AppTheme.bodySmallFromContext(
                  context,
                ).copyWith(color: AppTheme.textTertiaryFromContext(context)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendarSection(BuildContext context) {
    return FutureBuilder<StudyStats>(
      future: StudyActivityService().getStudyStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(height: 300, child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        final streakData = StreakCalendarService.generateCalendarData(
          currentStreak: stats.currentStreak,
          longestStreak: stats.longestStreak,
          lastActivityDate: stats.lastStudyTime ?? DateTime.now(),
        );
        final weeks = StreakCalendarService.generateWeekData(streakData);

        return StreakCalendarGrid(calendarData: streakData, weeks: weeks);
      },
    );
  }

  Widget _buildMonthStats(BuildContext context, bool isDark) {
    return FutureBuilder<StudyStats>(
      future: StudyActivityService().getStudyStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(height: 200);
        }

        final stats = snapshot.data!;
        final streakData = StreakCalendarService.generateCalendarData(
          currentStreak: stats.currentStreak,
          longestStreak: stats.longestStreak,
          lastActivityDate: stats.lastStudyTime ?? DateTime.now(),
        );
        final monthStats = StreakCalendarService.getMonthStats(
          calendarData: streakData,
          currentStreak: stats.currentStreak,
          longestStreak: stats.longestStreak,
        );
        final accentColor = AppTheme.accentBlue;

        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCardFromContext(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text('📊', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 12),
                  Text(
                    'This Month',
                    style: AppTheme.bodyLargeFromContext(
                      context,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Divider(color: accentColor.withOpacity(0.2)),
              SizedBox(height: 16),
              // Stats rows
              _buildStatRow(
                context,
                label: 'Days studied',
                value: '${monthStats.daysStudied} / ${monthStats.totalDays}',
              ),
              SizedBox(height: 12),
              _buildStatRow(
                context,
                label: 'Best streak',
                value: '${monthStats.currentStreak} days',
              ),
              SizedBox(height: 12),
              _buildStatRow(
                context,
                label: 'Consistency',
                value: '${monthStats.consistencyPercentage}%',
              ),
              SizedBox(height: 20),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: monthStats.totalDays > 0
                      ? monthStats.daysStudied / monthStats.totalDays
                      : 0,
                  backgroundColor: AppTheme.surfaceElevatedFromContext(context),
                  valueColor: AlwaysStoppedAnimation(accentColor),
                  minHeight: 8,
                ),
              ),
              SizedBox(height: 20),
              // Motivational message
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.surfaceElevatedFromContext(context),
                  border: Border.all(color: accentColor.withOpacity(0.5)),
                ),
                child: Center(
                  child: Text(
                    StreakCalendarService.getMotivationalMessage(
                      monthStats.currentStreak,
                    ),
                    style: AppTheme.bodyMediumFromContext(
                      context,
                    ).copyWith(color: accentColor, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final accentColor = AppTheme.accentBlue;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.bodyMediumFromContext(
            context,
          ).copyWith(color: AppTheme.textSecondaryFromContext(context)),
        ),
        Text(
          value,
          style: AppTheme.bodyMediumFromContext(
            context,
          ).copyWith(color: accentColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        '${AppLocalizations.of(context).t('streak.dailyStreak')} 🔥',
        style: AppTheme.headlineLargeFromContext(context),
      ),
      centerTitle: true,
      actions: [
        PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(value: 'settings', child: Text('Settings')),
          ],
          onSelected: (value) {
            if (value == 'settings') {
              // Handle settings
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Header section with flame + current streak
          SlideTransition(
            position: _headerSlideAnimation,
            child: _buildHeaderSection(context),
          ),
          SizedBox(height: 32),
          // Stats cards (current + longest)
          SlideTransition(
            position: _statsSlideAnimation,
            child: FutureBuilder<StudyStats>(
              future: StudyActivityService().getStudyStats(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return SizedBox(height: 120);
                }
                final stats = snapshot.data!;
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return _buildStatsCardsContent(context, stats, isDark);
              },
            ),
          ),
          SizedBox(height: 32),
          // Calendar grid
          SlideTransition(
            position: _gridSlideAnimation,
            child: _buildCalendarSection(context),
          ),
          SizedBox(height: 32),
          // Month stats
          SlideTransition(
            position: _gridSlideAnimation,
            child: _buildMonthStats(
              context,
              Theme.of(context).brightness == Brightness.dark,
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}
