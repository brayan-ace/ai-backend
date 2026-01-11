# Render Log Monitoring Guide - AI Greeting Implementation

## Overview

This guide helps you verify that the AI greeting implementation is working correctly by reading the Render logs.

## What to Look For

### 1. **Frontend Logs** (from Flutter app)

When a user opens a bot chat screen for the first time, look for these logs:

```
[ChatScreen] 🎯 _fetchInitialGreeting() CALLED - Getting fresh AI greeting
[ChatScreen] 👤 User ID: [user_id]
[ChatScreen] 🔗 Calling endpoint: https://ai-backend-vf75.onrender.com/api/chat-enhanced
[ChatScreen] 📨 Payload: message=[START_SESSION], botId=[bot_id]
[ChatScreen] 📬 Response status: 200
[ChatScreen] ✅ AI GREETING RECEIVED from backend
[ChatScreen] 💬 Greeting text: "[actual greeting from AI]"
[ChatScreen] ✅ Initial greeting fetched from backend and displayed
```

### 2. **Backend Logs** (from Node.js/Render)

When the [START_SESSION] message arrives at the backend, look for:

```
🔵 ===== [POST /api/chat-enhanced] NEW REQUEST =====
⏰ Timestamp: [ISO timestamp]
📨 Message: "[START_SESSION]"
🤖 Bot ID: [bot_id]
👤 User ID: [user_id]
⭐ SPECIAL MESSAGE DETECTED: [START_SESSION]
🎯 ACTION: Generate personalized greeting from AI using system instructions
📋 System Prompt loaded (length: [number] chars)
🔗 Calling Groq API for greeting generation...
✅ AI GREETING GENERATED
📝 Response: "[first 100 chars of greeting]..."
⏭️  Skipping database save for [START_SESSION] special message
✅ RESPONSE READY
📤 Sending response with greeting: "[first 80 chars]..."
🔵 ===== END CHAT-ENHANCED REQUEST =====
```

## How to Check Render Logs

### Via Render Dashboard:

1. Go to https://dashboard.render.com
2. Select your "ai-backend" service
3. Click **Logs** tab
4. Watch for real-time logs as user interacts with app

### Via Terminal:

```bash
# Stream logs from Render (if you have Render CLI installed)
render logs ai-backend-vf75 --tail
```

## Expected Behavior Flow

1. **User opens bot chat screen**

   - ✅ `_fetchInitialGreeting()` is called automatically
   - ✅ Frontend sends `[START_SESSION]` message

2. **Backend receives [START_SESSION]**

   - ✅ Recognizes special message
   - ✅ Loads bot's system instructions from database
   - ✅ Calls Groq API with system instructions

3. **Groq generates personalized greeting**

   - ✅ Uses bot's personality (from system instructions)
   - ✅ Generates warm, conversational greeting
   - ✅ Returns greeting text

4. **Backend sends greeting to frontend**

   - ✅ Response status 200
   - ✅ Includes AI-generated greeting

5. **Frontend displays greeting**
   - ✅ Shows greeting in chat
   - ✅ User can start conversing

## Troubleshooting

### Issue: `_fetchInitialGreeting()` not called

**Look for:** No logs starting with `[ChatScreen] 🎯 _fetchInitialGreeting()`
**Cause:** State caching prevented fresh greeting fetch
**Solution:** Check `_initPhase2()` in `study_plan_chat_screen.dart` - should always call `_fetchInitialGreeting()`

### Issue: [START_SESSION] not reaching backend

**Look for:** Backend logs don't show `⭐ SPECIAL MESSAGE DETECTED`
**Cause:** Network issue or wrong endpoint
**Solution:** Check payload in frontend logs - verify correct botId and userId

### Issue: Groq API error

**Look for:** Backend log `📋 System Prompt loaded` followed by error
**Cause:** GROQ_API_KEY not set or Groq API unreachable
**Solution:** Check backend env vars, verify Groq API key is valid

### Issue: Hardcoded greeting still showing

**Look for:** Backend returns hardcoded greeting instead of AI generated
**Cause:** [START_SESSION] handler not executing
**Solution:** Verify recent git push deployed correctly (check last commit date in logs)

## Key Log Markers for Quick Search

| What you're looking for   | Search for                          |
| ------------------------- | ----------------------------------- |
| Greeting fetch started    | `🎯 _fetchInitialGreeting()`        |
| Special message detected  | `⭐ SPECIAL MESSAGE DETECTED`       |
| Groq API called           | `🔗 Calling Groq API`               |
| Greeting generated        | `✅ AI GREETING GENERATED`          |
| Response sent to frontend | `📤 Sending response with greeting` |
| Error occurred            | `❌` or `ERROR`                     |

## Database-Free Design

✅ **[START_SESSION] is NOT saved to database**

- Message is ephemeral (only for triggering greeting)
- No chat message record created
- Greeting is generated fresh every session
- Clean separation: special messages vs regular messages

**Regular user messages ARE saved:**

- When user types "am good and you" - SAVED to database
- Backend processes with state machine
- Response is SAVED to database
- Chat history remains intact

## Verification Checklist

- [ ] Frontend logs show `_fetchInitialGreeting()` called
- [ ] `[START_SESSION]` message appears in backend logs
- [ ] Groq API call succeeds (look for `✅ AI GREETING GENERATED`)
- [ ] Response includes personalized greeting (not hardcoded)
- [ ] No errors in logs
- [ ] [START_SESSION] is NOT in chat_messages table (check DB)
- [ ] Regular messages ARE in chat_messages table

---

**Last Updated:** January 11, 2026
**Implementation:** AI-driven greeting with system instructions
**Status:** Ready for testing
