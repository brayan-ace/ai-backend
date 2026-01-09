# Phase 2 Quick Reference

## How It Works

### 1. User Flow

```
Phase 1 Confirmation Screen
    ↓ Click "What's Next?"
Phase 2 Chat Interface
    ↓ User responds to bot
State Machine Transitions
    ↓ Changes app behavior
Persistent Session Storage
    ↓ Resumable on app restart
```

### 2. State Transitions (Memory Guide)

```
INTRO → PLAN_PROPOSAL (user says "yes")
PLAN_PROPOSAL → PLAN_APPROVED (user says "approve")
PLAN_PROPOSAL → PLAN_MODIFICATION (user says "modify")
PLAN_MODIFICATION → PLAN_PROPOSAL (system regenerates)
PLAN_APPROVED → LESSON_ACTIVE (user says "start")
LESSON_ACTIVE → ASSESSMENT → REVIEW → COMPLETED
```

### 3. Key Files

| File                             | Purpose                         |
| -------------------------------- | ------------------------------- |
| `study_bot_state.dart`           | Data models for all states      |
| `study_bot_flow_controller.dart` | State machine logic             |
| `study_plan_service.dart`        | Persistence (+ Phase 2 methods) |
| `study_plan_chat_screen.dart`    | UI for Phase 1 & 2              |

### 4. Core Classes

**StudyBotStateType** - The 7 states

```dart
enum StudyBotStateType {
  intro,              // Greeting
  planProposal,       // TOC presented
  planApproved,       // TOC accepted
  planModification,   // User wants changes
  lessonActive,       // Teaching mode
  assessment,         // Quiz mode
  review,             // Summary
  completed           // Finished
}
```

**StudyBotState** - Persisted session data

```dart
class StudyBotState {
  final String sessionId;
  final String botId;
  final StudyBotStateType currentState;
  final List<TableOfContentsItem>? tableOfContents;
  final List<StudyBotMessage>? chatHistory;
  final List<PlanModificationRequest>? modificationHistory;
  // ... other properties
}
```

**StudyBotFlowController** - State machine

```dart
// Key methods:
createNewSession()                    // Initialize
generateTableOfContents()             // Create TOC
canTransitionTo(from, to)             // Validate
transitionTo(state, newState)         // Execute
getBotResponseForState()              // Chat response
```

### 5. Using the State Machine

```dart
// Create session
final flowController = StudyBotFlowController();
final state = flowController.createNewSession(botId: 'bot-123');

// Check if transition is valid
if (flowController.canTransitionTo(state.currentState, newState)) {
  // Execute transition
  var updatedState = flowController.transitionTo(state, newState);
  // Save to persistence
  await planService.saveBotState(updatedState);
}

// Get appropriate bot response
final response = flowController.getBotResponseForState(
  newState,
  botName: 'Alex',
  planName: 'Physics 101',
);
```

### 6. TOC Generation by Level

| Level       | Modules | Difficulty Curve        |
| ----------- | ------- | ----------------------- |
| Primary     | 6       | Mostly beginner         |
| Secondary   | 8       | beginner → intermediate |
| High School | 9       | Linear progression      |
| University  | 10      | Full spectrum           |
| Advanced    | 12      | Deep advanced           |

### 7. Message Types

```dart
// Bot message
final botMsg = StudyBotMessage(
  id: 'msg-1',
  senderType: 'bot',
  text: 'Hi! Are you ready to start?',
  timestamp: DateTime.now(),
);

// User message
final userMsg = StudyBotMessage(
  id: 'msg-2',
  senderType: 'user',
  text: 'Yes, let\'s begin!',
  timestamp: DateTime.now(),
);
```

### 8. Persistence

```dart
// Save session state
final service = StudyPlanService();
await service.saveBotState(state);

// Load later
final loadedState = await service.getBotState(sessionId);

// Get all sessions for a bot
final allSessions = await service.getBotStatesByBotId(botId);
```

### 9. UI Navigation

**Phase 1 → Phase 2:**

```dart
Navigator.of(context).pushReplacement(
  MaterialPageRoute(
    builder: (_) => StudyPlanChatScreen(
      botId: botId,
      planName: planName,
      planDescription: planDescription,
      botName: botName,
      educationLevel: educationLevel,
      // No initialState = will create new Phase 2 session
    ),
  ),
);
```

### 10. State Validation Rules

```
Valid transitions enforced by canTransitionTo():
✓ intro → planProposal
✓ planProposal → {planApproved, planModification}
✓ planModification → planProposal
✓ planApproved → lessonActive
✓ lessonActive → {assessment, lessonActive}
✓ assessment → {review, lessonActive}
✓ review → {completed, lessonActive}

Invalid transitions rejected:
✗ intro → assessment (skip steps)
✗ planApproved → intro (go backward)
✗ completed → planProposal (restart not defined)
```

## Testing Scenarios

### Scenario 1: First-time User

1. Create Study Bot (Phase 1)
2. Click "What's Next?" → Chat screen (Phase 2)
3. Bot shows greeting (INTRO state)
4. User says "yes"
5. Bot generates TOC (PLAN_PROPOSAL state)
6. User says "approve"
7. Bot ready for lessons (PLAN_APPROVED state)
   ✅ Session persisted

### Scenario 2: User Modifies Plan

1. At PLAN_PROPOSAL state
2. User says "modify"
3. State → PLAN_MODIFICATION
4. User describes changes
5. Bot regenerates TOC
6. State → PLAN_PROPOSAL (back to approval)
7. User approves
8. State → PLAN_APPROVED
   ✅ Modification history saved

### Scenario 3: Session Resume

1. App closes during PLAN_APPROVED state
2. User reopens app and navigates to chat
3. System detects existing session
4. Loads from SharedPreferences
5. Resumes at PLAN_APPROVED
6. Chat history restored
7. User can continue
   ✅ Seamless resume

## Common Tasks

### Add New State

```dart
// 1. Add to enum
enum StudyBotStateType {
  ..., newState, ...
}

// 2. Add response in getBotResponseForState()
case StudyBotStateType.newState:
  return 'Your response here';

// 3. Add transitions in canTransitionTo()
StudyBotStateType.someOtherState: {
  StudyBotStateType.newState,
},
```

### Modify TOC Generation

```dart
// Edit _generateBaseModules() in flow controller
// Or _getDifficultyProgression()
// Or _getTimeEstimate()
// Or _generateModuleTitle()
// All methods configurable without breaking state machine
```

### Add User Intent Detection

```dart
// In _processUserMessage() method
if (userMessage.toLowerCase().contains('restart')) {
  nextState = StudyBotStateType.intro;
}
```

## Debugging Tips

### Check Current State

```dart
print('Current state: ${_botState?.currentState}');
```

### View Chat History

```dart
for (var msg in _messages) {
  print('${msg.senderType}: ${msg.text}');
}
```

### Check Persistence

- SharedPreferences key: `myai_bot_states_v1`
- Contains all StudyBotState objects as JSON
- Each session keyed by sessionId

### Invalid Transition Error

```
StateError: Invalid transition from INTRO to LESSON_ACTIVE
→ This means user skipped approval step
→ Check canTransitionTo() logic
→ Verify state machine rules
```

## Performance Notes

- TOC generation: O(n) where n = module count (typically 6-12)
- State transitions: O(1)
- Message persistence: Async, doesn't block UI
- Chat UI: Efficient ListView with lazy loading
- No memory leaks: Proper dispose() of TextEditingController

## Known Limitations (By Design)

1. No AI responses yet (template-based only)
2. No actual lesson content (infrastructure ready)
3. No quiz/assessment implementation (state prepared)
4. No multi-language support yet
5. No voice input yet
6. No adaptive learning yet

All limitations can be addressed in future phases without architectural changes.
