import 'package:flutter/material.dart';

/// Settings widget for spaced repetition parameters
class SpacedRepetitionSettingsWidget extends StatefulWidget {
  final int defaultDailyGoal;
  final double defaultEasinessFactor;
  final int minimumEasinessFactor;
  final Function(SpacedRepetitionPreferences)? onPreferencesChanged;

  const SpacedRepetitionSettingsWidget({
    Key? key,
    this.defaultDailyGoal = 10,
    this.defaultEasinessFactor = 2.5,
    this.minimumEasinessFactor = 1,
    this.onPreferencesChanged,
  }) : super(key: key);

  @override
  State<SpacedRepetitionSettingsWidget> createState() =>
      _SpacedRepetitionSettingsWidgetState();
}

class _SpacedRepetitionSettingsWidgetState
    extends State<SpacedRepetitionSettingsWidget> {
  late int dailyGoal;
  late double easinessFactor;
  late bool enableNotifications;
  late String difficulty;
  late bool adaptivePacing;

  @override
  void initState() {
    super.initState();
    dailyGoal = widget.defaultDailyGoal;
    easinessFactor = widget.defaultEasinessFactor;
    enableNotifications = true;
    difficulty = 'medium';
    adaptivePacing = true;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Daily Goal Setting
          _SettingSection(
            icon: '🎯',
            title: 'Daily Review Goal',
            description: 'Target number of reviews per day',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border.all(color: Colors.blue[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$dailyGoal reviews/day',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '~${dailyGoal * 5} min',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Slider(
                  value: dailyGoal.toDouble(),
                  min: 5,
                  max: 30,
                  divisions: 5,
                  label: '$dailyGoal',
                  onChanged: (value) {
                    setState(() {
                      dailyGoal = value.toInt();
                      _notifyPreferencesChanged();
                    });
                  },
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '5 (Light)',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      Text(
                        '30 (Ambitious)',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // Learning Difficulty
          _SettingSection(
            icon: '📈',
            title: 'Learning Difficulty',
            description: 'Adjust interval spacing based on difficulty',
            child: Column(
              children: [
                _DifficultyOption(
                  value: 'easy',
                  label: 'Easy',
                  description: 'Quick reviews, shorter intervals',
                  isSelected: difficulty == 'easy',
                  onTap: () {
                    setState(() {
                      difficulty = 'easy';
                      easinessFactor = 2.2;
                      _notifyPreferencesChanged();
                    });
                  },
                ),
                SizedBox(height: 8),
                _DifficultyOption(
                  value: 'medium',
                  label: 'Medium',
                  description: 'Balanced approach',
                  isSelected: difficulty == 'medium',
                  onTap: () {
                    setState(() {
                      difficulty = 'medium';
                      easinessFactor = 2.5;
                      _notifyPreferencesChanged();
                    });
                  },
                ),
                SizedBox(height: 8),
                _DifficultyOption(
                  value: 'hard',
                  label: 'Hard',
                  description: 'Longer intervals, thorough retention',
                  isSelected: difficulty == 'hard',
                  onTap: () {
                    setState(() {
                      difficulty = 'hard';
                      easinessFactor = 2.8;
                      _notifyPreferencesChanged();
                    });
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // Adaptive Pacing
          _SettingSection(
            icon: '🔄',
            title: 'Adaptive Pacing',
            description: 'Automatically adjust intervals based on performance',
            child: _ToggleSetting(
              value: adaptivePacing,
              onChanged: (value) {
                setState(() {
                  adaptivePacing = value;
                  _notifyPreferencesChanged();
                });
              },
            ),
          ),
          SizedBox(height: 20),

          // Notifications
          _SettingSection(
            icon: '🔔',
            title: 'Daily Notifications',
            description: 'Get reminders to complete your reviews',
            child: _ToggleSetting(
              value: enableNotifications,
              onChanged: (value) {
                setState(() {
                  enableNotifications = value;
                  _notifyPreferencesChanged();
                });
              },
            ),
          ),
          SizedBox(height: 20),

          // Info Box
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              border: Border.all(color: Colors.amber[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('💡', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Text(
                      'Spaced Repetition Tips',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[900],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '• Complete reviews daily for best results\n'
                  '• Quality of review matters more than quantity\n'
                  '• Take breaks between reviews\n'
                  '• Consistency beats intensity',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber[900],
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _notifyPreferencesChanged() {
    widget.onPreferencesChanged?.call(
      SpacedRepetitionPreferences(
        dailyGoal: dailyGoal,
        easinessFactor: easinessFactor,
        enableNotifications: enableNotifications,
        difficulty: difficulty,
        adaptivePacing: adaptivePacing,
      ),
    );
  }
}

class _SettingSection extends StatelessWidget {
  final String icon;
  final String title;
  final String description;
  final Widget child;

  const _SettingSection({
    Key? key,
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DifficultyOption extends StatelessWidget {
  final String value;
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _DifficultyOption({
    Key? key,
    required this.value,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.grey[50],
          border: Border.all(
            color: isSelected ? Colors.blue[300]! : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.grey[300],
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey[400]!,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.blue[700] : Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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

class _ToggleSetting extends StatelessWidget {
  final bool value;
  final Function(bool)? onChanged;

  const _ToggleSetting({Key? key, required this.value, this.onChanged})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          value ? '✅ Enabled' : '⏸️ Disabled',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: value ? Colors.green : Colors.grey[600],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.green,
          inactiveThumbColor: Colors.grey[300],
        ),
      ],
    );
  }
}

/// Data class for spaced repetition preferences
class SpacedRepetitionPreferences {
  final int dailyGoal;
  final double easinessFactor;
  final bool enableNotifications;
  final String difficulty;
  final bool adaptivePacing;

  SpacedRepetitionPreferences({
    required this.dailyGoal,
    required this.easinessFactor,
    required this.enableNotifications,
    required this.difficulty,
    required this.adaptivePacing,
  });

  Map<String, dynamic> toJson() => {
    'dailyGoal': dailyGoal,
    'easinessFactor': easinessFactor,
    'enableNotifications': enableNotifications,
    'difficulty': difficulty,
    'adaptivePacing': adaptivePacing,
  };

  factory SpacedRepetitionPreferences.fromJson(Map<String, dynamic> json) =>
      SpacedRepetitionPreferences(
        dailyGoal: json['dailyGoal'] as int? ?? 10,
        easinessFactor: json['easinessFactor'] as double? ?? 2.5,
        enableNotifications: json['enableNotifications'] as bool? ?? true,
        difficulty: json['difficulty'] as String? ?? 'medium',
        adaptivePacing: json['adaptivePacing'] as bool? ?? true,
      );
}

/// Badge widget showing current spaced repetition status
class SpacedRepetitionStatusBadge extends StatelessWidget {
  final int dueToday;
  final int overdue;
  final int totalScheduled;

  const SpacedRepetitionStatusBadge({
    Key? key,
    required this.dueToday,
    required this.overdue,
    required this.totalScheduled,
  }) : super(key: key);

  Color _getStatusColor() {
    if (overdue > 0) return Colors.red;
    if (dueToday > 0) return Colors.orange;
    return Colors.green;
  }

  String _getStatusMessage() {
    if (overdue > 0) return '$overdue concepts overdue';
    if (dueToday > 0) return '$dueToday due today';
    return 'All caught up!';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        border: Border.all(color: _getStatusColor().withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            overdue > 0
                ? '⚠️'
                : dueToday > 0
                ? '📚'
                : '✅',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(width: 6),
          Text(
            _getStatusMessage(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _getStatusColor(),
            ),
          ),
        ],
      ),
    );
  }
}
