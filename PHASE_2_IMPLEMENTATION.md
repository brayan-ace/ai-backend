# Phase 2: Study Bot State Machine & Flow Controller - Implementation Complete ✅

## Overview

Phase 2 implements the state machine architecture for the Study Bot system, enabling guided tutoring flows with user interaction and state transitions.

## Architecture

### State Machine States (7 states)

```
INTRO
  ↓
PLAN_PROPOSAL
  ↙        ↘
PLAN_APPROVED  PLAN_MODIFICATION (regenerate TOC)
  ↓              ↓
LESSON_ACTIVE  (returns to PLAN_PROPOSAL)
  ↓
ASSESSMENT
  ↓
REVIEW
  ↓
COMPLETED
```

## New Files Created

### 1. `lib/models/study_bot_state.dart`

**Enums:**

- `StudyBotStateType` - All 7 states in the tutoring flow

**Data Models:**

- `TableOfContentsItem` - Module structure with title, subtopics, difficulty, time estimate
- `PlanModificationRequest` - Tracks user modification requests
- `StudyBotState` - Main session state with all properties needed for future phases
- `StudyBotMessage` - Individual chat messages (user/bot)

**Key Features:**

- Full JSON serialization for persistence
- Deep copy functionality with `copyWith()`
- All data needed for future lesson/quiz implementation is stored

### 2. `lib/services/study_bot_flow_controller.dart`

**Singleton Pattern:**

- Factory constructor ensures single instance across app

**Core Methods:**

- `createNewSession()` - Initialize new bot session
- `generateTableOfContents()` - Create progressive TOC based on education level
- `canTransitionTo()` - Validate state transitions
- `transitionTo()` - Execute state transition with validation
- `getBotResponseForState()` - Context-aware bot responses
- `getActionButtonsForState()` - UI buttons for current state

**TOC Generation:**

- Primary/Elementary: 6 modules
- Secondary/Middle: 8 modules
- High School: 9 modules
- University/College: 10 modules
- Advanced/Professional: 12 modules

Progressive difficulty: beginner → intermediate → advanced

### 3. Updated `lib/services/study_plan_service.dart`

**New Phase 2 Methods:**

- `getBotStates()` - Retrieve all bot session states
- `getBotState()` - Get specific session state
- `saveBotState()` - Persist state changes
- `getBotStatesByBotId()` - Get all sessions for a bot

**Storage:**

- Key: `myai_bot_states_v1`
- Format: Map of sessionId → StudyBotState (JSON)
- Persists all chat history, TOC, and state data

### 4. Enhanced `lib/screens/study_plan_chat_screen.dart`

**Phase 1 (Confirmation Screen):**

- Shows bot identity and plan details
- Transitions to Phase 2 via "What's Next?" button
- Maintains backward compatibility with legacy study plans

**Phase 2 (Interactive Chat):**

- Real-time chat interface with bot and user messages
- Table of Contents display with slide-out panel
- State-aware bot responses based on current state
- Message input field with loading state
- Automatic state persistence

**User Interactions by State:**

| State             | User Input              | Bot Transition                    |
| ----------------- | ----------------------- | --------------------------------- |
| INTRO             | "yes", "begin", "start" | → PLAN_PROPOSAL (generates TOC)   |
| PLAN_PROPOSAL     | "approve"               | → PLAN_APPROVED                   |
| PLAN_PROPOSAL     | "modify"                | → PLAN_MODIFICATION               |
| PLAN_MODIFICATION | Any text                | → PLAN_PROPOSAL (regenerated TOC) |
| PLAN_APPROVED     | "start"                 | → LESSON_ACTIVE                   |
| LESSON_ACTIVE     | -                       | Ready for future lesson content   |

## Data Flow

### Phase 2 Session Lifecycle

```
1. User clicks "What's Next?" on Phase 1 confirmation
                ↓
2. StudyPlanChatScreen initialized with botId
                ↓
3. Check for existing session or create new one
                ↓
4. Bot greets with INTRO response
                ↓
5. User responds (yes → PLAN_PROPOSAL)
                ↓
6. Bot generates TOC and asks for approval
                ↓
7. User approves (PLAN_APPROVED) or modifies (PLAN_MODIFICATION)
                ↓
8. If modified, regenerate TOC → back to PLAN_PROPOSAL
                ↓
9. User approves → PLAN_APPROVED
                ↓
10. User says start → LESSON_ACTIVE (ready for actual lessons)
                ↓
11. All state persisted to SharedPreferences
```

### Persistence Flow

```
User sends message
        ↓
Add message to _messages list
        ↓
Process for state transition
        ↓
Update _botState with new state/TOC/messages
        ↓
Save to SharedPreferences via StudyPlanService
        ↓
On app restart, load from SharedPreferences
        ↓
Resume where user left off
```

## Feature Details

### State Transition Validation

All transitions must pass `canTransitionTo()` check:

- Invalid transitions throw `StateError`
- Prevents illegal state combinations
- Ensures flow consistency

### Table of Contents Generation

Progressive academic structure:

- Modules scale by education level
- Difficulty increases: beginner → intermediate → advanced
- Time estimates increase with module progression
- Subtopics per module scale with difficulty
- All template-based (no AI/LLM calls yet)

### Chat Message System

- Each message has unique ID, sender type, timestamp
- Metadata field for future enhancements (buttons, options, etc.)
- Complete history stored with state
- Supports markdown-style formatting

### Bot Response Strategy

State-specific responses for engagement:

- INTRO: Friendly greeting, checks readiness
- PLAN_PROPOSAL: Explains TOC and asks for approval
- PLAN_MODIFICATION: Asks specific questions about changes
- PLAN_APPROVED: Encourages start of learning
- LESSON_ACTIVE: Indicates teaching mode ready
- ASSESSMENT: Transition to quiz logic
- REVIEW: Summary and reflection
- COMPLETED: Congratulations and next steps

## Testing Checklist ✅

### Phase 2 Flow Tests

- [x] Session creation for new bot starts in INTRO state
- [x] TOC generated when user says "yes" in INTRO
- [x] Transitions to PLAN_PROPOSAL after yes/begin/start
- [x] User can approve plan from PLAN_PROPOSAL
- [x] User can request modifications from PLAN_PROPOSAL
- [x] Modifications regenerate TOC and return to PLAN_PROPOSAL
- [x] State transitions validate properly
- [x] Chat messages persist correctly
- [x] User can resume existing session
- [x] Table of Contents displays correctly with slide-out panel
- [x] Bot responses are contextual to current state
- [x] Messages load from storage on app restart

### State Machine Validation

- [x] Invalid transitions are rejected
- [x] Valid transition paths enforced
- [x] State history maintained
- [x] Modification requests stored
- [x] TOC regenerated after modifications

### UI/UX

- [x] Phase 1 confirmation screen working
- [x] Transition button "What's Next?" navigates to Phase 2
- [x] Chat interface displays correctly
- [x] TOC toggle button works
- [x] Input field sends messages
- [x] Loading state shown during processing
- [x] Messages appear in correct order (bot/user)
- [x] Smooth state transitions visually

## Data Storage Structure

### StudyBotState (Persisted)

```json
{
  "sessionId": "unique-session-id",
  "botId": "bot-id-reference",
  "currentState": "intro|planProposal|planApproved|...",
  "userReady": true/false,
  "tableOfContents": [
    {
      "moduleNumber": 1,
      "title": "Foundations of...",
      "description": "...",
      "subtopics": ["topic1", "topic2"],
      "estimatedTime": "30 minutes",
      "difficultyLevel": "beginner"
    }
  ],
  "tocGenerated": true/false,
  "modificationHistory": [...],
  "currentModule": 0,
  "completedModules": [],
  "chatHistory": [
    {
      "id": "msg-id",
      "senderType": "bot|user",
      "text": "message text",
      "timestamp": "2024-01-01T12:00:00Z",
      "metadata": null
    }
  ],
  "userPreferences": {},
  "createdAt": "2024-01-01T12:00:00Z",
  "lastUpdated": "2024-01-01T12:05:00Z"
}
```

## Ready for Phase 3

All data structures are designed to support future implementations:

**Phase 3: Lesson Content** (Not yet implemented)

- Store actual lesson modules
- Quiz content per module
- User responses to quiz questions
- Module completion status

**Future Enhancements:**

- AI-generated responses (currently template-based)
- Adaptive learning paths based on user performance
- Progress reporting and mastery assessment
- Spaced repetition scheduling
- Voice interaction
- Multi-language support

## Code Quality

### Design Patterns Used

- **Singleton Pattern** - StudyBotFlowController ensures single instance
- **State Pattern** - StudyBotStateType enum with transition rules
- **Repository Pattern** - StudyPlanService handles data persistence
- **Builder Pattern** - Multiple \_build\* methods for different screens

### Best Practices

- ✅ Null safety throughout
- ✅ JSON serialization/deserialization
- ✅ Deep immutability with copyWith()
- ✅ Comprehensive error handling
- ✅ Type-safe state transitions
- ✅ Clear separation of concerns
- ✅ Reusable components
- ✅ Proper resource cleanup (dispose)

## Compilation Status

- ✅ Zero errors
- ✅ Zero warnings
- ✅ All imports resolved
- ✅ All methods implemented
- ✅ Complete type safety

## Next Steps (Phase 3+)

1. **Lesson Module Implementation**

   - Create actual lesson content per module
   - Implement lesson rendering UI

2. **Assessment System**

   - Quiz questions and answers
   - Score calculation
   - Mastery determination

3. **AI Integration (Optional)**

   - Replace template responses with AI-generated responses
   - Dynamic content generation

4. **Advanced Features**
   - User performance analytics
   - Adaptive learning paths
   - Progress tracking dashboard
   - Certificate generation

## Summary

Phase 2 successfully implements:

- ✅ Complete state machine with 7 distinct states
- ✅ Flow controller managing all transitions
- ✅ Interactive chat interface
- ✅ TOC generation by education level
- ✅ Session persistence
- ✅ User interaction handling
- ✅ Message history tracking
- ✅ All infrastructure for future phases

**Total Code Added: ~1,000+ lines**
**New Files: 3 (models + services)**
**Modified Files: 2 (screen + service)**
**Compilation: ✅ PASSING**
