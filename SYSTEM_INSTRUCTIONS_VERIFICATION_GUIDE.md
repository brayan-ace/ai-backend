# System Instructions Verification & Update Guide

## What Changed

The system has been updated to **automatically fetch fresh system instructions from the database** when you start a chat session. This means any changes you make to system instructions will immediately appear in the app.

---

## How to Verify Instructions Are Being Fetched

### 1. **Check Backend Logs (Look for Fresh Instructions)**

When you open a chat with a bot, you should see this in the backend logs:

```
[ChatScreen] ✅ Fresh system instructions fetched and updated
[ChatScreen] Bot: [BotName], Topic: [TopicName]
```

This confirms the frontend is fetching fresh instructions on startup.

---

### 2. **View the Actual Stored Instructions in Database**

Use this diagnostic endpoint to see exactly what's stored:

```bash
curl "https://ai-backend-vf75.onrender.com/api/debug/bot/BOT_ID_HERE"
```

**Example Response:**

```json
{
  "status": "success",
  "debug_info": {
    "botId": "bot_1768095418663_9978",
    "botName": "nutri",
    "topic": "Autotrophs",
    "gradeLevel": "Senior Secondary",
    "createdAt": "2026-01-11T...",
    "currentState": {...}
  },
  "systemInstructions": {
    "bot_name": "nutri",
    "topic": "Autotrophs",
    "grade_level": "Senior Secondary",
    "generated_at": "2026-01-11T...",
    "instructions_preview": "You are a warm, human study companion...",
    "full_instructions": "## YOU ARE A WARM, HUMAN STUDY COMPANION..."
  }
}
```

**To get your Bot ID:**

1. Create a bot in the app
2. Look at the app logs for: `[BotProcessingScreen] Bot created successfully: bot_XXXXX`
3. Use that ID in the curl command above

---

## How to Update System Instructions

### Option 1: Update via API (Programmatic)

```bash
curl -X PUT "https://ai-backend-vf75.onrender.com/api/bot/BOT_ID_HERE/instructions" \
  -H "Content-Type: application/json" \
  -d '{
    "systemInstructions": {
      "instructions": "Your new instructions here...",
      "bot_name": "botName",
      "topic": "topic",
      "grade_level": "grade",
      "generated_at": "2026-01-11T...",
      "is_natural_bot": true
    }
  }'
```

### Option 2: Update Directly in Database (Advanced)

Connect to your PostgreSQL database and run:

```sql
UPDATE study_bots
SET system_instructions = '{"instructions": "NEW INSTRUCTIONS...", "bot_name": "...", ...}'::jsonb
WHERE bot_id = 'bot_YOUR_BOT_ID';
```

---

## How the Frontend Uses Fresh Instructions

1. **When Bot Screen Loads** → Automatically fetches fresh instructions via `GET /api/bot/:botId/instructions`
2. **During Chat** → Uses the fetched instructions to guide bot behavior
3. **Instructions Override** → Database instructions override any stale instructions passed from frontend

---

## API Endpoints Reference

### **GET /api/bot/:botId/instructions**

Fetch fresh system instructions from database.

**Response:**

```json
{
  "status": "success",
  "systemInstructions": {...},
  "botName": "string",
  "topic": "string",
  "gradeLevel": "string"
}
```

### **PUT /api/bot/:botId/instructions**

Update system instructions in database.

**Request Body:**

```json
{
  "systemInstructions": {
    "instructions": "...",
    "bot_name": "...",
    "topic": "...",
    "grade_level": "...",
    "generated_at": "ISO timestamp",
    "is_natural_bot": true
  }
}
```

### **GET /api/debug/bot/:botId**

View complete bot data including full system instructions.

---

## Troubleshooting

### ✅ Instructions Not Updating?

1. **Check Bot ID**: Confirm you're using the correct bot ID

   ```
   curl https://ai-backend-vf75.onrender.com/api/debug/bot/bot_YOUR_ID
   ```

2. **Clear App Cache** (on device):

   - Stop the Flutter app
   - Run `flutter clean` on your machine
   - Rebuild with `flutter run`

3. **Hot Restart** (faster):

   - Press `R` in the Flutter terminal while app is running
   - This reloads the app code AND fetches fresh instructions

4. **Check Network Logs**:

   - In Chrome DevTools or Dart DevTools
   - Look for GET request to `/api/bot/YOUR_BOT_ID/instructions`
   - Should return status 200 with fresh instructions

5. **Verify Backend is Updated**:
   - Check that your changes were pushed to GitHub
   - Render auto-deploys from GitHub (takes ~30 seconds)
   - Test API endpoint directly with curl command above

---

## Key Changes Made

### Backend (server.js)

- ✅ Added `GET /api/bot/:botId/instructions` - Fetch fresh instructions
- ✅ Added `PUT /api/bot/:botId/instructions` - Update instructions
- ✅ Added `GET /api/debug/bot/:botId` - Debug/view bot data
- ✅ `POST /api/chat-enhanced` already uses database instructions (not changed)

### Frontend (study_plan_chat_screen.dart)

- ✅ Added `_fetchFreshSystemInstructions()` method
- ✅ Called in `_initPhase2()` after loading chat history
- ✅ Updates `_botInstructions` state variable with fresh data
- ✅ Logs success/failure for debugging

---

## Example Workflow

1. **Create a bot** in the app
2. **Copy the bot ID** from logs
3. **Check current instructions**:
   ```bash
   curl "https://ai-backend-vf75.onrender.com/api/debug/bot/bot_YOUR_ID"
   ```
4. **Update instructions** (via API or database):
   ```bash
   curl -X PUT "https://ai-backend-vf75.onrender.com/api/bot/bot_YOUR_ID/instructions" \
     -H "Content-Type: application/json" \
     -d '{"systemInstructions": {...}}'
   ```
5. **Hot restart app**: Press `R` in Flutter terminal
6. **Verify**: Check logs for `✅ Fresh system instructions fetched`
7. **Test bot behavior**: It should use the new instructions immediately

---

## Frontend Code Flow

```
StudyPlanChatScreen.initState()
  ↓
_initPhase2()
  ↓
Load chat history from backend
Load bot progress
  ↓
_fetchFreshSystemInstructions(botId) ← NEW!
  ↓
GET /api/bot/:botId/instructions
  ↓
Update _botInstructions state variable
  ↓
When user sends message: Use _botInstructions in API call
```

---

## Backend Code Flow

```
POST /api/chat-enhanced (user sends message)
  ↓
SELECT system_instructions FROM study_bots WHERE bot_id = ? ← Gets LATEST from DB
  ↓
Use database system_instructions (ignores stale frontend version)
  ↓
Generate bot response
```

The key is: **Backend always uses database version, frontend fetches fresh version on load.**
