# SPACED REPETITION SYSTEM - COMPLETE FILE INDEX & NAVIGATION GUIDE

## 📑 Quick Navigation

**Start here**: [SR_QUICK_REFERENCE.md](SR_QUICK_REFERENCE.md) - 5 minute overview  
**Integration steps**: [SPACED_REPETITION_INTEGRATION_GUIDE.md](SPACED_REPETITION_INTEGRATION_GUIDE.md) - Detailed implementation  
**Backend reference**: [BACKEND_SPACED_REPETITION_ENDPOINTS.md](BACKEND_SPACED_REPETITION_ENDPOINTS.md) - API specifications  
**Full details**: [IMPLEMENTATION_COMPLETE_SUMMARY.md](IMPLEMENTATION_COMPLETE_SUMMARY.md) - Complete project overview

---

## 🗂️ COMPLETE FILE TREE

### Core System Files

```
PROJECT ROOT
├── lib/
│   ├── services/
│   │   ├── checkpoint_quiz_service.dart ✅ (NEW)
│   │   │   └── Purpose: API communication for quizzes & struggles
│   │   │       Services: CheckpointQuizService
│   │   │       Models: CheckpointQuiz, CheckpointQuestion, CheckpointQuizResult
│   │   │
│   │   └── spaced_repetition_service.dart ✅ (NEW)
│   │       └── Purpose: SM-2 algorithm & review scheduling
│   │           Services: SpacedRepetitionService
│   │           Models: ConceptReview, ScheduledReview, SpacedRepetitionStats
│   │
│   └── widgets/
│       ├── checkpoint_quiz_widget.dart ✅ (NEW)
│       │   └── Purpose: Interactive quiz UI + results
│       │       Components: CheckpointQuizWidget, CheckpointResultWidget
│       │       Features: Timer, progress bar, MCQ/short-answer, score calculation
│       │
│       ├── struggle_detection_widget.dart ✅ (NEW)
│       │   └── Purpose: Alert banners & analytics dashboard
│       │       Components: StruggleDetectionWidget, LearningAnalyticsWidget
│       │       Features: 5 signal types, intervention buttons, performance graphs
│       │
│       ├── review_schedule_widget.dart ✅ (NEW)
│       │   └── Purpose: Calendar view of upcoming reviews
│       │       Components: ReviewScheduleWidget, ScheduledReviewCard, ScheduledReviewCard
│       │       Features: Calendar grid, statistics, concept tiles
│       │
│       ├── daily_goal_tracker_widget.dart ✅ (NEW)
│       │   └── Purpose: Daily progress tracking
│       │       Components: DailyGoalTrackerWidget, ActivityCalendarWidget, MiniProgressIndicator
│       │       Features: Progress bar, motivation, streak tracking, activity heatmap
│       │
│       └── spaced_repetition_settings_widget.dart ✅ (NEW)
│           └── Purpose: User preferences configuration
│               Components: SpacedRepetitionSettingsWidget
│               Features: Daily goal slider, difficulty selection, adaptive pacing toggle
│
├── backend/
│   └── spaced-repetition-utils.js ✅ (NEW)
│       └── Purpose: Server-side SM-2 calculations & database queries
│           Functions: calculateNextReview(), getConceptsDueForReview(), logReviewCompletion()
│           Database: Queries for concept_review_schedule, review_analytics, review_streaks
│
└── docs/ (This folder)
    ├── SR_QUICK_REFERENCE.md ✅ (NEW)
    │   └── 5-minute overview with code examples & troubleshooting
    │
    ├── SPACED_REPETITION_INTEGRATION_GUIDE.md ✅ (NEW)
    │   └── Step-by-step integration instructions with diagrams
    │
    ├── BACKEND_SPACED_REPETITION_ENDPOINTS.md ✅ (NEW)
    │   └── 8 API endpoint specifications with examples
    │
    └── IMPLEMENTATION_COMPLETE_SUMMARY.md ✅ (NEW)
        └── Complete project overview, architecture, testing checklist
```

---

## 📄 DOCUMENTATION FILES

### 1. **SR_QUICK_REFERENCE.md**

**Purpose**: Quick lookup reference  
**Audience**: Developers integrating widgets  
**Read time**: 5 minutes  
**Contains**:

- File overview table
- Service usage examples
- Widget integration code
- SM-2 algorithm quick reference
- Common tasks with code
- Troubleshooting guide

**When to use**:

- "How do I show a checkpoint quiz?"
- "What parameters does calculateNextReview() need?"
- "Widget not working - help!"

**[→ Open SR_QUICK_REFERENCE.md](SR_QUICK_REFERENCE.md)**

---

### 2. **SPACED_REPETITION_INTEGRATION_GUIDE.md**

**Purpose**: Step-by-step integration instructions  
**Audience**: Backend & frontend developers  
**Read time**: 15 minutes  
**Contains**:

- 8 parts covering complete integration
- Service initialization
- Widget integration points
- Struggle display logic
- Checkpoint modal modal handling
- Analytics dashboard setup
- Spaced repetition backend work
- Daily goal tracking
- Settings/preferences integration
- Implementation checklist

**When to use**:

- "Where do I add these services to my app?"
- "How do I integrate the widgets?"
- "What backend work is needed?"
- "Complete integration process?"

**[→ Open SPACED_REPETITION_INTEGRATION_GUIDE.md](SPACED_REPETITION_INTEGRATION_GUIDE.md)**

---

### 3. **BACKEND_SPACED_REPETITION_ENDPOINTS.md**

**Purpose**: API endpoint reference  
**Audience**: Backend developers  
**Read time**: 20 minutes  
**Contains**:

- 8 complete endpoint specifications
- Request/response format for each
- SQL queries
- Error handling
- Integration checklist
- Example usage code

**Endpoints documented**:

1. GET /api/daily-reviews/:botId/:userId
2. POST /api/log-review/:botId/:userId/:moduleIndex/:conceptIndex
3. POST /api/initialize-review/:botId/:userId/:moduleIndex/:conceptIndex
4. GET /api/review-schedule/:botId/:userId
5. GET /api/concept-review-history/:botId/:userId/:moduleIndex/:conceptIndex
6. POST /api/reset-review/:botId/:userId/:moduleIndex/:conceptIndex
7. POST /api/update-all-reviews/:botId/:userId
8. GET /api/learning-recommendations/:botId/:userId

**When to use**:

- "What parameters does this endpoint need?"
- "What does the response look like?"
- "How do I implement a specific endpoint?"
- "Backend endpoint reference?"

**[→ Open BACKEND_SPACED_REPETITION_ENDPOINTS.md](BACKEND_SPACED_REPETITION_ENDPOINTS.md)**

---

### 4. **IMPLEMENTATION_COMPLETE_SUMMARY.md**

**Purpose**: Complete project overview & status  
**Audience**: Project managers, architects, all developers  
**Read time**: 25 minutes  
**Contains**:

- Problems solved (with solutions)
- Deliverables summary
- Technical architecture
- Database schema
- API response format
- SM-2 algorithm details
- Testing checklist
- User experience flows
- Implementation roadmap (6 phases)
- File structure
- Key features
- Success metrics
- Deployment checklist

**When to use**:

- "What was built and why?"
- "What's the architecture?"
- "What's the testing plan?"
- "What's the deployment process?"
- "Project status overview?"

**[→ Open IMPLEMENTATION_COMPLETE_SUMMARY.md](IMPLEMENTATION_COMPLETE_SUMMARY.md)**

---

## 🛠️ SOURCE FILE GUIDE

### Frontend Services

#### **checkpoint_quiz_service.dart** (210 lines)

**Models**: 5 data classes

- `CheckpointQuiz` - Quiz metadata (concept, questions, passing score, time limit)
- `CheckpointQuestion` - Individual question (id, type, options, correct answer)
- `CheckpointQuizResult` - Result after submission (passed, score, percentage, message)
- `StruggleSignal` - Detected struggle information
- `ConceptPerformance` - Performance metrics per concept

**Service Class**: `CheckpointQuizService`

- `submitQuizAnswers()` - POST quiz answers, get score
- `getStruggleSignals()` - Fetch detected struggles
- `getConceptPerformance()` - Get performance metrics

**When editing**:

- Add new API methods here for quiz-related endpoints
- Add new models for quiz response variations
- Update error handling for network issues

**[→ View file](lib/services/checkpoint_quiz_service.dart)**

---

#### **spaced_repetition_service.dart** (340 lines)

**Models**: 3 data classes

- `ConceptReview` - Individual review record (easiness factor, interval, review count)
- `ScheduledReview` - Review date grouped concepts
- `SpacedRepetitionStats` - Aggregated statistics (total, mastered, overdue, etc.)

**Service Class**: `SpacedRepetitionService`

- `calculateNextReview()` - SM-2 algorithm (main logic)
- `needsReview()` - Boolean check if due
- `getReviewUrgency()` - 0-1 urgency score
- `generateReviewSchedule()` - Calendar of reviews
- `getRecommendedDailyGoal()` - Workload recommendation

**Key Constants**:

- `MINIMUM_EASINESS_FACTOR = 1.3`
- `MAXIMUM_EASINESS_FACTOR = 2.8`

**When editing**:

- SM-2 formula is in `calculateNextReview()` - change carefully
- Review interval algorithm is quality-dependent
- Easiness factor clamping ensures stability

**[→ View file](lib/services/spaced_repetition_service.dart)**

---

### Frontend Widgets

#### **checkpoint_quiz_widget.dart** (380 lines)

**Widgets**: 2 classes

- `CheckpointQuizWidget(StatefulWidget)` - Main quiz component
- `CheckpointResultWidget` - Result display component

**Features**:

- Multi-question quiz with progress tracking
- Timer with color-coded urgency
- MCQ with A/B/C/D buttons
- Short answer text field support
- Score calculation & validation
- Previous/Next/Skip/Submit navigation
- Auto-submit on timeout
- Loading states

**State variables**:

- `currentQuestionIndex` - Current question being displayed
- `answers` - User's answers map
- `timeRemaining` - Countdown timer
- `isSubmitting` - Loading state during submission

**When editing**:

- Timer colors in `_getTimerColor()`
- Question display in `_buildQuestionContent()`
- Navigation buttons in `_buildNavigation()`
- Result celebration emoji/animation

**[→ View file](lib/widgets/checkpoint_quiz_widget.dart)**

---

#### **struggle_detection_widget.dart** (420 lines)

**Widgets**: 3 main classes

- `StruggleDetectionWidget` - Alert banner with actions
- `LearningAnalyticsWidget` - Analytics dashboard
- `ConceptPerformanceCard` - Individual concept stats
- `StruggleSignalCard` - Individual struggle display

**Features**:

- Amber alert styling for struggles
- 4 intervention action buttons
- Real-time data fetching via FutureBuilder
- Performance bar charts per concept
- Struggle history with timestamps
- Intervention status badges

**Data flow**:

1. Widget fetches performance + struggles on build
2. FutureBuilder handles async loading
3. LearningAnalyticsWidget displays results in two sections
4. User can tap concepts to see details

**When editing**:

- Intervention buttons in `StruggleDetectionWidget.build()`
- Chart rendering in `ConceptPerformanceCard`
- Data fetching in `LearningAnalyticsWidget` initState
- Color coding based on difficulty (red/amber/green)

**[→ View file](lib/widgets/struggle_detection_widget.dart)**

---

#### **review_schedule_widget.dart** (450 lines)

**Widgets**: 4 classes

- `ReviewScheduleWidget` - Main schedule display
- `ScheduledReviewCard` - Daily review group
- `ConceptReviewTile` - Individual concept in schedule
- Various helper widgets

**Features**:

- Calendar grid showing concept distribution
- Statistics cards (due today, overdue, mastery %)
- Concept tiles with review count & status
- Color-coded urgency (red=overdue, blue=today, green=future)
- Tap to select concept for review
- Empty state when no reviews needed

**State**:

- `_updateSchedule()` - Regenerates schedule from concepts

**Date calculations**:

- `_getDateColor()` - Color based on urgency
- `_getStatusColor()` - Status indicator color

**When editing**:

- Schedule generation in `_updateSchedule()`
- Date grouping in `ScheduledReviewCard`
- Urgency colors in `_getDateColor()`
- Card styling in `ConceptReviewTile`

**[→ View file](lib/widgets/review_schedule_widget.dart)**

---

#### **daily_goal_tracker_widget.dart** (350 lines)

**Widgets**: 3 classes

- `DailyGoalTrackerWidget` - Main daily tracker
- `ActivityCalendarWidget` - Activity heatmap
- `MiniProgressIndicator` - Inline progress bar

**Features**:

- Progress bar toward daily goal
- Motivational messages (dynamic based on progress)
- Statistics row (streak, time, efficiency)
- Activity calendar (heatmap view)
- Start/Continue button
- Goal completion celebration

**Dynamic messaging**:

- 0-25%: "💪 Keep going!"
- 25-50%: "🔥 Almost there!"
- 50-75%: "🎯 Close to goal!"
- 75-99%: "✨ Nearly done!"
- 100%: "🎉 Daily goal complete!"

**Calendar heatmap**:

- Light gray = no reviews
- Orange = 1-5 reviews
- Green = 5+ reviews

**When editing**:

- Motivational messages in `get _motivationalMessage`
- Progress color in `get _progressColor`
- Activity legend in `ActivityCalendarWidget`
- Heatmap color logic in `_ActivityDot._getColor()`

**[→ View file](lib/widgets/daily_goal_tracker_widget.dart)**

---

#### **spaced_repetition_settings_widget.dart** (380 lines)

**Widgets**: 5 classes

- `SpacedRepetitionSettingsWidget` - Main settings screen
- `_SettingSection` - Section wrapper widget
- `_DifficultyOption` - Radio button option
- `_ToggleSetting` - Toggle switch wrapper
- `SpacedRepetitionStatusBadge` - Inline status indicator

**Data models**:

- `SpacedRepetitionPreferences` - User preferences (serializable)

**Features**:

- Daily goal slider (5-30)
- Difficulty radio buttons (Easy/Medium/Hard)
- Adaptive pacing toggle
- Notifications toggle
- Tips info box
- Preferences saved & callback notification

**Preference mapping**:

- Easy → easiness 2.2
- Medium → easiness 2.5
- Hard → easiness 2.8

**When editing**:

- Slider range in `Slider.min` and `.max`
- Difficulty options in `_DifficultyOption` list
- Preference callback in `_notifyPreferencesChanged()`
- Tips text in info box

**[→ View file](lib/widgets/spaced_repetition_settings_widget.dart)**

---

### Backend Utilities

#### **spaced-repetition-utils.js** (400 lines)

**Constants**:

- `MINIMUM_EASINESS_FACTOR = 1.3`
- `MAXIMUM_EASINESS_FACTOR = 2.8`

**Core Functions**:

- `calculateNextReview()` - SM-2 algorithm (400+ lines)
- `getConceptsDueForReview()` - Query today's reviews
- `getOverdueReviews()` - Get overdue reviews
- `logReviewCompletion()` - Update review record
- `initializeConceptReview()` - Create new review
- `getSpacedRepetitionStats()` - Aggregate statistics
- `calculateDailyGoal()` - Recommend daily workload
- `generateReviewSchedule()` - Calendar projection
- `getConceptReviewHistory()` - Individual concept history
- `resetConceptReview()` - Reset to beginning

**Database queries**:

- All use parameterized statements (SQL injection safe)
- Index recommendations for performance

**Error handling**:

- Try/catch blocks return meaningful error messages
- Validates input parameters
- Checks foreign key relationships

**When editing**:

- SM-2 algorithm in `calculateNextReview()`
- Query filters in `getConceptsDueForReview()`
- Update logic in `logReviewCompletion()`
- Aggregation formulas in `calculateDailyGoal()`

**[→ View file](backend/spaced-repetition-utils.js)**

---

## 🔄 WORKFLOWS

### Adding a New Feature

**Example: Add "Concept difficulty selector" to checkpoint quiz**

1. **Backend**: Edit `server.js`
   - Add `difficulty` field to `generateMasteryCheckpointQuiz()` response
2. **Frontend Services**: Edit `checkpoint_quiz_service.dart`
   - Add `difficulty` field to `CheckpointQuiz` model
   - Update `fromJson()` to parse field

3. **Frontend Widget**: Edit `checkpoint_quiz_widget.dart`
   - Display difficulty selector before quiz starts
   - Pass selected difficulty to backend on submit

4. **Backend Endpoints**: Edit `server.js`
   - Handle `difficulty` in POST `/api/submit-checkpoint-quiz`
   - Use difficulty to adjust scoring thresholds

5. **Documentation**: Update relevant markdown files
   - Add to SPACED_REPETITION_INTEGRATION_GUIDE.md
   - Add to SR_QUICK_REFERENCE.md examples

---

### Fixing a Bug

**Example: SM-2 calculation not working correctly**

1. **Identify**: Check `SpacedRepetitionService.calculateNextReview()` in `spaced_repetition_service.dart`

2. **Test locally**: Create test case with known SM-2 paper values

3. **Fix**: Adjust formula in `calculateNextReview()`

4. **Test backend**: Also check `spaced-repetition-utils.js` for same logic

5. **Verify**: Test with multiple scenarios (quality 0-5, various intervals)

6. **Document**: Update comments if formula changes

---

### Integrating into App

**Full integration steps**:

1. **Services**: Import and initialize in main screen
2. **Models**: Parse API responses into data classes
3. **Widgets**: Add to UI hierarchy
4. **Navigation**: Add routes/tabs for new screens
5. **Database**: Run migrations for new tables
6. **API endpoints**: Test with Postman before connecting
7. **Testing**: Unit + integration tests
8. **Documentation**: Update docs with your changes

See **SPACED_REPETITION_INTEGRATION_GUIDE.md** for details.

---

## 📊 DATA RELATIONSHIPS

```
┌─────────────────────────────────────────┐
│         Study Bot / User Session        │
└────────────────┬────────────────────────┘
                 │
        ┌────────┴──────────┬──────────────┐
        │                   │              │
┌───────▼──────┐  ┌────────▼────────┐  ┌─▼───────────┐
│ Checkpoint   │  │ Struggle        │  │ Concept     │
│ Quiz         │  │ Signals         │  │ Review      │
│              │  │                 │  │ Schedule    │
│ ┌─────────┐  │  │ ┌────────────┐  │  │             │
│ │Question │  │  │ │Signal Type │  │  │ ┌─────────┐│
│ │Question │  │  │ │Confidence  │  │  │ │Interval  ││
│ │Question │  │  │ │Intervention│  │  │ │Easiness  ││
│ └─────────┘  │  │ └────────────┘  │  │ │Next Date ││
│              │  │                 │  │ └─────────┘│
└──────────────┘  └─────────────────┘  └────────────┘
       │                 │                    │
       └──────────────┬──────────────────────┘
                      │
         ┌────────────▼───────────┐
         │ Learning Analytics    │
         │ • Performance graphs  │
         │ • Trend analysis      │
         │ • Mastery percentage  │
         │ • Struggle hotspots   │
         └───────────────────────┘
```

---

## 🧭 DECISION TREE: "Which file do I need?"

```
I want to...

├─ Understand the project?
│  └─ Read: IMPLEMENTATION_COMPLETE_SUMMARY.md
│
├─ Learn how to use widgets?
│  └─ Read: SR_QUICK_REFERENCE.md
│
├─ Integrate widgets into my app?
│  └─ Read: SPACED_REPETITION_INTEGRATION_GUIDE.md
│
├─ Implement a backend endpoint?
│  └─ Read: BACKEND_SPACED_REPETITION_ENDPOINTS.md
│  └─ Edit: backend/spaced-repetition-utils.js & server.js
│
├─ Fix a widget display issue?
│  └─ Edit: lib/widgets/[widget_name].dart
│  └─ Check: SR_QUICK_REFERENCE.md troubleshooting
│
├─ Fix an SM-2 calculation?
│  └─ Edit: lib/services/spaced_repetition_service.dart (frontend)
│  └─ Edit: backend/spaced-repetition-utils.js (backend)
│
├─ Add a new model/data class?
│  └─ Edit: lib/services/[service_name].dart
│
├─ Call a new backend API?
│  └─ Edit: lib/services/checkpoint_quiz_service.dart
│  └─ Check: BACKEND_SPACED_REPETITION_ENDPOINTS.md
│
└─ Deploy to production?
   └─ Check: IMPLEMENTATION_COMPLETE_SUMMARY.md deployment checklist
```

---

## ✅ VERIFICATION CHECKLIST

After making changes, verify:

- [ ] Code compiles without errors
- [ ] Models serialize/deserialize correctly
- [ ] Network requests use correct endpoints
- [ ] Database queries use parameterized statements
- [ ] UI widgets render properly on iOS/Android
- [ ] Color schemes match app theme
- [ ] SM-2 calculations produce expected results
- [ ] Error messages are user-friendly
- [ ] Loading states prevent duplicate submissions
- [ ] Timestamps are consistent (UTC or local?)
- [ ] Documentation updated

---

**Last Updated**: 2024  
**Total Files**: 11 (Frontend: 7, Backend: 1, Documentation: 4 - but this combines into this index)  
**Total Lines**: ~3,350 lines of production code + comprehensive documentation  
**Status**: ✅ Implementation Phase 2 Complete, Ready for Phase 3 Integration
