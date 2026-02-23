# SPACED REPETITION IMPLEMENTATION - QUICK REFERENCE CARD

## 📦 New Files Created

| File                                     | Type    | Lines | Purpose                                   |
| ---------------------------------------- | ------- | ----- | ----------------------------------------- |
| `checkpoint_quiz_service.dart`           | Service | 210   | API communication for quizzes & struggles |
| `checkpoint_quiz_widget.dart`            | Widget  | 380   | Interactive quiz UI + results display     |
| `struggle_detection_widget.dart`         | Widget  | 420   | Struggle alerts + analytics dashboard     |
| `review_schedule_widget.dart`            | Widget  | 450   | Calendar view of upcoming reviews         |
| `daily_goal_tracker_widget.dart`         | Widget  | 350   | Daily progress tracking widget            |
| `spaced_repetition_settings_widget.dart` | Widget  | 380   | User preferences settings                 |
| `spaced_repetition_service.dart`         | Service | 340   | SM-2 algorithm + review scheduling        |
| `spaced-repetition-utils.js`             | Backend | 400   | Server-side SM-2 + database queries       |
| `SPACED_REPETITION_INTEGRATION_GUIDE.md` | Doc     | -     | Step-by-step integration instructions     |
| `BACKEND_SPACED_REPETITION_ENDPOINTS.md` | Doc     | -     | 8 API endpoint specifications             |
| `IMPLEMENTATION_COMPLETE_SUMMARY.md`     | Doc     | -     | Full project overview & roadmap           |

**Total**: 11 files | **Total Lines**: ~3,350 lines of production code

---

## 🎯 What Each Component Does

### Services (Data Layer)

#### `CheckpointQuizService`

```dart
// Submit quiz answers
await quizService.submitQuizAnswers(
  botId: 'bot-123',
  userId: 'user-456',
  answers: {1: 'A', 2: 'B', 3: 'C'},
  correctAnswers: {1: 'A', 2: 'C', 3: 'C'},
);

// Fetch struggle signals
var struggles = await quizService.getStruggleSignals(
  botId: 'bot-123',
  userId: 'user-456',
);

// Get performance metrics
var performance = await quizService.getConceptPerformance(
  botId: 'bot-123',
  userId: 'user-456',
  moduleIndex: 0,
  conceptIndex: 0,
);
```

#### `SpacedRepetitionService`

```dart
// Calculate next review date
var nextReview = SpacedRepetitionService.calculateNextReview(
  quality: 4,          // 0-5 user response rating
  easinessFactor: 2.5,
  previousInterval: 1, // days
);
// Returns: {nextReviewDate, newEasiness, newInterval}

// Check if concept needs review
bool needsReview = SpacedRepetitionService.needsReview(concept);

// Generate schedule
var schedule = SpacedRepetitionService.generateReviewSchedule(
  concepts: allConcepts,
  daysAhead: 30,
);
```

---

### Widgets (UI Layer)

#### `CheckpointQuizWidget`

**When to use**: After user says they understand, before advancing concept

```dart
CheckpointQuizWidget(
  quiz: checkpointQuiz,
  botId: botId,
  userId: userId,
  moduleIndex: 0,
  conceptIndex: 0,
  onCompleted: (result) {
    if (result.passed) {
      // Advance to next concept
      _advanceToNext();
    } else {
      // Show review option
      _showReviewPrompt();
    }
  },
)
```

**Features**:

- ⏱️ Timer with urgency colors
- ✔️ Progress tracking (Q1/3, Q2/3, etc)
- 🔵 MCQ with visual selection (A/B/C/D)
- 📝 Short answer support
- 📊 Score calculation (70%+ to pass)

---

#### `StruggleDetectionWidget`

**When to use**: Place in alert banner when struggles detected

```dart
if (struggles.isNotEmpty) {
  StruggleDetectionWidget(
    signal: struggles.first,
    onDifferentAngle: () => _showAlternativeExplanation(),
    onShowExample: () => _displayExample(),
    onTakeBreak: () => _pauseSession(),
    onDismiss: () => _dismissAlert(),
  )
}
```

**Features**:

- 🤔 5 struggle types (confusion, clarification, frustration, disengagement, mismatch)
- 💡 4x intervention options
- 📊 LearningAnalyticsWidget embedded
- 🎯 Confidence scoring for each signal

---

#### `DailyGoalTrackerWidget`

**When to use**: Top of study dashboard

```dart
DailyGoalTrackerWidget(
  completedToday: 3,
  recommendedDaily: 10,
  onStartReview: () => _navigateToReviews(),
)
```

**Features**:

- 📊 Progress bar with percentage
- 💪 Motivational messages
- ✨ Streak counter
- ⏱️ Time estimate
- 🎉 Celebration on goal completion

---

#### `ReviewScheduleWidget`

**When to use**: New "Schedule" tab in main navigation

```dart
ReviewScheduleWidget(
  concepts: userConcepts,
  daysAhead: 30,
  onReviewSelected: (concept) {
    _showCheckpointQuiz(concept);
  },
)
```

**Features**:

- 📅 Calendar view
- 📊 Statistics cards (due today, overdue, mastery %)
- 🎯 Per-concept review tiles
- ⚠️ Overdue concept highlighting

---

#### `SpacedRepetitionSettingsWidget`

**When to use**: Settings > Learning > Spaced Repetition

```dart
SpacedRepetitionSettingsWidget(
  defaultDailyGoal: 10,
  defaultEasinessFactor: 2.5,
  onPreferencesChanged: (prefs) {
    _savePreferences(prefs);
    _recalculateSchedule();
  },
)
```

**Features**:

- 🎯 Daily goal slider (5-30)
- 📈 Difficulty selection (Easy/Medium/Hard)
- 🔄 Adaptive pacing toggle
- 🔔 Notification settings

---

## 🔌 Integration Points

### In StudyPlanChatScreen

```dart
// After receiving message response:
if (response['checkpointQuizRequired'] == true) {
  // Show checkpoint quiz
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: CheckpointQuizWidget(
        quiz: CheckpointQuiz.fromJson(response['checkpointQuiz']),
        onCompleted: _handleCheckpointResult,
      ),
    ),
  );
}

// Display struggles in message bubble
if (response['struggles'] != null) {
  final signal = StruggleSignal.fromJson(response['struggles'][0]);
  _showStruggleBubble(signal);
}
```

### In Bottom Navigation

```dart
BottomNavigationBar(
  items: [
    BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
    BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'Quiz'),
    BottomNavigationBarItem(icon: Icon(Icons.calendar), label: 'Schedule'),
    BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
  ],
  onTap: (index) {
    if (index == 2) {
      // Show ReviewScheduleWidget
    } else if (index == 3) {
      // Show LearningAnalyticsWidget
    }
  },
)
```

---

## 🔄 Data Flow Diagram

```
User sends message
    ↓
API: POST /api/chat-enhanced
    ↓ (returns)
{
  message: "...",
  struggles: [...],            ← detectStruggleSignals() runs here
  checkpointQuizRequired: true, ← marked when CONCEPT_COMPLETE
  checkpointQuiz: {...}        ← generateMasteryCheckpointQuiz()
}
    ↓
CheckpointQuizWidget shows
    ↓
User answers 3 questions
    ↓
API: POST /api/submit-checkpoint-quiz
    ↓ (calculates score)
CheckpointQuizResult
    ├─ If passed (70%+): Schedule next review ✅
    └─ If failed: Show retry option ❌
    ↓
SpacedRepetitionService.calculateNextReview()
    ↓
Save to concept_review_schedule table
    ↓
ReviewScheduleWidget shows updated calendar
```

---

## 🚀 Minimal Integration (30 minutes)

To get spaced repetition working with minimal code:

### Step 1: Add to StudyPlanChatScreen

```dart
late CheckpointQuizService _quizService;

@override
void initState() {
  _quizService = CheckpointQuizService(
    backendUrl: 'http://your-backend:5000',
  );
  super.initState();
}
```

### Step 2: Show checkpoint quiz

```dart
if (response['checkpointQuizRequired'] == true) {
  showDialog(
    context: context,
    builder: (context) => CheckpointQuizWidget(
      quiz: CheckpointQuiz.fromJson(response['checkpointQuiz']),
      botId: widget.botId,
      userId: widget.userId,
      moduleIndex: _currentModuleIndex,
      conceptIndex: _currentConceptIndex,
      onCompleted: (result) {
        Navigator.pop(context);
        if (result.passed) {
          _advanceToNextConcept();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message)),
          );
        }
      },
    ),
  );
}
```

### Step 3: Add daily goal tracker

```dart
// In build() method, at top of study dashboard:
DailyGoalTrackerWidget(
  completedToday: _completedToday,
  recommendedDaily: 10,
)
```

✅ **Done!** You now have:

- Checkpoint quiz validation
- Struggle detection (backend handles)
- Daily goal tracking

---

## 📊 SM-2 Algorithm Quick Reference

**Quality Scale** (How well learner remembers):

- 0: Complete failure - don't remember at all
- 1: Incorrect with serious error
- 2: Incorrect answer, but right approach
- 3: Correct with serious difficulty
- 4: Correct with some difficulty
- 5: Perfect response

**Interval Calculation**:

```
IF quality < 3:
  nextInterval = 1 day
  easiness = easiness - 0.14 + (5-quality)*0.1

ELSE:
  IF previousInterval = 0 or 1:
    nextInterval = 3 days
  ELSE:
    nextInterval = round(previousInterval * easiness)

  easiness = easiness + 0.1 - (5-quality)*0.08

Clamp easiness: 1.3 ≤ easiness ≤ 2.8
```

**Example**:

```
Concept 1, Review 1:
  quality = 4 (good)
  easiness = 2.5 (default)
  interval = 3 (first review rule)
  → Next review: 3 days from now

Concept 1, Review 2:
  quality = 5 (perfect)
  easiness = 2.5 + 0.1 - 0 = 2.6
  interval = round(3 * 2.6) = 8 days
  → Next review: 8 days from now

Concept 1, Review 3:
  quality = 2 (struggling)
  interval = 1 day (failed)
  easiness = 2.6 - 0.14 + 0.3 = 2.76
  → Next review: 1 day from now (retry)
```

---

## 🛠️ Common Implementation Tasks

### Task: Show learning analytics

```dart
LearningAnalyticsWidget(
  botId: botId,
  userId: userId,
  quizService: _quizService,
)
```

### Task: Calculate days until review

```dart
int daysUntil = concept.nextReviewDate
    .difference(DateTime.now())
    .inDays;

String label = daysUntil < 0 ? 'Overdue'
             : daysUntil == 0 ? 'Due today'
             : 'Due in $daysUntil days';
```

### Task: Disable/Enable review button

```dart
bool canReview = SpacedRepetitionService.needsReview(concept);

ElevatedButton(
  onPressed: canReview ? () => _startReview() : null,
  child: Text('Review ${canReview ? '📖' : '✅'}'),
)
```

### Task: Get user's recommended daily workload

```dart
int dailyGoal = SpacedRepetitionService.getRecommendedDailyGoal(
  stats: spaceRepStats,
);

// Or from preferences
int customGoal = userPreferences.dailyGoal ?? 10;
```

---

## ⚠️ Troubleshooting

### Checkpoint quiz not showing?

- [ ] Backend response includes `checkpointQuizRequired: true`
- [ ] CheckpointQuiz JSON has `questions` array
- [ ] Modal isn't being dismissed accidentally
- [ ] CheckpointQuizWidget imported correctly

### Struggles not detected?

- [ ] Backend `detectStruggleSignals()` called before response
- [ ] Message contains trigger words (confused, understand, frustrated)
- [ ] Response includes `struggles` array
- [ ] StruggleSignal model deserializing correctly

### SM-2 calculations seem off?

- [ ] Quality is 0-5, not percentage
- [ ] previousInterval is days, not milliseconds
- [ ] easinessFactory is between 1.3-2.8
- [ ] Comparing to SM-2 paper examples

### Performance issues?

- [ ] Add database index: `CREATE INDEX idx_next_review ON concept_review_schedule(next_review_date)`
- [ ] Batch analytics updates instead of per-review
- [ ] Cache user preferences locally
- [ ] Use pagination for schedule beyond 30 days

---

## 📞 Quick Help

**"How do I..."**

| Question               | Answer                                                            |
| ---------------------- | ----------------------------------------------------------------- |
| Show checkpoint quiz?  | Use `CheckpointQuizWidget` in dialog                              |
| Calculate next review? | Call `SpacedRepetitionService.calculateNextReview()`              |
| Get daily goal?        | Use `SpacedRepetitionService.getRecommendedDailyGoal()`           |
| Display struggles?     | Use `StruggleDetectionWidget`                                     |
| Show calendar?         | Use `ReviewScheduleWidget`                                        |
| Store preferences?     | Use `SpacedRepetitionPreferences.toJson()` with SharedPreferences |
| Test SM-2 logic?       | Use `spaced_repetition_service.dart` test cases                   |
| Integrate backend?     | Follow steps in SPACED_REPETITION_INTEGRATION_GUIDE.md            |

---

## 📚 File Locations

```
lib/
  ├── services/
  │   ├── checkpoint_quiz_service.dart ← API calls
  │   └── spaced_repetition_service.dart ← SM-2 algorithm
  └── widgets/
      ├── checkpoint_quiz_widget.dart ← Quiz UI
      ├── struggle_detection_widget.dart ← Alerts
      ├── review_schedule_widget.dart ← Calendar
      ├── daily_goal_tracker_widget.dart ← Progress
      └── spaced_repetition_settings_widget.dart ← Preferences

backend/
  └── spaced-repetition-utils.js ← Server functions

docs/
  ├── SPACED_REPETITION_INTEGRATION_GUIDE.md
  ├── BACKEND_SPACED_REPETITION_ENDPOINTS.md
  └── IMPLEMENTATION_COMPLETE_SUMMARY.md
```

---

**Version**: 1.0 | **Last Updated**: 2024 | **Status**: Ready for Integration
