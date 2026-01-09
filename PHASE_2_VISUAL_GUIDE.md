# Phase 2: State Machine Visual Guide

## Complete State Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     PHASE 2 STATE MACHINE                       │
└─────────────────────────────────────────────────────────────────┘

                           START (New Session)
                                  ↓
                    ╔════════════════════════╗
                    ║   INTRO STATE          ║
                    ║ - Greeting message     ║
                    ║ - Check readiness      ║
                    ║ - Ask: "Ready to go?"  ║
                    ╚════════════════════════╝
                                  ↓
                    (User: "Yes", "Begin", "Start")
                                  ↓
        ╔═══════════════════════════════════════════════════════╗
        ║         PLAN_PROPOSAL STATE                          ║
        ║ - Generate TOC based on education level              ║
        ║ - Display Table of Contents                          ║
        ║ - Show modules with difficulty progression           ║
        ║ - Ask: "Approve this plan or modify it?"             ║
        ╚═══════════════════════════════════════════════════════╝
              ↙                                            ↘
    (User: "Approve")                           (User: "Modify")
         ↓                                             ↓
    ╔═════════════════╗                    ╔═══════════════════════╗
    ║ PLAN_APPROVED   ║                    ║ PLAN_MODIFICATION     ║
    ║ - TOC approved  ║                    ║ - User requests:      ║
    ║ - Ready for     ║                    ║   • Pace change       ║
    ║   lessons       ║                    ║   • Topic adjustment  ║
    ║ - Ask: "Start?" ║                    ║   • Depth level       ║
    ╚═════════════════╝                    ╚═══════════════════════╝
           ↓                                        ↓
     (User: "Start")                  (Bot: Regenerate TOC)
           ↓                                        ↓
           └─────────────┬──────────────────────────┘
                         ↓
            Back to PLAN_PROPOSAL for re-approval
                         ↓
                  (User: "Approve" again)
                         ↓
                ╔═════════════════╗
                ║ LESSON_ACTIVE   ║
                ║ - Module 1 starts│
                ║ - Teaching mode  │
                ║ - Interactive Q&A│
                ║ - Progress track │
                ╚═════════════════╝
                         ↓
              (After module completion)
                         ↓
                ╔═════════════════╗
                ║ ASSESSMENT      ║
                ║ - Quiz module   │
                ║ - Score calc    │
                ║ - Mastery check │
                ╚═════════════════╝
                         ↓
              (After assessment complete)
                         ↓
                ╔═════════════════╗
                ║ REVIEW          ║
                ║ - Summary       │
                ║ - Mastery level │
                ║ - Recommendations│
                ╚═════════════════╝
                         ↓
              (After final review)
                         ↓
                ╔═════════════════╗
                ║ COMPLETED       ║
                ║ - Plan done     │
                ║ - Certificate   │
                ║ - Celebration   │
                ╚═════════════════╝
```

## User Interaction Map

```
┌────────────────────────────────────────────────────────────────┐
│              USER INTERACTIONS & BOT RESPONSES                 │
└────────────────────────────────────────────────────────────────┘

STATE: INTRO
┌─────────────────────────────────────────┐
│ BOT: "Hi! I'm your study guide for      │
│ this plan. Ready to start?"              │
├─────────────────────────────────────────┤
│ USER INPUTS:                            │
│ ✓ "yes" / "begin" / "start"   →  APPROVED
│ ✗ Other input   →  Re-prompt   │
└─────────────────────────────────────────┘

STATE: PLAN_PROPOSAL
┌─────────────────────────────────────────┐
│ BOT: "Here's your personalized          │
│ learning path with X modules...          │
│ Approve or modify?"                      │
├─────────────────────────────────────────┤
│ USER INPUTS:                            │
│ ✓ "approve"     →  PLAN_APPROVED        │
│ ✓ "modify"      →  PLAN_MODIFICATION    │
│ ✗ Other input   →  Re-ask choice        │
└─────────────────────────────────────────┘

STATE: PLAN_MODIFICATION
┌─────────────────────────────────────────┐
│ BOT: "What would you like to adjust?    │
│ - Pace (faster/slower)                  │
│ - Topics (focus areas)                  │
│ - Depth (technical level)"              │
├─────────────────────────────────────────┤
│ USER INPUT:  Any modification request   │
│ SYSTEM:                                 │
│   1. Extract modification area          │
│   2. Regenerate TOC                     │
│   3. Return to PLAN_PROPOSAL            │
│   4. Show updated plan                  │
└─────────────────────────────────────────┘

STATE: PLAN_APPROVED
┌─────────────────────────────────────────┐
│ BOT: "Excellent! We're ready.           │
│ Let's start Module 1!"                  │
├─────────────────────────────────────────┤
│ USER INPUTS:                            │
│ ✓ "start"       →  LESSON_ACTIVE        │
│ ✗ Other input   →  Encourage start      │
└─────────────────────────────────────────┘

STATE: LESSON_ACTIVE
┌─────────────────────────────────────────┐
│ BOT: "Now teaching Module 1...          │
│ Ready for interactive Q&A"              │
├─────────────────────────────────────────┤
│ (Future implementation)                 │
│ - Lesson content display                │
│ - User questions answered               │
│ - Progress tracking                     │
│ - Move to assessment                    │
└─────────────────────────────────────────┘
```

## Data Persistence Timeline

```
SESSION CREATION
   │
   ↓ (User opens bot)
INIT PHASE 2
   ├─ Check SharedPreferences for existing session
   └─ If not found, create new StudyBotState

   ↓ (Bot sends intro message)
ADD MESSAGE TO HISTORY
   ├─ Create StudyBotMessage object
   ├─ Add to _messages list
   └─ Save StudyBotState with chatHistory

   ↓ (User responds "yes")
PROCESS INPUT & TRANSITION
   ├─ Check canTransitionTo(INTRO, PLAN_PROPOSAL)
   ├─ Generate TOC
   ├─ Update _botState
   ├─ Add bot response to messages
   └─ Call planService.saveBotState()

   ↓ (Stored in SharedPreferences)
PERSISTED STATE
   ├─ Key: myai_bot_states_v1
   └─ Contains all StudyBotState objects as JSON

   ↓ (App closed and reopened)
SESSION RESUME
   ├─ Load from SharedPreferences
   ├─ Restore _botState
   ├─ Restore _messages
   └─ Show existing conversation
```

## State Properties Matrix

```
┌─────────────────────────────────────────────────────────────────┐
│  STATE PROPERTIES FILLED/USED BY EACH STATE                     │
└─────────────────────────────────────────────────────────────────┘

                    │ INTRO │ PLAN  │ PLAN  │ LESSON│ ASSESS│ REVIEW│
                    │       │ PROP  │ APPRO │ ACTIVE│       │       │
────────────────────┼───────┼───────┼───────┼───────┼───────┼───────┤
currentState        │   ✓   │   ✓   │   ✓   │   ✓   │   ✓   │   ✓   │
userReady           │   ✓   │       │       │       │       │       │
tableOfContents     │       │   ✓   │   ✓   │   ✓   │   ✓   │   ✓   │
tocGenerated        │       │   ✓   │   ✓   │   ✓   │   ✓   │   ✓   │
modificationHistory │       │       │   ✓   │       │       │       │
currentModule       │       │       │   1   │   ✓   │   ✓   │   ✓   │
completedModules    │       │       │       │   ✓   │   ✓   │   ✓   │
currentAssessment   │       │       │       │       │   ✓   │       │
chatHistory         │   ✓   │   ✓   │   ✓   │   ✓   │   ✓   │   ✓   │
userPreferences     │       │       │   ✓   │       │       │       │
```

## Message Exchange Sequence

```
User Opens App
     │
     ├─→ Phase 1: Show confirmation screen
     │       "Here's your bot: Alex"
     │       [Bot Name] [Education Level]
     │       [Plan Details]
     │   Button: "What's Next?"
     │
     └─→ Click "What's Next?"
         │
         ├─→ Create Phase 2 Session (INTRO state)
         │
         ├─→ Bot Message #1:
         │   "Hi! I'm Alex, your personal study guide for
         │    Physics 101. Are you ready to begin?"
         │   ├─ Sender: "bot"
         │   ├─ State: INTRO
         │   └─ Timestamp: 12:00:00
         │
         ├─→ User Types: "Yes, let's start"
         │
         ├─→ User Message #1:
         │   "Yes, let's start"
         │   ├─ Sender: "user"
         │   ├─ Timestamp: 12:00:05
         │   └─ Saved to SharedPreferences
         │
         ├─→ System: Process message
         │   ├─ Transition: INTRO → PLAN_PROPOSAL
         │   ├─ Generate TOC (8 modules, education: secondary)
         │   └─ Update _botState
         │
         ├─→ Bot Message #2:
         │   "Great! I've prepared a personalized
         │    learning path. Here's your Table of Contents...
         │    Would you like to approve or modify?"
         │   ├─ Sender: "bot"
         │   ├─ State: PLAN_PROPOSAL
         │   └─ TableOfContents: [8 modules]
         │
         ├─→ Display TOC with modules
         │   Module 1: Foundations... (beginner)
         │   Module 2: Core Concepts... (beginner)
         │   ... etc
         │
         └─→ User Responds: "Approve"
            [Cycle continues...]
```

## Education Level → Module Count

```
╔════════════════════════════════════════════════╗
║  EDUCATION LEVEL  │  MODULES  │  DIFFICULTY    ║
╠═══════════════════╪═══════════╪════════════════╣
║ Primary (K-5)     │    6      │ ••              ║
║ Elementary        │    6      │ ••              ║
╠═══════════════════╪═══════════╪════════════════╣
║ Secondary (6-8)   │    8      │ ••••            ║
║ Middle School     │    8      │ ••••            ║
╠═══════════════════╪═══════════╪════════════════╣
║ High School       │    9      │ •••••           ║
║ Secondary School  │    9      │ •••••           ║
╠═══════════════════╪═══════════╪════════════════╣
║ University        │   10      │ ••••••          ║
║ College           │   10      │ ••••••          ║
╠═══════════════════╪═══════════╪════════════════╣
║ Advanced          │   12      │ ••••••••        ║
║ Professional      │   12      │ ••••••••        ║
╚════════════════════════════════════════════════╝

Module progression: Each module builds on previous
Difficulty curve: Linear from beginner → advanced
Time estimate: Increases with difficulty
Subtopics: More for advanced modules
```

## Valid State Paths (Green = Valid)

```
              INTRO
                ↓
         PLAN_PROPOSAL
            ↙      ↘
    PLAN_APPROVED  PLAN_MODIFICATION
         ↓              ↓
    LESSON_ACTIVE ←─────┘
         ↓
     ASSESSMENT
         ↓
       REVIEW
         ↓
      COMPLETED

Invalid attempts:
❌ INTRO → ASSESSMENT (skip steps)
❌ PLAN_APPROVED → INTRO (go back)
❌ LESSON_ACTIVE → PLAN_PROPOSAL (restart undefined)
❌ COMPLETED → anything (end state)
```

## Error Handling Flow

```
User Input Received
        ↓
┌──────────────────────────┐
│ VALIDATE TRANSITION      │
│ canTransitionTo(curr,    │
│ next)?                   │
└──────────────────────────┘
    ↙               ↘
  YES               NO
   ↓                ↓
Execute        Throw StateError
transition      & Show error
   ↓             ↓
Update bot    Keep current state
state         Ask for valid input
   ↓
Save to
persistence
   ↓
SUCCESS
```

This visual guide helps understand:
✅ What state the bot is in
✅ What the user can do
✅ How data flows through the system
✅ What gets persisted
✅ How to resume sessions
✅ Why certain transitions are blocked
