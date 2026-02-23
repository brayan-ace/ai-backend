/// SPACED REPETITION & ADAPTIVE LEARNING INTEGRATION GUIDE
///
/// This guide explains how to integrate all the new services and widgets
/// into the existing study bot application.

import 'package:flutter/material.dart';

# /\*

# PART 1: SERVICE LAYER SETUP

The service layer handles all API communication and business logic:

1. CheckpointQuizService
   - Communicates with: /api/submit-checkpoint-quiz
     /api/struggle-signals
     /api/concept-performance
   - Handles: Quiz submission, struggle detection, performance fetching

2. SpacedRepetitionService
   - Local calculation only (no API calls initially)
   - Handles: SM-2 algorithm calculations, schedule generation, urgency scoring

3. Backend Integration Points:
   - Modify server.js to create these tables (already done in Phase 3):
     - concept_mastery_checkpoints
     - concept_performance_metrics
     - struggle_signals
     - study_plan_generation_progress
   - New endpoints (already implemented):
     - POST /api/submit-checkpoint-quiz
     - GET /api/struggle-signals/:botId/:userId
     - GET /api/concept-performance/:botId/:userId

\*/

// EXAMPLE 1: Basic Service Initialization
class ServiceSetup {
static void example() {
// Initialize checkpoint quiz service with your backend URL
final checkpointQuizService = CheckpointQuizService(
backendUrl: 'http://your-backend-url:5000', // or Firebase hosting URL
);

    // SpacedRepetitionService is stateless, no initialization needed
    // Use directly: SpacedRepetitionService.calculateNextReview(...)

}
}

# /\*

# PART 2: WIDGET INTEGRATION INTO StudyPlanChatScreen

Current StudyPlanChatScreen flow:

1. User sends message
2. Bot responds with chat message
3. If concept seems complete, user sees "Great, moving to next concept!"

NEW flow with checkpoint validation:

1. User sends message
2. Bot responds with chat message + struggle detection
3. If CONCEPT_COMPLETE marker detected in response:
   a. Struggle detection runs (real-time feedback)
   b. Checkpoint quiz generated (objective validation)
   c. Quiz is shown in modal/overlay
   d. User answers quiz questions
   e. Quiz result determines advancement
   f. Analytics updated

\*/

// EXAMPLE 2: Integration into StudyPlanChatScreen
class StudyPlanChatScreenIntegration {
/\*
Modification to study_plan_chat_screen.dart:

1. Add instance variables:


    late CheckpointQuizService _quizService;
    CheckpointQuiz? _pendingCheckpointQuiz;
    List<StruggleSignal> _currentStruggles = [];

2. Initialize in initState():


    _quizService = CheckpointQuizService(
      backendUrl: 'http://your-backend-url',
    );

3. When receiving chat response, check for checkpointQuizRequired:


    if (aiResponse['checkpointQuizRequired'] == true) {
      // Parse checkpoint quiz from response
      _pendingCheckpointQuiz = CheckpointQuiz.fromJson(
        aiResponse['checkpointQuiz']
      );

      // Extract struggle signals if present
      if (aiResponse['struggles'] != null) {
        _currentStruggles = (aiResponse['struggles'] as List)
          .map((s) => StruggleSignal.fromJson(s))
          .toList();

        // Show struggle alert if high confidence struggle detected
        if (_currentStruggles.isNotEmpty) {
          _showStruggleAlert(_currentStruggles.first);
        }
      }

      // Show checkpoint quiz in modal
      _showCheckpointQuizModal();
    }

4. Add methods for handling quiz results:


    void _handleCheckpointQuizResult(CheckpointQuizResult result) {
      if (result.passed) {
        // Advance to next concept
        _advanceToNextConcept();
        _showCelebration('✅ Mastery Validated!', 'Ready for next challenge?');
      } else {
        // Show review option
        _showReviewPrompt(result);
      }

      // Update analytics
      _updateLearningAnalytics();
    }

5. New UI components to add:


    - CheckpointQuizWidget in modal overlay
    - StruggleDetectionWidget for alerts
    - LearningAnalyticsWidget in drawer/tab
    - ReviewScheduleWidget in new "Schedule" tab
    - DailyGoalTrackerWidget in study dashboard

\*/
}

# /\*

# PART 3: REAL-TIME STRUGGLE DETECTION TRIGGER

Currently, struggles are detected asynchronously.
For real-time user experience, integrate into message display:

When showing bot response:

1. Parse struggles array from response JSON
2. Map struggle type to intervention strategy
3. Display appropriate widget based on signal type

\*/

// EXAMPLE 3: Struggle Display Logic
class StruggleDisplayLogic {
static Widget buildStruggleUI(StruggleSignal signal) {
switch (signal.signalType) {
case 'explicit_confusion':
return \_ConfusionInterventionBubble(signal: signal);
case 'clarification_request':
return \_ClarificationAlertBubble(signal: signal);
case 'frustration_detected':
return \_FrustrationSupportBubble(signal: signal);
case 'disengagement_pattern':
return \_ReEngagementPromptBubble(signal: signal);
case 'concept_mismatch':
return \_ConceptCorrectionBubble(signal: signal);
default:
return SizedBox.shrink();
}
}
}

class \_ConfusionInterventionBubble extends StatelessWidget {
final StruggleSignal signal;
const \_ConfusionInterventionBubble({required this.signal});
@override
Widget build(BuildContext context) {
return Container(
padding: EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.blue[50],
border: Border.all(color: Colors.blue[200]!),
borderRadius: BorderRadius.circular(8),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'🤔 Let me explain this differently...',
style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
),
SizedBox(height: 8),
ElevatedButton.icon(
onPressed: () {
// Trigger alternative explanation
},
icon: Icon(Icons.lightbulb),
label: Text('Show Alternative Explanation'),
style: ElevatedButton.styleFrom(
backgroundColor: Colors.blue,
),
),
],
),
);
}
}

class \_ClarificationAlertBubble extends StatelessWidget {
final StruggleSignal signal;
const \_ClarificationAlertBubble({required this.signal});
@override
Widget build(BuildContext context) {
return Container(
padding: EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.orange[50],
border: Border.all(color: Colors.orange[200]!),
borderRadius: BorderRadius.circular(8),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'❓ Let me break this down into steps...',
style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
),
SizedBox(height: 8),
ElevatedButton.icon(
onPressed: () {
// Show step-by-step explanation
},
icon: Icon(Icons.format_list_numbered),
label: Text('Show Step-by-Step'),
style: ElevatedButton.styleFrom(
backgroundColor: Colors.orange,
),
),
],
),
);
}
}

class \_FrustrationSupportBubble extends StatelessWidget {
final StruggleSignal signal;
const \_FrustrationSupportBubble({required this.signal});
@override
Widget build(BuildContext context) {
return Container(
padding: EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.green[50],
border: Border.all(color: Colors.green[200]!),
borderRadius: BorderRadius.circular(8),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'💪 You\'re doing great! Let\'s take this step by step.',
style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
),
SizedBox(height: 8),
Row(
mainAxisSize: MainAxisSize.min,
children: [
ElevatedButton.icon(
onPressed: () {
// Take a break
},
icon: Icon(Icons.coffee),
label: Text('Take a Break'),
style: ElevatedButton.styleFrom(
backgroundColor: Colors.green,
),
),
SizedBox(width: 8),
OutlinedButton(
onPressed: () {
// Show simpler version
},
child: Text('Simplify'),
),
],
),
],
),
);
}
}

class \_ReEngagementPromptBubble extends StatelessWidget {
final StruggleSignal signal;
const \_ReEngagementPromptBubble({required this.signal});
@override
Widget build(BuildContext context) {
return Container(
padding: EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.purple[50],
border: Border.all(color: Colors.purple[200]!),
borderRadius: BorderRadius.circular(8),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'😊 Let\'s make this interactive!',
style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
),
SizedBox(height: 8),
ElevatedButton.icon(
onPressed: () {
// Show interactive question
},
icon: Icon(Icons.quiz),
label: Text('Try a Quick Question'),
style: ElevatedButton.styleFrom(
backgroundColor: Colors.purple,
),
),
],
),
);
}
}

class \_ConceptCorrectionBubble extends StatelessWidget {
final StruggleSignal signal;
const \_ConceptCorrectionBubble({required this.signal});
@override
Widget build(BuildContext context) {
return Container(
padding: EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.red[50],
border: Border.all(color: Colors.red[200]!),
borderRadius: BorderRadius.circular(8),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'🔄 Let me clarify this concept...',
style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
),
SizedBox(height: 8),
ElevatedButton.icon(
onPressed: () {
// Show correct explanation with examples
},
icon: Icon(Icons.check_circle),
label: Text('Show Correct Approach'),
style: ElevatedButton.styleFrom(
backgroundColor: Colors.red,
),
),
],
),
);
}
}

# /\*

# PART 4: CHECKPOINT QUIZ MODAL INTEGRATION

Show checkpoint quiz in a modal dialog:

void \_showCheckpointQuizModal() {
showDialog(
context: context,
barrierDismissible: false, // User must complete or skip
builder: (context) => Dialog(
insetPadding: EdgeInsets.all(16),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
child: CheckpointQuizWidget(
quiz: \_pendingCheckpointQuiz!,
botId: widget.botId,
userId: widget.userId,
moduleIndex: \_currentModuleIndex,
conceptIndex: \_currentConceptIndex,
onCompleted: (result) {
Navigator.pop(context);
\_handleCheckpointQuizResult(result);
},
),
),
);
}

\*/

# /\*

# PART 5: ANALYTICS DASHBOARD INTEGRATION

Two options:

Option A: New "Analytics" tab in bottom navigation

- Add tab to bottom navigation bar
- Display LearningAnalyticsWidget in full screen
- Show ConceptPerformance + StruggleSignals together

Option B: Analytics drawer/modal

- Add analytics button to app bar
- Show modal with analytics on tap
- Include SpacedRepetitionInsights

Recommended: Option A for permanent access

Code snippet:

if (selectedIndex == 3) { // Analytics tab
return LearningAnalyticsWidget(
botId: widget.botId,
userId: widget.userId,
quizService: \_quizService,
);
}

\*/

# /\*

# PART 6: SPACED REPETITION INTEGRATION

This requires backend work first. Create new endpoint:
POST /api/schedule-reviews/:botId/:userId

The flow:

1. After checkpoint quiz passes, calculate next review date
2. Store in database: concept_review_schedule table
3. User can view review schedule in new "Schedule" tab
4. ReviewScheduleWidget shows calendar + upcoming reviews
5. When user taps "Review" on a concept, fetch and show checkpoint again

Database schema needed:
CREATE TABLE concept_review_schedule (
id SERIAL PRIMARY KEY,
bot_id UUID NOT NULL,
user_id UUID NOT NULL,
module_index INT,
concept_index INT,
last_review_date TIMESTAMP,
next_review_date TIMESTAMP,
review_count INT DEFAULT 0,
easiness_factor DECIMAL(3,2) DEFAULT 2.5,
interval_days INT DEFAULT 1,
created_at TIMESTAMP DEFAULT NOW(),
FOREIGN KEY (bot_id) REFERENCES study_bots(id),
FOREIGN KEY (user_id) REFERENCES users(id),
UNIQUE(bot_id, user_id, module_index, concept_index)
);

\*/

class SpacedRepetitionBackendIntegration {
/// Call this after successful checkpoint quiz to schedule next review
static Future<void> scheduleNextReview({
required String botId,
required String userId,
required int moduleIndex,
required int conceptIndex,
required int quizScore,
required int possibleScore,
CheckpointQuizService? service,
}) async {
// Calculate quality (0-5) from score
final quality = \_calculateQuality(quizScore, possibleScore);

    // Initial values for new concepts
    double easiness = 2.5;
    int interval = 1;
    DateTime lastReview = DateTime.now();

    // Calculate next review using SM-2
    final nextReview = SpacedRepetitionService.calculateNextReview(
      quality: quality,
      easinessFactor: easiness,
      previousInterval: interval,
      lastReviewDate: lastReview,
    );

    // POST to backend to save review schedule
    // URL: /api/schedule-reviews
    // Body: {
    //   botId, userId, moduleIndex, conceptIndex,
    //   nextReviewDate: nextReview['nextReviewDate'],
    //   easinessFactor: nextReview['newEasiness'],
    //   interval: nextReview['newInterval']
    // }

    print('Scheduled review for concept $conceptIndex on ${nextReview['nextReviewDate']}');

}

static int \_calculateQuality(int score, int possibleScore) {
final percentage = score / possibleScore;
if (percentage >= 0.95) return 5; // Perfect
if (percentage >= 0.85) return 4; // Good
if (percentage >= 0.70) return 3; // Acceptable
if (percentage >= 0.40) return 2; // Poor
return 0; // Failed
}
}

# /\*

# PART 7: DAILY GOAL TRACKING

Add to study dashboard (or new separate screen):

1. Show DailyGoalTrackerWidget at top
   - Displays: completed_today / recommended_daily
   - Shows progress bar with motivation message

2. Track completion:
   - When checkpoint quiz is submitted successfully
   - Call reviewService.completeReview(conceptIndex)
   - Increment completed_today counter

3. Show ReviewScheduleWidget below daily goal
   - Displays calendar of upcoming reviews
   - Allows user to view past/future schedule

4. Time-based reset:
   - Reset completed_today at midnight (00:00)
   - Use local device time or server time

Example:

\_completedTodayReviews = 0;
\_recommendedDaily = 10;

void \_onCheckpointQuizSuccess() {
setState(() {
\_completedTodayReviews++;
});

    if (_completedTodayReviews >= _recommendedDaily) {
      // Show celebration
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🎉 Daily goal completed!'),
        backgroundColor: Colors.green,
      ));
    }

}

\*/

# /\*

# PART 8: SETTINGS/PREFERENCES INTEGRATION

Add new "Settings" screen with SpacedRepetitionSettingsWidget:

1. Located in: Settings > Learning Preferences > Spaced Repetition

2. Configurable parameters:
   - Daily Goal: 5-30 reviews (default 10)
   - Learning Difficulty: Easy/Medium/Hard
   - Adaptive Pacing: On/Off
   - Notifications: On/Off

3. Store preferences in:
   - Local SharedPreferences for quick access
   - Backend database for sync across devices

4. Apply preferences:
   - dailyGoal affects DailyGoalTrackerWidget display
   - difficulty affects interval calculation (easinessFactor)
   - adaptivePacing affects SM-2 algorithm sensitivity
   - notifications trigger local push notifications

Example usage:

final prefs = SpacedRepetitionPreferences(
dailyGoal: 12,
easinessFactor: 2.3,
enableNotifications: true,
difficulty: 'hard',
adaptivePacing: true,
);

// Save locally
SharedPreferences.getInstance().then((sp) {
sp.setString('spaced_rep_prefs', jsonEncode(prefs.toJson()));
});

// Use in calculations
final nextReview = SpacedRepetitionService.calculateNextReview(
quality: quizScore,
easinessFactor: prefs.easinessFactor, // < uses preference
previousInterval: lastInterval,
);

\*/

# /\*

# IMPLEMENTATION CHECKLIST

Backend (Server.js):
✅ Create 4 new database tables
✅ Add generateMasteryCheckpointQuiz() function
✅ Add detectStruggleSignals() function
✅ Add 3 new API endpoints
✅ Modify chat-enhanced endpoint to return checkpoint data

Frontend - Services:
✅ checkpoint_quiz_service.dart (API communication)
✅ spaced_repetition_service.dart (SM-2 algorithm)

Frontend - Widgets:
✅ checkpoint_quiz_widget.dart (Interactive quiz UI)
✅ struggle_detection_widget.dart (Alert + Analytics)
✅ review_schedule_widget.dart (Calendar view)
✅ daily_goal_tracker_widget.dart (Progress tracking)
✅ spaced_repetition_settings_widget.dart (Preferences)

Frontend - Integration:
⏳ Integrate checkpointQuizWidget into StudyPlanChatScreen
⏳ Integrate struggle detection bubble displays
⏳ Integrate LearningAnalyticsWidget into dashboard
⏳ Integrate ReviewScheduleWidget into new "Schedule" tab
⏳ Integrate DailyGoalTrackerWidget into study dashboard
⏳ Create Settings screen with preferences

Backend - Phase 2:
⏳ Create concept_review_schedule table
⏳ Create POST /api/schedule-reviews endpoint
⏳ Create GET /api/daily-reviews endpoint
⏳ Integrate with local notification service

Testing:
⏳ Unit tests for SM-2 calculations
⏳ Integration tests for checkpoint flow
⏳ E2E tests for complete learning cycle

\*/

# '''

# QUICK START: Minimal Integration Path

If you want to get something working quickly:

1. Add checkpoint_quiz_widget to StudyPlanChatScreen
   - Wrap in FutureBuilder
   - Show when response contains checkpointQuizRequired: true
   - Handle onCompleted callback

2. Show struggle alerts inline with messages
   - Extract struggles array from response
   - Display using buildStruggleUI() helper

3. Add DailyGoalTrackerWidget to study dashboard
   - Static values initially: completed=3, recommended=10
   - Update when quiz submitted

4. Add ReviewScheduleWidget in drawer or future tab
   - Generate sample schedule with dummy data
   - User can see upcoming reviews

5. Later: Connect backend endpoints and store real data

This gives you 80% of the UX with 20% of the development work!

============================================================================
SUPPORT & DEBUGGING
============================================================================

Common Issues:

1. Checkpoint quiz not showing
   - Check: Response contains checkpointQuizRequired: true
   - Check: CheckpointQuiz model can parse JSON
   - Debug: Print response JSON to console

2. Struggle signals not appearing
   - Check: Response contains struggles array
   - Check: StruggleSignal model serialization
   - Debug: Verify signal type matches switch statement

3. SM-2 calculations seem off
   - Check: Quality is 0-5, not percentage
   - Check: Interval calculation follows formula
   - Debug: Use SpacedRepetitionService.debug() for verbose output

4. API communication failing
   - Check: Backend URL is correct
   - Check: Endpoints are implemented
   - Check: CORS headers are set
   - Debug: Check browser DevTools Network tab

Need help? See: DEEP_EXPLANATION_IMPLEMENTATION.md for detailed examples
'''
