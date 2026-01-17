# Backend Testing & Debugging Guide

## 🧪 Quick Test Commands

### **Test 1: Check if Bot Exists in Database**

```bash
# Connect to PostgreSQL
psql -U postgres -d myai_db

# Query bots
SELECT bot_id, name, topic FROM study_bots LIMIT 5;

# Check specific bot
SELECT bot_id, name, topic, system_instructions FROM study_bots
WHERE bot_id = 'your_bot_id';
```

### **Test 2: Test Backend Endpoint - Get Bot Instructions**

```bash
# Using curl
curl -X GET "http://localhost:3000/api/bot/bot_12345/instructions" \
  -H "Content-Type: application/json"

# Expected response (success):
{
  "status": "success",
  "botId": "bot_12345",
  "botName": "Biology Tutor",
  "topic": "Photosynthesis",
  "gradeLevel": "10th Grade",
  "systemInstructions": {
    "instructions": "You are an expert biology tutor..."
  },
  "timestamp": "2026-01-17T..."
}

# Expected response (bot not found):
{
  "error": "Bot not found",
  "message": "Bot with ID bot_12345 not found in database",
  "timestamp": "2026-01-17T..."
}
```

### **Test 3: Test Chat Endpoint with Instructions**

```bash
curl -X POST "http://localhost:3000/api/chat-enhanced" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What is photosynthesis?",
    "botId": "bot_12345",
    "userId": "user_123",
    "systemInstructions": {
      "instructions": "You are a biology tutor. Explain concepts clearly."
    }
  }'

# Expected response:
{
  "status": "success",
  "response": "Photosynthesis is the process...",
  "instructionSource": "database",
  "learnerProfileApplied": false,
  "moodApplied": false,
  "timestamp": "2026-01-17T..."
}
```

### **Test 4: Test with Learner Profile**

```bash
curl -X POST "http://localhost:3000/api/chat-enhanced" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "I don'\''t understand photosynthesis",
    "botId": "bot_12345",
    "userId": "user_123",
    "systemInstructions": {
      "instructions": "You are a biology tutor..."
    },
    "learnerProfile": {
      "sessionId": "session_123",
      "learningStyle": "visual",
      "pacePreference": "slow",
      "communicationTone": "encouraging",
      "motivationLevel": "medium",
      "confidenceLevel": 0.6,
      "createdAt": "2026-01-17T...",
      "conversationContext": {}
    },
    "currentMood": {
      "sentiment": "confused",
      "confidence": 0.85,
      "indicators": ["don'\''t understand", "confused"],
      "detectedAt": "2026-01-17T...",
      "suggestedAction": "provide_example_or_different_explanation"
    }
  }'

# Expected response shows:
# "instructionSource": "database"
# "learnerProfileApplied": true
# "moodApplied": true
```

---

## 🔍 Backend Logs to Check

### **When Bot Instructions Are Being Loaded:**

```
[GET /api/bot/:botId/instructions] Fetching for botId: bot_12345
[Bot Instructions] Found bot: Biology Tutor
[Bot Instructions] status: success (check response above)
```

### **When Message Is Sent to Backend:**

```
[POST /api/chat-enhanced] Request received
[POST /api/chat-enhanced] Received payload: {message: ..., botId: ..., userId: ...}
```

### **When Instructions Are Fetched from Database:**

```
[Chat-Enhanced] ✅ Instructions fetched from database
[Chat-Extended] Using instructions from DATABASE
[Chat-Enhanced] Instructions ready: "You are an expert..." (source: database)
```

### **When Profile/Mood Are Applied:**

```
[Chat-Enhanced] Instructions enhanced with learner profile
[Chat-Enhanced] Instructions enhanced with mood context
```

### **When AI Response Is Generated:**

```
[Chat-Enhanced] ✅ AI response received, length: 450
[Chat-Enhanced] Backend processing info:
[Chat-Enhanced]    - Instructions from: database
[Chat-Enhanced]    - Learner profile applied: true
[Chat-Enhanced]    - Mood applied: true
```

### **Error Scenarios:**

```
# Bot not found
[Bot Instructions] Bot not found: bot_12345
[GET /api/bot/:botId/instructions] Error: Bot not found

# Missing API key
[POST /api/chat-enhanced] GROQ_API_KEY not configured

# Database error
[Chat-Enhanced] Could not fetch from DB: connection error
[Chat-Enhanced] Using instructions from FRONTEND (fallback)
```

---

## 📊 Frontend Logs to Monitor

### **When Bot Screen Loads:**

```
[ChatScreen] 🎯 _fetchInitialGreeting() CALLED
[ChatScreen] 📋 System Instructions available: true
[ChatScreen] 👤 User ID: user_123
[ChatScreen] 🔗 Calling endpoint: https://backend.com/api/chat-enhanced
[ChatScreen] ✅ Initial greeting fetched from backend and displayed
```

### **When User Sends Message:**

```
[ChatScreen] Sending message to backend: What is photosynthesis?
[ChatScreen] Bot ID: bot_12345
[ChatScreen] User ID: user_123
[ChatScreen] 📋 Instructions present: true
[ChatScreen] 🧠 Learner profile: true
[ChatScreen] 🎯 Current mood: positive
[ChatScreen] 📬 Response status: 200
[ChatScreen] ✅ Backend processing info:
[ChatScreen]    - Instructions from: database
[ChatScreen]    - Learner profile applied: true
[ChatScreen]    - Mood applied: true
```

### **Error Cases in Frontend:**

```
# 500 Error
[ChatScreen] ⚠️ ERROR 500 - Server error from backend
[ChatScreen] ⚠️ Response body: {error: "Failed to process chat message"}

# 404 Error
[ChatScreen] ⚠️ ERROR 404 - Bot or endpoint not found

# 400 Error
[ChatScreen] ⚠️ ERROR 400 - Bad request

# Network error
[ChatScreen] ⚠️ Network/Connection Error: Connection refused
```

---

## 🛠️ Step-by-Step Debugging for Error 500

### **Step 1: Verify Backend is Running**

```bash
# Check if server is listening
netstat -an | grep 3000
# or
lsof -i :3000

# If not running:
cd backend
npm start
```

### **Step 2: Check if Endpoint Exists**

```bash
curl -X GET "http://localhost:3000/api/bot/bot_test/instructions"

# Should NOT return 404
# Should return either: 200 (success) or your error message
```

### **Step 3: Check Database Connection**

```bash
# In backend logs, look for:
[DB] user_study_state table ensured
[DB] conversation_memory table ensured

# If you see connection errors:
psql -U postgres -d myai_db -c "SELECT 1"
# Should return: 1 (success)
```

### **Step 4: Check Database Contains Bots**

```bash
psql -U postgres -d myai_db -c "SELECT COUNT(*) FROM study_bots;"

# Should return: {count: > 0}
# If 0, no bots created yet
```

### **Step 5: Check API Key**

```bash
# In backend .env file:
GROQ_API_KEY=gsk_xxxxx...

# In Node.js:
const key = process.env.GROQ_API_KEY;
console.log('API Key set:', !!key);

# Key must be non-empty
```

### **Step 6: Monitor Live Logs**

```bash
# Start backend with verbose logging:
cd backend
NODE_DEBUG=http npm start

# Watch for:
# - Incoming requests
# - Database queries
# - API calls
# - Error messages
```

---

## 🚨 Common Error Codes & Fixes

### **Error 500 (Internal Server Error)**

**Cause 1: API Key Missing**

```
[POST /api/chat-enhanced] GROQ_API_KEY not configured

Fix:
1. Open backend/.env
2. Add: GROQ_API_KEY=your_actual_key
3. Restart backend
```

**Cause 2: Database Connection Failed**

```
[Chat-Enhanced] Could not fetch from DB: ECONNREFUSED

Fix:
1. Check PostgreSQL is running: systemctl status postgresql
2. Verify connection string in db.js
3. Test: psql -U postgres -d myai_db -c "SELECT 1"
```

**Cause 3: Unexpected Error in Code**

```
[POST /api/chat-enhanced] Error: Cannot read property 'instructions' of null

Fix:
1. Check backend logs for full error
2. Check if systemInstructions is being passed from frontend
3. Verify database schema has system_instructions column
```

---

### **Error 404 (Not Found)**

**If it's `/api/bot/:botId/instructions`:**

```
Check:
1. Is the bot actually in database?
   SELECT * FROM study_bots WHERE bot_id = 'bot_12345';

2. Is the route defined in server.js?
   grep -n "api/bot.*instructions" server.js

3. Is server restarted after adding route?
   Kill process and restart: npm start
```

---

### **Error 400 (Bad Request)**

**Frontend is missing required field:**

```
Missing: message, botId, or userId

Check frontend _sendMessageToBackend() is sending:
- message ✓
- botId ✓
- userId ✓
- systemInstructions (optional but recommended)
- learnerProfile (optional)
- currentMood (optional)
```

---

## 📋 Deployment Checklist

- [ ] Backend code updated with new endpoints
- [ ] Frontend code recompiled (0 errors)
- [ ] Restart backend server
- [ ] Test `/api/bot/:botId/instructions` endpoint
- [ ] Verify database has `study_bots` table
- [ ] Verify GROQ_API_KEY is set in .env
- [ ] Create test bot via UI
- [ ] Verify bot appears in database
- [ ] Send message and check logs for "Instructions fetched from database"
- [ ] Verify no Error 500 messages
- [ ] Check "instructionSource" in response is "database"

---

## 🎯 Success Indicators

✅ **All of these should be true:**

1. Bot creation works

   ```
   Bot created successfully, ID shown
   ```

2. Instructions retrieved

   ```
   GET /api/bot/:botId/instructions returns 200
   systemInstructions field contains the instructions
   ```

3. Chat responds without 500

   ```
   POST /api/chat-enhanced returns 200
   Response includes: status, response, instructionSource
   ```

4. Backend logs show proper flow

   ```
   [Chat-Enhanced] ✅ Instructions fetched from database
   [Chat-Enhanced] ✅ AI response received
   ```

5. Frontend shows no errors
   ```
   Response status: 200
   Backend processing: Instructions from database
   ```

---

## 🔄 Full Test Workflow

1. **Create Bot:**

   ```bash
   curl -X POST http://localhost:3000/api/create-study-bot \
     -H "Content-Type: application/json" \
     -d '{\n      "user_id": "test_user",\n      "name": "Test Bot",\n      "topic": "Math",\n      "grade_level": "9th Grade"\n    }'\n   # Note: bot_id from response
   ```

2. **Fetch Instructions:**

   ```bash
   curl -X GET "http://localhost:3000/api/bot/bot_xxxxx/instructions"
   # Should return instructions
   ```

3. **Send Message:**

   ```bash
   curl -X POST http://localhost:3000/api/chat-enhanced \
     -H "Content-Type: application/json" \
     -d '{\n      "message": "What is 2+2?",\n      "botId": "bot_xxxxx",\n      "userId": "test_user",\n      "systemInstructions": {...instructions from step 2...}\n    }'\n   # Should return AI response with instructionSource: "database"
   ```

4. **Check Logs:**
   ```bash
   # Backend should show:
   # ✅ Instructions fetched from database
   # ✅ AI response received
   ```

---

**Ready to debug? Start with Step 1 above! 🚀**
