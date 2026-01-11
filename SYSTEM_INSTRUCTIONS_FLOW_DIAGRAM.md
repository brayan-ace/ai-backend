# System Instructions Flow Diagram

## Before the Fix (Stale Instructions)

```
Bot Created (Time T=0)
  ↓
Backend: Store instructions in DB
Frontend: Receive & store in memory
  ↓
[Time passes...]
  ↓
User makes changes to system instructions
Database: UPDATED ✓
Frontend: Still using OLD cached version ✗
  ↓
Result: Changes don't appear in app!
```

---

## After the Fix (Always Fresh)

```
Bot Created (Time T=0)
  ↓
Backend: Store instructions in DB
Frontend: Receive instructions (but will refresh later)
  ↓
User Opens Bot Chat Screen
  ↓
Frontend calls: GET /api/bot/:botId/instructions
  ↓
Backend queries: SELECT system_instructions FROM study_bots
  ↓
Frontend receives: LATEST instructions from database
  ↓
Frontend stores: Fresh instructions in _botInstructions
  ↓
User sends message
  ↓
Backend also queries DB again (uses LATEST)
  ↓
Result: Always uses current instructions! ✓
```

---

## Data Flow: User → Frontend → Backend → Database

```
┌─────────────────────────────────────────────────────────────────┐
│                     FLUTTER APP (Frontend)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  StudyPlanChatScreen                                            │
│  ├─ initState()                                                 │
│  │  └─ _initPhase2()                                            │
│  │     ├─ Load chat history (existing messages)                │
│  │     ├─ Load bot progress (state, modules)                   │
│  │     └─ _fetchFreshSystemInstructions(botId) ← NEW!          │
│  │        │                                                     │
│  │        └─ HTTP GET /api/bot/:botId/instructions             │
│  │           └─ Updates _botInstructions = fresh data          │
│  │                                                              │
│  ├─ _sendMessageToBackend(message)                             │
│  │  └─ HTTP POST /api/chat-enhanced                            │
│  │     ├─ Send: message + botId + userId                       │
│  │     ├─ Send: _botInstructions (for reference)               │
│  │     └─ Receive: bot response + state                        │
│  │                                                              │
│  └─ Display bot response to user                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ (HTTP Requests)
                              │
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   NODE.JS BACKEND (server.js)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  New Endpoints:                                                 │
│  ├─ GET /api/bot/:botId/instructions                           │
│  │  └─ Query DB: SELECT system_instructions FROM study_bots    │
│  │     └─ Return: Fresh instructions object                    │
│  │                                                              │
│  ├─ PUT /api/bot/:botId/instructions                           │
│  │  └─ Update DB: UPDATE study_bots SET system_instructions    │
│  │     └─ Return: Updated instructions                         │
│  │                                                              │
│  ├─ GET /api/debug/bot/:botId                                  │
│  │  └─ Query DB: SELECT * FROM study_bots                      │
│  │     └─ Return: Full bot data (for debugging)                │
│  │                                                              │
│  Existing Endpoints (Already using DB):                         │
│  ├─ POST /api/chat-enhanced                                    │
│  │  └─ Query DB: SELECT system_instructions FROM study_bots    │
│  │  └─ Always uses LATEST instructions from database           │
│  │  └─ Generates bot response using fresh instructions         │
│  │                                                              │
│  └─ POST /api/create-study-bot                                 │
│     └─ INSERT into study_bots with generated instructions      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ (SQL Queries)
                              │
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              PostgreSQL DATABASE (study_bots table)             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Columns:                                                       │
│  ├─ bot_id: "bot_1768095418663_9978"                          │
│  ├─ user_id: "8iEGV6zsZtON8kNlZtcLypU24f53"                   │
│  ├─ name: "nutri"                                              │
│  ├─ topic: "Autotrophs"                                        │
│  ├─ grade_level: "Senior Secondary"                            │
│  ├─ system_instructions: {                                     │
│  │    "bot_name": "nutri",                                     │
│  │    "instructions": "You are a warm...",  ← LATEST VERSION  │
│  │    "topic": "Autotrophs",                                   │
│  │    "grade_level": "Senior Secondary",                       │
│  │    "generated_at": "2026-01-11T...",                        │
│  │    "is_natural_bot": true                                   │
│  │  }                                                           │
│  ├─ state: {...}                                               │
│  └─ created_at: "2026-01-11T..."                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Sequence Diagram: Fresh Instructions Flow

```
User Opens             Frontend               Backend              Database
Chat Screen              │                       │                    │
    │                    │                       │                    │
    ├──────────────────>│                       │                    │
    │  initState()      │                       │                    │
    │                   │                       │                    │
    │                   ├──────────────────────>│                    │
    │                   │  GET /api/chat-history                     │
    │                   │  (existing messages)                       │
    │                   │                       │                    │
    │                   │<──────────────────────┤                    │
    │                   │  Return messages      │                    │
    │                   │                       │                    │
    │                   ├──────────────────────>│                    │
    │                   │  GET /api/bot/:botId/instructions  ← NEW! │
    │                   │                       │                    │
    │                   │                       ├───────────────────>│
    │                   │                       │  SELECT            │
    │                   │                       │  system_instructions
    │                   │                       │<───────────────────┤
    │                   │                       │  Returns fresh data│
    │                   │<──────────────────────┤                    │
    │                   │  Fresh instructions   │                    │
    │                   │  (LATEST from DB)     │                    │
    │                   │                       │                    │
    │  Updates state    │                       │                    │
    │  with fresh data  │                       │                    │
    │<──────────────────┤                       │                    │
    │  ✅ Chat ready    │                       │                    │
    │  with fresh       │                       │                    │
    │  instructions     │                       │                    │
    │                   │                       │                    │
User types message      │                       │                    │
    │                   │                       │                    │
    ├──────────────────>│                       │                    │
    │                   ├──────────────────────>│                    │
    │                   │  POST /api/chat-enhanced                   │
    │                   │  message + botId      │                    │
    │                   │  (+ fresh instructions)                    │
    │                   │                       │                    │
    │                   │                       ├───────────────────>│
    │                   │                       │  SELECT            │
    │                   │                       │  system_instructions
    │                   │                       │  (ALWAYS latest)   │
    │                   │                       │<───────────────────┤
    │                   │                       │  Fresh instructions│
    │                   │                       │                    │
    │                   │                       │  Generate response │
    │                   │<──────────────────────┤                    │
    │                   │  Bot response         │                    │
    │<──────────────────┤  (using LATEST        │                    │
    │  Display message  │   instructions)       │                    │
    │                   │                       │                    │
```

---

## Key Points

1. **Frontend Fetches Fresh Instructions**

   - When chat screen loads
   - Via GET /api/bot/:botId/instructions
   - Stores in `_botInstructions` state variable

2. **Backend Always Uses DB Version**

   - Never relies on frontend-provided instructions
   - Always queries database in chat endpoint
   - Gets LATEST version every message

3. **Double Protection**

   - Frontend has fresh copy (for UI logic)
   - Backend fetches fresh copy (for AI generation)
   - Even if frontend is stale, backend uses latest

4. **No More Stale Data**
   - Changes to system instructions immediately visible
   - Both frontend and backend always in sync
   - Debugging endpoint shows exact DB state
