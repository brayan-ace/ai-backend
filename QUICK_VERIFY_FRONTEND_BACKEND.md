# Quick Frontend-Backend Verification Script

## One-Minute Verification

Run these commands to verify everything is working:

### 1. Check Backend is Live

```bash
curl https://ai-backend-vf75.onrender.com/api/health
# Should return: {"status":"running"} or similar
```

### 2. Create a Test Bot

Use the app to create a new bot:

- Name: "VerifyBot"
- Topic: "Testing"
- Grade: Any
- Copy the Bot ID from logs

### 3. Verify Instructions Endpoint

```bash
BOTID="bot_YOUR_ID_HERE"
curl "https://ai-backend-vf75.onrender.com/api/bot/$BOTID/instructions"
# Should return JSON with systemInstructions field
```

### 4. Test [START_SESSION] Handler

```bash
curl -X POST "https://ai-backend-vf75.onrender.com/api/chat-enhanced" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "[START_SESSION]",
    "botId": "'$BOTID'",
    "userId": "test-user-123",
    "systemInstructions": {}
  }'
# Should return a greeting (not hardcoded)
```

### 5. Check Logs

```
Frontend logs should show:
✅ _fetchInitialGreeting() CALLED
✅ Payload: message=[START_SESSION]
✅ AI GREETING RECEIVED from backend

Backend (Render) logs should show:
🔵 [POST /api/chat-enhanced] NEW REQUEST
⭐ SPECIAL MESSAGE DETECTED: [START_SESSION]
✅ AI GREETING GENERATED
```

---

## Full Integration Test

### Step 1: Monitor Render Logs

Go to: https://dashboard.render.com → ai-backend → Logs
Leave this tab open and watch for real-time logs.

### Step 2: Open App and Create Bot

1. Open app on device/emulator
2. Create a new bot with custom instructions
3. Copy bot ID from app logs

### Step 3: Open Bot Chat

1. Tap the newly created bot
2. Watch app logs for:
   ```
   [ChatScreen] 🎯 _fetchInitialGreeting() CALLED
   [ChatScreen] 📨 Payload: message=[START_SESSION]
   [ChatScreen] ✅ AI GREETING RECEIVED from backend
   ```

### Step 4: Check Backend Logs

In Render logs, look for:

```
🔵 ===== [POST /api/chat-enhanced] NEW REQUEST =====
📨 Message: "[START_SESSION]"
⭐ SPECIAL MESSAGE DETECTED: [START_SESSION]
📋 System Prompt loaded
🔗 Calling Groq API for greeting generation...
✅ AI GREETING GENERATED
📝 Response: "Greeting from AI..."
📤 Sending response with greeting
🔵 ===== END CHAT-ENHANCED REQUEST =====
```

### Step 5: Verify Output

- Greeting appears in app chat ✅
- Greeting is from AI (different each time) ✅
- Greeting matches bot personality ✅
- No errors in logs ✅

---

## Testing Different Scenarios

### Scenario 1: Fresh Instructions

1. Update bot instructions via API
2. Restart app
3. Open bot chat
4. Verify greeting reflects new instructions

### Scenario 2: Multiple Bots

1. Create bot A with instructions: "Respond in pirate speak"
2. Create bot B with instructions: "Respond like a scientist"
3. Open each bot's chat
4. Verify each greeting is different

### Scenario 3: Network Issue

1. Disconnect network while app loads
2. App should show error gracefully
3. Logs should show network error
4. App should continue functioning

---

## API Contract Verification

### GET /api/bot/:botId/instructions

**Request:**

```bash
GET /api/bot/bot_12345/instructions
```

**Response (200):**

```json
{
  "status": "success",
  "systemInstructions": {
    "instructions": "You are a...",
    "bot_name": "name",
    "topic": "topic",
    "grade_level": "level",
    "generated_at": "ISO timestamp",
    "is_natural_bot": true
  },
  "botName": "name",
  "topic": "topic"
}
```

### POST /api/chat-enhanced (with [START_SESSION])

**Request:**

```json
{
  "message": "[START_SESSION]",
  "botId": "bot_12345",
  "userId": "user_123",
  "systemInstructions": {...}
}
```

**Response (200):**

```json
{
  "status": "success",
  "response": "AI-generated greeting here",
  "state": "intro",
  "progress": {
    "percentage": 0,
    "completed_modules": 0
  },
  "timestamp": "ISO timestamp"
}
```

### POST /api/chat-enhanced (regular message)

**Request:**

```json
{
  "message": "user message",
  "botId": "bot_12345",
  "userId": "user_123",
  "systemInstructions": {...}
}
```

**Response (200):**

```json
{
  "status": "success",
  "response": "bot response based on state machine and instructions",
  "state": "intro|learning|...",
  "progress": {
    "percentage": 0,
    "completed_modules": 0
  },
  "timestamp": "ISO timestamp"
}
```

---

## Troubleshooting Flowchart

```
Is backend running?
  NO  → Check Render status, restart service
  YES ↓

Do logs show "POST /api/chat-enhanced"?
  NO  → Frontend not calling endpoint
       Check _fetchInitialGreeting() is being called
       Check endpoint URL is correct
  YES ↓

Do logs show "[START_SESSION]" detected?
  NO  → Message not reaching backend properly
       Check payload in frontend logs
       Check network tab in browser
  YES ↓

Do logs show "AI GREETING GENERATED"?
  NO  → Groq API call failed
       Check GROQ_API_KEY is set
       Check Groq API status
  YES ↓

Does greeting appear in app?
  NO  → Frontend not displaying response
       Check _addBotMessage() is called
       Check JSON parsing
  YES ↓

✅ SUCCESS! System working correctly
```

---

## Performance Checks

### Frontend Response Time

```
Should be <200ms from sending [START_SESSION] to receiving response
Look in frontend logs for timestamps
```

### Backend Processing Time

```
Should be <3s total including Groq API call
Look in backend logs for timing
```

### Overall User Experience

```
Greeting appears within 2-3 seconds of opening chat
No loading spinner blocking UI for >5 seconds
```

---

## Database Verification

### Check if instructions are stored:

```sql
SELECT bot_id, name, system_instructions
FROM study_bots
WHERE bot_id = 'bot_YOUR_ID';
```

### Check if chat history is saved:

```sql
SELECT *
FROM chat_messages
WHERE bot_id = 'bot_YOUR_ID'
  AND message_type = 'user'
ORDER BY created_at DESC;
```

### Check if [START_SESSION] is in database:

```sql
SELECT *
FROM chat_messages
WHERE content = '[START_SESSION]';
# Should return EMPTY (0 rows)
```

---

## Cleanup/Reset (if needed)

### Clear app cache:

```bash
flutter clean
flutter run
```

### Reset backend logs:

```
Go to Render logs and refresh
(Logs are temporary, clear on service restart)
```

### Reset database (⚠️ PRODUCTION CAUTION):

```bash
# WARNING: Only do this in development!
# Contact admin before doing on production
```

---

**Quick Links:**

- 📊 Render Dashboard: https://dashboard.render.com
- 🔍 Logs: https://dashboard.render.com → ai-backend → Logs
- 📚 Documentation: FRONTEND_BACKEND_API_VALIDATION.md
- 📝 Status: AI_GREETING_IMPLEMENTATION_STATUS.md

**Last Updated:** January 11, 2026
