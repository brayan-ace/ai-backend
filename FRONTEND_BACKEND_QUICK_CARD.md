# Frontend-Backend Integration - Quick Reference Card

## The 3 Core API Calls

### 1️⃣ GET Instructions

```
Frontend: _fetchFreshSystemInstructions()
Endpoint: GET /api/bot/:botId/instructions
Response: { systemInstructions: {...}, botName, topic }
Storage: Dart var _botInstructions
Used In: Both greeting and messages
```

### 2️⃣ POST Greeting

```
Frontend: _fetchInitialGreeting()
Endpoint: POST /api/chat-enhanced
Payload:  { message: "[START_SESSION]", botId, userId, systemInstructions }
Backend:  Recognizes [START_SESSION], calls Groq with instructions
Response: { response: "AI greeting", state: "intro" }
Display:  Added to chat via _addBotMessage()
```

### 3️⃣ POST Message

```
Frontend: _sendMessageToBackend(userMessage)
Endpoint: POST /api/chat-enhanced
Payload:  { message: userMessage, botId, userId, systemInstructions }
Backend:  Uses state machine + instructions to respond
Response: { response: "bot reply", state: "...", progress: {...} }
Display:  Added to chat via _addBotMessage()
```

---

## What Gets Passed Where

```
Frontend Variables     Backend Processing         Database
─────────────────────  ──────────────────────────  ────────────────
_botInstructions   ──→ system prompt for Groq  ──→ system_instructions
widget.botId       ──→ identify bot            ──→ study_bots.bot_id
userId             ──→ identify user           ──→ bot_progress.user_id
_botCurrentState   ──→ determine flow path     ──→ bot_progress.bot_state
_messages          ──→ saved to db             ──→ chat_messages table
```

---

## Log Verification

### Frontend Ready ✅

```
[ChatScreen] 🎯 _fetchInitialGreeting() CALLED
[ChatScreen] 📨 Payload: message=[START_SESSION]
[ChatScreen] ✅ Fresh system instructions fetched and updated
[ChatScreen] ✅ AI GREETING RECEIVED from backend
```

### Backend Ready ✅

```
🔵 [POST /api/chat-enhanced] NEW REQUEST
📨 Message: "[START_SESSION]"
⭐ SPECIAL MESSAGE DETECTED: [START_SESSION]
✅ AI GREETING GENERATED
📤 Sending response with greeting
```

---

## Troubleshooting

| Problem               | Check                                         |
| --------------------- | --------------------------------------------- |
| Hardcoded greeting    | Backend logs for `✅ AI GREETING GENERATED`   |
| Instructions not used | Verify `_botInstructions` in frontend payload |
| Wrong personality     | Confirm bot's system_instructions in database |
| Network error         | Check endpoint URL and network connectivity   |
| State not updating    | Look for `bot_state` in backend response      |

---

## File Locations

**Frontend:** `lib/screens/study_plan_chat_screen.dart`

- Line 328: `_fetchFreshSystemInstructions()`
- Line 375: `_fetchInitialGreeting()`
- Line 480: `_sendMessageToBackend()`

**Backend:** `backend/server.js`

- Line 1089: GET `/api/bot/:botId/instructions`
- Line 1442: POST `/api/chat-enhanced` (start point)
- Line 1520: [START_SESSION] handler
- Line 1578: Regular message handler

---

## Key Code Snippets

### Frontend - Send Message with Instructions

```dart
final payload = {
  'message': userMessage,
  'botId': widget.botId,
  'userId': userId,
  'systemInstructions': _botInstructions,  // ✅ Always included
};
```

### Backend - Use Instructions in Groq

```javascript
const systemPrompt = finalSystemInstructions?.instructions;
const chatCompletion = await axios.post("groq-api", {
  messages: [{
    role: "system",
    content: systemPrompt,  // ✅ Instructions here
  }, ...],
});
```

---

## Testing in 30 Seconds

1. Open app → Create bot
2. Open bot chat
3. Check app logs for: `✅ AI GREETING RECEIVED from backend`
4. Check Render logs for: `✅ AI GREETING GENERATED`
5. Greeting should be unique (from Groq, not hardcoded)
6. ✅ Done!

---

## Database Queries

### Check instructions are stored:

```sql
SELECT bot_id, system_instructions
FROM study_bots
LIMIT 1;
```

### Check instructions NOT in chat:

```sql
SELECT * FROM chat_messages
WHERE content LIKE '%START_SESSION%';
-- Should return 0 rows
```

### Check state is tracked:

```sql
SELECT bot_id, bot_state, progress_percentage
FROM bot_progress
LIMIT 1;
```

---

## Render Dashboard Shortcuts

**Logs:** https://dashboard.render.com → ai-backend → Logs (CTRL+L)
**Metrics:** https://dashboard.render.com → ai-backend → Metrics
**Settings:** https://dashboard.render.com → ai-backend → Settings

---

## Documentation Index

1. **This file** - Quick reference
2. `FRONTEND_BACKEND_INTEGRATION_COMPLETE.md` - Full overview
3. `FRONTEND_BACKEND_API_VALIDATION.md` - Detailed API mapping
4. `QUICK_VERIFY_FRONTEND_BACKEND.md` - Testing procedures
5. `RENDER_LOG_MONITORING_GUIDE.md` - Log reading guide
6. `AI_GREETING_IMPLEMENTATION_STATUS.md` - Implementation details

---

## Status Summary

✅ Frontend calls backend properly
✅ System instructions are fetched
✅ Instructions passed in every request
✅ Backend uses instructions for all responses
✅ Comprehensive logging enabled
✅ All endpoints tested
✅ Production ready

---

**Print this and keep it handy!**
Last Updated: January 11, 2026
