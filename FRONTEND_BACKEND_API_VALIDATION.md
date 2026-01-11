# Frontend-Backend API Call Validation

## Overview

This document maps all frontend API calls to backend endpoints and validates that system instructions are properly passed and used.

## 1. INITIAL GREETING FLOW

### Frontend Call (`_fetchInitialGreeting`)

**File:** `lib/screens/study_plan_chat_screen.dart` (Lines 375-413)

```dart
final payload = {
  'message': '[START_SESSION]',     // ✅ Special trigger
  'botId': widget.botId,             // ✅ Bot identifier
  'userId': userId,                  // ✅ User identifier
  'systemInstructions': _botInstructions,  // ✅ Instructions included
};

final resp = await http.post(
  '$_backendUrl/api/chat-enhanced',  // ✅ Correct endpoint
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode(payload),
);
```

### Backend Handler

**File:** `backend/server.js` (Lines 1442-1576)

```javascript
app.post("/api/chat-enhanced", async (req, res) => {
  const { message, botId, userId, systemInstructions } = req.body;

  // ✅ Step 1: Check for [START_SESSION]
  if (message === "[START_SESSION]") {
    console.log("⭐ SPECIAL MESSAGE DETECTED: [START_SESSION]");

    // ✅ Step 2: Load bot's system instructions from database
    const systemPrompt = finalSystemInstructions?.instructions || fallback;

    // ✅ Step 3: Call Groq with system instructions
    const chatCompletion = await axios.post(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        messages: [
          {
            role: "system",
            content: systemPrompt, // 👈 THIS IS WHERE INSTRUCTIONS ARE USED
          },
          {
            role: "user",
            content:
              "Hi, I'm starting a study session with you. Please greet me warmly.",
          },
        ],
        model: "mixtral-8x7b-32768",
      }
    );

    // ✅ Step 4: Return AI-generated greeting
    botResponse = chatCompletion.data.choices[0]?.message?.content;
  }
});
```

**Flow Verification:**

- ✅ Frontend sends `[START_SESSION]` → Backend recognizes it
- ✅ System instructions used to prompt Groq
- ✅ Groq generates personalized greeting
- ✅ Response sent back to frontend

---

## 2. SYSTEM INSTRUCTIONS FETCH

### Frontend Call (`_fetchFreshSystemInstructions`)

**File:** `lib/screens/study_plan_chat_screen.dart` (Lines 328-351)

```dart
final uri = Uri.parse('$_backendUrl/api/bot/$botId/instructions');
final response = await http.get(uri).timeout(const Duration(seconds: 10));

if (response.statusCode == 200) {
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final freshInstructions = body['systemInstructions'] as Map<String, dynamic>?;

  if (freshInstructions != null) {
    setState(() {
      _botInstructions = freshInstructions;  // ✅ Stored for use in messages
    });
    print('[ChatScreen] ✅ Fresh system instructions fetched and updated');
  }
}
```

### Backend Endpoint

**File:** `backend/server.js` (Lines 1089-1140)

```javascript
app.get("/api/bot/:botId/instructions", async (req, res) => {
  const { botId } = req.params;

  try {
    const result = await pool.query(
      `SELECT system_instructions, name, topic FROM study_bots WHERE bot_id = $1`,
      [botId]
    );

    if (result.rows.length > 0) {
      const bot = result.rows[0];
      return res.json({
        status: "success",
        systemInstructions: bot.system_instructions,
        botName: bot.name,
        topic: bot.topic,
      });
    }
  } catch (err) {
    console.error("[api/bot/:botId/instructions] Error:", err.message);
    return res.status(500).json({ error: err.message });
  }
});
```

**Flow Verification:**

- ✅ Frontend requests fresh instructions
- ✅ Backend fetches from database
- ✅ Frontend stores in `_botInstructions`
- ✅ Instructions used in all subsequent messages

---

## 3. REGULAR MESSAGE FLOW

### Frontend Call (`_sendMessageToBackend`)

**File:** `lib/screens/study_plan_chat_screen.dart` (Lines 480-534)

```dart
final payload = {
  'message': userMessage,            // ✅ User input
  'botId': widget.botId,             // ✅ Bot identifier
  'userId': userId,                  // ✅ User identifier
  'systemInstructions': _botInstructions,  // ✅ Instructions ALWAYS included
};

final resp = await http.post(
  '$_backendUrl/api/chat-enhanced',  // ✅ Same endpoint
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode(payload),
);
```

### Backend Handler (Regular Messages)

**File:** `backend/server.js` (Lines 1577-1750)

```javascript
// Regular user messages (not [START_SESSION])
else {
  console.log("💬 REGULAR MESSAGE - Saving to database");
  await pool.query(
    `INSERT INTO chat_messages (bot_id, user_id, message_type, content)
     VALUES ($1, $2, $3, $4)`,
    [botId, userId, "user", message]
  );
}

// STATE MACHINE - Uses system instructions from database
if (progress.bot_state === "intro" && message !== "[START_SESSION]") {
  console.log("🔄 STATE: intro (user not ready yet)");
  // Uses finalSystemInstructions to respond
}

// LEARNING STATE - Uses system instructions with Groq
else if (progress.bot_state === "learning") {
  const instructionsText = finalSystemInstructions?.instructions || fallback;

  const groqMessages = [
    { role: "system", content: instructionsText },  // 👈 INSTRUCTIONS HERE
    ...chatHistory,
    { role: "user", content: message }
  ];

  const groqRes = await axios.post("https://api.groq.com/openai/v1/chat/completions", {
    messages: groqMessages,
    model: "openai/gpt-oss-20b",
  });
}
```

**Flow Verification:**

- ✅ Frontend sends message with instructions
- ✅ Backend checks bot_state
- ✅ Backend loads instructions from database
- ✅ Uses instructions in state machine AND Groq API
- ✅ Response sent back with updated state

---

## Complete Call Chain Diagram

```
FRONTEND                          BACKEND                        DATABASE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PHASE 1: INSTRUCTIONS FETCH
┌─ GET /api/bot/:botId/instructions ──→ Query study_bots table
│                                        ↓
└─ Receive systemInstructions ←─ Return from DB
                                        ↑
                                   SELECT system_instructions
                                   FROM study_bots
                                   WHERE bot_id = $1

PHASE 2: INITIAL GREETING
┌─ POST /api/chat-enhanced ──────────→ Recognize [START_SESSION]
│   message: [START_SESSION]            ↓
│   botId: ...                       Load instructions from DB
│   userId: ...                         ↓
│   systemInstructions: {...}       Call Groq API
│                                      ↓
└─ Response: {                      Use instructions as system prompt
    response: "AI Greeting",         ↓
    state: "intro",              Groq generates greeting
    ...                              ↓
  }                              Store in chat_messages
                                     ↑
                                INSERT INTO chat_messages

PHASE 3: REGULAR MESSAGES
┌─ POST /api/chat-enhanced ──────────→ Get bot progress from DB
│   message: "user text"               ↓
│   botId: ...                      Load system_instructions
│   userId: ...                         ↓
│   systemInstructions: {...}       Check bot_state
│                                      ↓
│                                   If "intro": State response
│                                   If "learning": Call Groq
│                                      ↓
└─ Response: {                      Use instructions for response
    response: "Bot reply",           ↓
    state: "...",               Save to chat_messages
    ...                             ↓
  }                          UPDATE bot_progress

DATABASE SCHEMA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

study_bots:
  bot_id (PK)
  system_instructions (JSONB) ← Instructions fetched here
  name
  topic
  grade_level

bot_progress:
  bot_id (FK)
  user_id (FK)
  bot_state          ← Used to determine response type
  study_plan
  current_module
  completed_modules
  progress_percentage

chat_messages:
  bot_id
  user_id
  message_type       ← "user" or "bot"
  content
  created_at
```

---

## Frontend Variables That Track Instructions

### `_botInstructions`

**Set at:** Line 330 in `_fetchFreshSystemInstructions()`
**Used at:**

- Line 376: Sent to backend in `_fetchInitialGreeting()`
- Line 495: Sent to backend in `_sendMessageToBackend()`

**Content:**

```dart
{
  "instructions": "You are a WARM, HUMAN STUDY COMPANION...",
  "bot_name": "sulp",
  "topic": "Sulphur",
  "grade_level": "Senior Secondary",
  "generated_at": "2026-01-11T...",
  "is_natural_bot": true
}
```

### `_botCurrentState`

**Set at:** Line 298 (from progress fetch)
**Updated at:** Line 516 (from backend response)
**Used to:** Determine UI state and flow

---

## Validation Checklist

### Frontend ✅

- [x] `_botInstructions` initialized and populated
- [x] `_fetchFreshSystemInstructions()` called on init
- [x] Instructions passed to `_fetchInitialGreeting()`
- [x] Instructions passed to `_sendMessageToBackend()`
- [x] Logging shows instructions fetched
- [x] Logging shows messages sent with payload

### Backend ✅

- [x] GET `/api/bot/:botId/instructions` returns instructions
- [x] POST `/api/chat-enhanced` receives payload
- [x] [START_SESSION] handler uses instructions
- [x] Regular message handler uses instructions from database
- [x] System instructions passed to Groq API
- [x] State machine checks use instructions
- [x] Logging shows instructions loaded

### Database ✅

- [x] `study_bots` table has `system_instructions` column
- [x] Instructions stored as JSONB
- [x] Instructions updated when bot created
- [x] Instructions updated when changed via API
- [x] Chat history stored in `chat_messages`
- [x] Progress stored in `bot_progress`

---

## Testing Instructions Call Chain

### 1. Create a Bot with Specific Instructions

```
App: Create bot with name="TestBot", topic="Programming"
↓
Backend: Generate default system instructions
↓
Database: Store in study_bots.system_instructions
```

### 2. Verify Frontend Fetches Them

```
App: Navigate to chat screen
↓
Frontend: Call GET /api/bot/:botId/instructions
↓
Log: [ChatScreen] ✅ Fresh system instructions fetched and updated
✓ Verify _botInstructions variable is populated
```

### 3. Verify Initial Greeting Uses Instructions

```
Frontend: Call _fetchInitialGreeting()
  ↓ Sends [START_SESSION]
↓
Backend: Receive [START_SESSION]
  ↓ Load instructions from database
  ↓ Call Groq with instructions
  ↓ Generate greeting
↓
Frontend: Receive greeting
  ↓ Display greeting
Log: [ChatScreen] ✅ AI GREETING RECEIVED from backend
✓ Verify greeting matches bot's personality
```

### 4. Verify Regular Messages Use Instructions

```
Frontend: User sends "Tell me about yourself"
  ↓ Sends message + instructions in payload
↓
Backend: Receive message
  ↓ Load instructions from database
  ↓ Check bot_state (should be "intro")
  ↓ Process with state machine
↓
Frontend: Receive response
Log: [ChatScreen] Response: 200 {...}
✓ Verify response matches bot's personality
```

---

## Common Issues & Fixes

| Issue                              | Where to Check                                                  | Fix                                               |
| ---------------------------------- | --------------------------------------------------------------- | ------------------------------------------------- |
| Greeting is hardcoded, not from AI | Backend logs - look for `✅ AI GREETING GENERATED`              | Verify [START_SESSION] handler is running         |
| Instructions not updating          | Frontend logs - look for `✅ Fresh system instructions fetched` | Check GET `/api/bot/:botId/instructions` endpoint |
| Wrong bot personality in response  | Backend logs - look for instructions loaded                     | Verify correct `botId` is being sent              |
| State not progressing              | Backend logs - look for state checks                            | Verify `_botCurrentState` is updating             |
| Network errors                     | Both logs - look for HTTP 500                                   | Check backend logs for exceptions                 |

---

## Log Search Patterns

### Find all instruction-related logs:

```
grep -n "instructions\|[START_SESSION]\|Fresh system\|Groq" logs.txt
```

### Verify greeting generation:

```
grep "AI GREETING\|SPECIAL MESSAGE\|Groq" backend_logs.txt
```

### Track state machine execution:

```
grep "STATE:\|bot_state\|intro\|learning" backend_logs.txt
```

---

**Last Updated:** January 11, 2026
**Status:** ✅ All API calls properly configured and logging enabled
