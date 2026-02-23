import 'package:flutter/material.dart';
import '../services/spaced_repetition_service.dart';

/// Widget displaying spaced repetition review schedule
class ReviewScheduleWidget extends StatefulWidget {
  final List<ConceptReview> concepts;
  final Function(ConceptReview)? onReviewSelected;
  final int daysAhead;

  const ReviewScheduleWidget({
    Key? key,
    required this.concepts,
    this.onReviewSelected,
    this.daysAhead = 30,
  }) : super(key: key);

  @override
  State<ReviewScheduleWidget> createState() => _ReviewScheduleWidgetState();
}

class _ReviewScheduleWidgetState extends State<ReviewScheduleWidget> {
  late List<ScheduledReview> schedule;
  late SpacedRepetitionStats stats;

  @override
  void initState() {
    super.initState();
    _updateSchedule();
  }

  void _updateSchedule() {
    schedule = SpacedRepetitionService.generateReviewSchedule(
      concepts: widget.concepts,
      daysAhead: widget.daysAhead,
    );
    stats = SpacedRepetitionStats.fromConcepts(widget.concepts);
  }

  @override
  void didUpdateWidget(ReviewScheduleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.concepts != widget.concepts) {
      _updateSchedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Statistics cards
        Text(
          '📅 Review Schedule',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6366F1),
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Due Today',
                value: stats.reviewsToday.toString(),
                icon: '📖',
                backgroundColor: Colors.blue[50],
                borderColor: Colors.blue,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: StatCard(
                title: 'Overdue',
                value: stats.overdueConcepts.toString(),
                icon: '⚠️',
                backgroundColor: Colors.red[50],
                borderColor: Colors.red,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: StatCard(
                title: 'Mastery',
                value: '${stats.masteryPercentage.toStringAsFixed(0)}%',
                icon: '⭐',
                backgroundColor: Colors.green[50],
                borderColor: Colors.green,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),

        // Schedule list
        if (schedule.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Text(
                    '🎉 All caught up!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No reviews scheduled. Keep learning!',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: schedule.length,
            itemBuilder: (context, index) {
              final review = schedule[index];
              return ScheduledReviewCard(
                scheduledReview: review,
                onTap: widget.onReviewSelected,
              );
            },
          ),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String icon;
  final Color? backgroundColor;
  final Color? borderColor;

  const StatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    this.backgroundColor,
    this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[50],
        border: Border.all(color: borderColor ?? Colors.grey[300]!, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: TextStyle(fontSize: 20)),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: borderColor ?? Colors.grey[700],
            ),
          ),
          SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class ScheduledReviewCard extends StatelessWidget {
  final ScheduledReview scheduledReview;
  final Function(ConceptReview)? onTap;

  const ScheduledReviewCard({
    Key? key,
    required this.scheduledReview,
    this.onTap,
  }) : super(key: key);

  Color _getDateColor() {
    if (scheduledReview.isPastDue) return Colors.red;
    if (scheduledReview.isToday) return Colors.blue;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _getDateColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Text(
                  scheduledReview.isPastDue ? '⏰' : '📅',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(width: 8),
                Text(
                  scheduledReview.dateLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _getDateColor(),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getDateColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${scheduledReview.concepts.length} review${scheduledReview.concepts.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getDateColor(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          ...scheduledReview.concepts
              .map(
                (concept) => ConceptReviewTile(
                  concept: concept,
                  onTap: () => onTap?.call(concept),
                ),
              )
              .toList(),
        ],
      ),
    );
  }
}

class ConceptReviewTile extends StatelessWidget {
  final ConceptReview concept;
  final VoidCallback? onTap;

  const ConceptReviewTile({Key? key, required this.concept, this.onTap})
    : super(key: key);

  String _getStatus() {
    if (concept.reviewCount == 0) return 'New';
    if (concept.reviewCount == 1) return '1st Review';
    if (concept.reviewCount < 5) return '${concept.reviewCount}th Review';
    return 'Refresh';
  }

  Color _getStatusColor() {
    if (concept.reviewCount == 0) return Colors.blue;
    if (concept.reviewCount == 1) return Colors.orange;
    if (concept.isOverdue) return Colors.red;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(10),
        margin: EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: _getStatusColor(),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Concept ${concept.conceptIndex + 1}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withOpacity(0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          _getStatus(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      if (concept.daysUntilDue >= 0)
                        Text(
                          '📊 Easiness: ${concept.easinessFactor.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

/// Widget for showing spaced repetition insights
class SpacedRepetitionInsights extends StatelessWidget {
  final SpacedRepetitionStats stats;
  final int recommendedDaily;

  const SpacedRepetitionInsights({
    Key? key,
    required this.stats,
    required this.recommendedDaily,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💡 Spaced Repetition Insights',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          _InsightRow(
            icon: '📚',
            title: 'Total Concepts',
            value: '${stats.totalConcepts}',
            subtitle: 'in your study plan',
          ),
          _InsightRow(
            icon: '✅',
            title: 'Mastered',
            value: '${stats.conceptsMastered}',
            subtitle: '${stats.masteryPercentage.toStringAsFixed(0)}% complete',
          ),
          _InsightRow(
            icon: '🎯',
            title: 'Recommended Today',
            value: '$recommendedDaily reviews',
            subtitle: 'for optimal learning',
          ),
          if (stats.overdueConcepts > 0)
            _InsightRow(
              icon: '⚠️',
              title: 'Catch Up',
              value: '${stats.overdueConcepts}',
              subtitle: 'concepts overdue for review',
              isAlert: true,
            ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final String icon;
  final String title;
  final String value;
  final String subtitle;
  final bool isAlert;

  const _InsightRow({
    Key? key,
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    this.isAlert = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(icon, style: TextStyle(fontSize: 20)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isAlert ? Colors.yellow[200] : Colors.white60,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
