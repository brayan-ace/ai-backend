import 'package:flutter/material.dart';

import 'dart:math';
import '../utils/theme.dart';
import '../services/analytics_service.dart';
import '../services/push_notification_service.dart';
import '../services/gamification_service.dart';
import '../widgets/premium_chart_widget.dart';

/// Premium Analytics Dashboard Screen
/// Displays comprehensive learning analytics and insights
class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen>
    with TickerProviderStateMixin {
  final AnalyticsService _analyticsService = AnalyticsService();
  final PushNotificationService _notificationService =
      PushNotificationService();
  final GamificationService _gamificationService = GamificationService();

  Map<String, dynamic> _analyticsData = {};
  List<String> _insights = [];
  Map<String, dynamic> _gamificationData = {};
  List<Map<String, dynamic>> _leaderboard = [];
  List<Map<String, dynamic>> _recentAchievements = [];

  bool _isLoading = true;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _achievementController;
  late Animation<double> _achievementAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _achievementController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _achievementAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _achievementController, curve: Curves.elasticOut),
    );

    _loadAnalytics();
    _loadGamificationData();
    _loadLeaderboard();
    _loadRecentAchievements();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final analytics = await _analyticsService.getLearningAnalytics();
      final insights = await _analyticsService.generatePersonalizedInsights();

      setState(() {
        _analyticsData = analytics;
        _insights = insights;
        _isLoading = false;
      });

      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      print('[AnalyticsDashboard] Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGamificationData() async {
    try {
      final data = _gamificationService.getUserStats();
      setState(() {
        _gamificationData = data;
      });
      _achievementController.forward();
    } catch (e) {
      print('[AnalyticsDashboard] Error loading gamification data: $e');
    }
  }

  Future<void> _loadLeaderboard() async {
    try {
      final leaderboard = await _gamificationService.getLeaderboard(type: 'xp');
      setState(() {
        _leaderboard = leaderboard;
      });
    } catch (e) {
      print('[AnalyticsDashboard] Error loading leaderboard: $e');
    }
  }

  Future<void> _loadRecentAchievements() async {
    try {
      // Simulate loading recent achievements
      final achievements = [
        {
          'title': 'Level Up!',
          'description': 'You reached level 5!',
          'icon': '🎉',
          'xp': 500,
          'date': DateTime.now().subtract(Duration(days: 1)),
        },
        {
          'title': 'Quiz Master',
          'description': 'Completed 10 quizzes with 90%+ accuracy',
          'icon': '🧠',
          'xp': 300,
          'date': DateTime.now().subtract(Duration(days: 3)),
        },
        {
          'title': 'Streak Warrior',
          'description': '7-day learning streak achieved',
          'icon': '🔥',
          'xp': 350,
          'date': DateTime.now().subtract(Duration(days: 7)),
        },
      ];
      setState(() {
        _recentAchievements = achievements;
      });
    } catch (e) {
      print('[AnalyticsDashboard] Error loading achievements: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _achievementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGradientStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Learning Analytics',
          style: AppTheme.headlineMedium.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.primaryBlue),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            )
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              color: AppTheme.primaryBlue,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.spaceMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Stats
                        _buildHeaderStats(),
                        const SizedBox(height: AppTheme.spaceLg),

                        // Learning Progress Chart
                        _buildLearningProgressChart(),
                        const SizedBox(height: AppTheme.spaceLg),

                        // Key Metrics Grid
                        _buildMetricsGrid(),
                        const SizedBox(height: AppTheme.spaceLg),

                        // Personalized Insights
                        _buildInsightsSection(),
                        const SizedBox(height: AppTheme.spaceLg),

                        // Activity Patterns
                        _buildActivityPatterns(),
                        const SizedBox(height: AppTheme.spaceLg),

                        // Achievement Highlights
                        _buildAchievementHighlights(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderStats() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppTheme.primaryGradient),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.white, size: 28),
              SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Learning Journey',
                      style: AppTheme.headlineMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Track your progress and achievements',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Study Streak',
                  '${_analyticsData['learning_streak'] ?? 0}',
                  '🔥',
                  Colors.white,
                ),
              ),
              SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: _buildStatCard(
                  'Total Sessions',
                  '${_analyticsData['total_sessions'] ?? 0}',
                  '📚',
                  Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String emoji, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(emoji, style: TextStyle(fontSize: 24)),
          SizedBox(height: 4),
          Text(
            value,
            style: AppTheme.headlineSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: AppTheme.bodySmall.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningProgressChart() {
    return _buildSectionCard(
      title: '📈 Learning Progress',
      child: Container(
        height: 200,
        child: PremiumChartWidget(
          data: _generateChartData(),
          type: ChartType.line,
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Metrics',
          style: AppTheme.headlineSmall.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: AppTheme.spaceMd,
          mainAxisSpacing: AppTheme.spaceMd,
          childAspectRatio: 1.5,
          children: [
            _buildMetricCard(
              'Study Time',
              '${(_analyticsData['total_study_time'] ?? 0) ~/ 60}h',
              Icons.access_time,
              AppTheme.primaryBlue,
            ),
            _buildMetricCard(
              'Avg Session',
              '${(_analyticsData['average_session_length'] ?? 0).toInt()}m',
              Icons.timer,
              AppTheme.accentBlue,
            ),
            _buildMetricCard(
              'Quiz Accuracy',
              '${((_analyticsData['quiz_accuracy'] ?? 0) * 100).toInt()}%',
              Icons.quiz,
              AppTheme.success,
            ),
            _buildMetricCard(
              'Concepts Learned',
              '${(_analyticsData['concepts_learned']?.length ?? 0)}',
              Icons.psychology,
              AppTheme.warning,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: AppTheme.spaceSm),
          Text(
            value,
            style: AppTheme.headlineSmall.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    return _buildSectionCard(
      title: '💡 Personalized Insights',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._insights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                    SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: Text(
                        insight,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityPatterns() {
    return _buildSectionCard(
      title: '📊 Activity Patterns',
      child: Column(
        children: [
          _buildPatternRow(
            'Most Active Day',
            _analyticsData['most_active_day'] ?? 'Monday',
            Icons.calendar_today,
          ),
          SizedBox(height: AppTheme.spaceMd),
          _buildPatternRow(
            'Preferred Time',
            _analyticsData['preferred_time'] ?? 'evening',
            Icons.schedule,
          ),
          SizedBox(height: AppTheme.spaceMd),
          _buildPatternRow(
            'Learning Velocity',
            '${((_analyticsData['learning_velocity'] ?? 0) * 100).toInt()}%',
            Icons.speed,
          ),
        ],
      ),
    );
  }

  Widget _buildPatternRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.accentBlue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.accentBlue, size: 20),
        ),
        SizedBox(width: AppTheme.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                value,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementHighlights() {
    return _buildSectionCard(
      title: '🏆 Recent Achievements',
      child: Container(
        height: 120,
        child: PremiumChartWidget(
          data: _generateAchievementData(),
          type: ChartType.bar,
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      padding: const EdgeInsets.all(AppTheme.spaceLg),
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
          Text(
            title,
            style: AppTheme.headlineSmall.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppTheme.spaceMd),
          child,
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _generateChartData() {
    // Generate sample data for the last 7 days
    List<Map<String, dynamic>> data = [];
    DateTime now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      DateTime date = now.subtract(Duration(days: i));
      data.add({
        'day': _getDayName(date.weekday),
        'value': Random().nextInt(60) + 20, // Random study minutes
        'date': date,
      });
    }

    return data;
  }

  List<Map<String, dynamic>> _generateAchievementData() {
    return [
      {'category': 'Quizzes', 'value': 85, 'color': AppTheme.success},
      {'category': 'Concepts', 'value': 92, 'color': AppTheme.primaryBlue},
      {'category': 'Sessions', 'value': 78, 'color': AppTheme.accentBlue},
      {'category': 'Streak', 'value': 95, 'color': AppTheme.warning},
    ];
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return 'Mon';
    }
  }
}
