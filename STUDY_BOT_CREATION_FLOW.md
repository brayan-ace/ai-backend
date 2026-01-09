# Study Bot Creation Flow - Complete Walkthrough

This document explains the entire journey from when a user creates a Study Bot plan through to the chat screen where the bot responds with AI-aware instructions.

---

## Overview: The Complete Journey

```
Phase 1 Screen (user enters plan details)
    ↓
Identity Modal (user names bot + picks grade level)
    ↓
Processing Screen (10-second loader + API call)
    ↓
Backend: Groq AI generates custom instructions
    ↓
Backend: Bot saved to PostgreSQL database
    ↓
Chat Screen (bot ready with state awareness)
    ↓
Bot responds using its system instructions + state tracking
```

---

## Step-by-Step Breakdown

### **STEP 1: Phase 1 Screen (StudyPlanScreen)**

**File:** `lib/screens/study_plan_screen_phase1.dart`

**What Happens:**

- User sees form with two fields:
  - **Study Plan Name** (e.g., "Nutrition Basics")
  - **Study Plan Description** (e.g., "Learn fundamentals of nutrition science", max 100 words)
- User taps "Generate/Continue" button
- App validates inputs:
  - Name cannot be empty
  - Description cannot be empty
  - Description max 100 words

**Example Inputs:**

```
Plan Name: "Nutrition Fundamentals"
Description: "Learn about macronutrients, vitamins, minerals, and healthy eating habits"
```

**Error Handling at This Stage:**

```javascript
✓ Empty name → Show SnackBar: "Please enter a Study Plan name"
✓ Empty description → Show SnackBar: "Please enter a Study Plan description"
✓ Too many words → Show SnackBar: "Description must be 100 words or less. Currently: XX words"
```

**On Success:**

- App shows a loading dialog briefly
- Bottom modal slides up (the Identity Modal)

---

### **STEP 2: Identity Modal (StudyBotIdentityModal)**

**File:** `lib/widgets/study_bot_identity_modal.dart`

**What Happens:**

- Modal displays the study plan summary (what user entered)
- User enters two new pieces of information:
  1. **Study Bot Name** (e.g., "Dr. Nutrition" or "Coach Ali")
  2. **Education Level** (dropdown: Primary, Junior Secondary, Senior Secondary, University, Self-Learner/Other)
- User taps "Create Study Bot" button

**Example Inputs:**

```
Bot Name: "Dr. Nutrition"
Education Level: "Senior Secondary"
```

**Error Handling at This Stage:**

```javascript
✓ Empty bot name → Show SnackBar: "Please enter a name for your Study Bot"
✓ Valid inputs → Proceed to next step
```

**On Success:**

- Modal closes
- App navigates to `BotProcessingScreen`

---

### **STEP 3: Processing Screen (BotProcessingScreen)**

**File:** `lib/screens/bot_processing_screen.dart`

**What Happens:**

- User sees a centered loading spinner
- Screen displays dynamic status messages (changes every 2.5 seconds):
  ```
  "Analyzing your study plan..."        (0-2.5 sec)
  "Searching for resources..."          (2.5-5 sec)
  "Preparing your Study Bot..."         (5-7.5 sec)
  "Finalizing your custom instructions..."  (7.5-10 sec)
  ```
- **Meanwhile, in the background:**
  - App makes HTTP POST request to backend `/api/create-study-bot`
  - Backend calls Groq AI to generate custom tutor instructions
  - Backend saves bot to database
  - Frontend waits at least 10 seconds (to show full progress animation)

**Collected Data at This Point:**

```javascript
{
  user_id: "firebase_uid_or_local_user",
  name: "Dr. Nutrition",
  description: "Learn about macronutrients, vitamins, minerals, and healthy eating habits",
  topic: "Nutrition Fundamentals",  // (fallback: same as planName)
  grade_level: "Senior Secondary"
}
```

**Error Handling at This Stage:**

```javascript
✓ Network error → Show error icon + "Network error. Please check your connection and try again."
✓ Server error (4xx/5xx) → Show error icon + "Server error (XXX). Please try again."
✓ User can tap "Retry" button to restart the entire process
```

---

### **STEP 4: Backend API Call (`/api/create-study-bot`)**

**File:** `backend/server.js`

**What Happens:**

#### 4.1: **Input Validation**

```javascript
✓ Check user_id is not empty → Reject if missing
✓ Check name is not empty → Reject if missing
✓ Sanitize inputs (trim whitespace)
✓ Log all inputs for debugging
```

**Error Response Example:**

```json
{
  "error": "Invalid request",
  "message": "user_id is required and must not be empty",
  "timestamp": "2026-01-09T14:32:10.000Z"
}
```

#### 4.2: **Groq AI API Call**

The backend constructs a prompt for Groq AI:

```javascript
System Prompt:
"You are an educational AI system. Generate detailed, personalized tutor system instructions as JSON."

User Prompt:
"Generate a detailed system_instructions JSON object for a Study Bot with these parameters:
Topic: Nutrition Fundamentals
Description: Learn about macronutrients, vitamins, minerals, and healthy eating habits
Grade Level: Senior Secondary

Return ONLY valid JSON with key 'instructions' containing a string of detailed tutor directives."
```

**Groq API Configuration:**

```javascript
- Model: mixtral-8x7b-32768  (or llama2-70b-4096)
- API Key: process.env.GROQ_API_KEY (from Render environment)
- Endpoint: https://api.groq.com/openai/v1/chat/completions
- Timeout: 30 seconds
- Temperature: 0.7 (balanced creativity)
- Max tokens: 1000
```

**Error Handling for Groq Call:**

```javascript
✗ GROQ_API_KEY not found → Use fallback instructions (log warning)
✗ API timeout (>30s) → Use fallback instructions (log error)
✗ API returns 401 (auth failed) → Use fallback instructions (log error)
✗ API returns 429 (rate limit) → Use fallback instructions (log error)
✗ Empty response → Use fallback instructions (log error)
✗ Malformed JSON → Store response as raw text (log warning)
✓ Success → Parse JSON and store custom instructions
```

**Groq Response Example:**

```json
{
  "choices": [
    {
      "message": {
        "content": "{\"instructions\": \"You are a Study Bot tutor specializing in nutrition education...\"}"
      }
    }
  ]
}
```

#### 4.3: **Prepare System Instructions**

Backend stores instructions in this format:

```javascript
{
  "instructions": "You are a Study Bot tutor specializing in nutrition education...",
  "gradeLevel": "Senior Secondary",
  "topic": "Nutrition Fundamentals",
  "generated_at": "2026-01-09T14:32:15.000Z",
  "is_fallback": false  // (true if Groq call failed)
}
```

**Error Handling:**

```javascript
✓ Successfully parsed from Groq
✓ Failed to parse JSON, but stored raw text
✓ Groq failed, but using fallback instructions (marked is_fallback: true)
```

#### 4.4: **Database Insert**

Backend attempts to insert into PostgreSQL:

**Table:** `study_bots`

**Columns:**

```sql
bot_id              TEXT PRIMARY KEY         -- e.g., "bot_1673347935000_8432"
user_id             TEXT NOT NULL            -- Firebase UID or local_user
name                TEXT NOT NULL            -- "Dr. Nutrition"
description         TEXT                     -- Study plan description
topic               TEXT                     -- "Nutrition Fundamentals"
grade_level         TEXT                     -- "Senior Secondary"
system_instructions JSONB                    -- AI-generated instructions
state               JSONB                    -- Initial state object
```

**Initial State Object:**

```javascript
{
  "current_module": 0,
  "current_subtopic": 0,
  "mastery": {},              // Tracks mastery by concept
  "weak_areas": [],           // Tracks struggling topics
  "created_at": "2026-01-09T14:32:15.000Z"
}
```

**Error Handling for DB Insert:**

```javascript
✗ Table doesn't exist → Auto-create it (idempotent CREATE TABLE IF NOT EXISTS)
✗ Duplicate bot_id → Extremely unlikely (uses timestamp + random)
✗ DB connection failed → Log error, return 500 to frontend
✗ Insert failed (permissions, etc.) → Log detailed error, return 500 to frontend
✓ Success → Return bot object to frontend
```

**Error Response Example:**

```json
{
  "error": "Failed to create study bot",
  "message": "Database error: ...",
  "timestamp": "2026-01-09T14:32:16.000Z"
}
```

#### 4.5: **Success Response**

Backend returns complete bot object:

```json
{
  "status": "success",
  "message": "Study Bot created successfully",
  "bot": {
    "bot_id": "bot_1673347935000_8432",
    "user_id": "firebase_user_123",
    "name": "Dr. Nutrition",
    "description": "Learn about macronutrients, vitamins, minerals, and healthy eating habits",
    "topic": "Nutrition Fundamentals",
    "grade_level": "Senior Secondary",
    "system_instructions": {
      "instructions": "You are a Study Bot tutor specializing in nutrition...",
      "gradeLevel": "Senior Secondary",
      "topic": "Nutrition Fundamentals",
      "generated_at": "2026-01-09T14:32:15.000Z",
      "is_fallback": false
    },
    "state": {
      "current_module": 0,
      "current_subtopic": 0,
      "mastery": {},
      "weak_areas": [],
      "created_at": "2026-01-09T14:32:15.000Z"
    },
    "created_at": "2026-01-09T14:32:15.000Z"
  },
  "timestamp": "2026-01-09T14:32:15.000Z"
}
```

---

### **STEP 5: Chat Screen (StudyPlanChatScreen)**

**File:** `lib/screens/study_plan_chat_screen.dart`

**What Happens:**

When the Processing Screen receives the successful bot object, it automatically navigates to the Chat Screen:

```dart
Navigator.of(context).pushReplacement(
  MaterialPageRoute(
    builder: (_) => StudyPlanChatScreen(
      botId: bot['bot_id'],
      planName: bot['name'],
      planDescription: bot['description'],
      botName: bot['name'],
      educationLevel: bot['grade_level'],
    ),
  ),
);
```

#### 5.1: **Chat Screen Initialization**

Chat Screen receives the bot data and is ready for interaction:

```javascript
✓ Bot Name: "Dr. Nutrition" (displayed in AppBar)
✓ Education Level: "Senior Secondary" (displayed in subtitle)
✓ Bot has State: {current_module: 0, ...}
✓ Bot has System Instructions: {"instructions": "..."}
✓ Bot is ready to chat
```

#### 5.2: **User Asks a Question**

User types: "What are macronutrients?"

**Process:**

1. User's message is displayed in chat
2. App shows loading indicator (bot is thinking)
3. App sends message + bot state to backend for response

**Message Sent:**

```javascript
{
  type: "chat",
  data: {
    message: "What are macronutrients?",
    botId: "bot_1673347935000_8432",
    botState: {
      current_module: 0,
      current_subtopic: 0,
      mastery: {},
      weak_areas: []
    },
    systemInstructions: {
      instructions: "You are a Study Bot tutor specializing in nutrition..."
    }
  }
}
```

#### 5.3: **Backend Processing (Chat Response)**

Backend receives the message and:

```javascript
1. Validates bot_id and message
2. Retrieves bot's system_instructions from database
3. Constructs prompt with:
   - System instructions (e.g., "You are a Study Bot tutor specializing in nutrition...")
   - Current state (e.g., "current_module: 0" to track progress)
   - User question (e.g., "What are macronutrients?")
4. Calls Groq AI with context awareness
5. Returns response
```

**Error Handling for Chat:**

```javascript
✓ Bot not found → Return error: "Bot not found"
✓ Message empty → Return error: "Message cannot be empty"
✓ Groq API fails → Return fallback: "I encountered a temporary issue..."
✓ Success → Return AI-generated response
```

#### 5.4: **Bot Response with State Awareness**

Groq AI responds, using the system instructions to guide its behavior:

**Example Response:**

```
"Great question! Macronutrients are the three essential nutrients your body needs in large amounts: proteins, carbohydrates, and fats.

Let me break each down:
- **Proteins**: Build and repair tissues (found in eggs, meat, beans)
- **Carbohydrates**: Provide energy (found in grains, fruits, vegetables)
- **Fats**: Store energy and support cell functions (found in oils, nuts, avocados)

Since you're at the beginning of the module (current_module: 0), I'm starting with fundamentals. As we progress, we'll explore how these interact in your body. Does this make sense so far?"
```

**State Awareness in Action:**

- Bot knows it's in `current_module: 0` → Teaches **fundamentals**
- If user struggles → Bot adds to `weak_areas: ["macronutrients"]`
- If user masters concept → Bot adds to `mastery: {"macronutrients": "advanced"}`
- Bot adjusts pace based on `grade_level: "Senior Secondary"`

---

## Error Handling Summary

| Stage                   | Error                  | Resolution                                |
| ----------------------- | ---------------------- | ----------------------------------------- |
| **Phase 1**             | Empty name/desc        | Show SnackBar warning                     |
| **Phase 1**             | Too many words         | Show SnackBar with word count             |
| **Modal**               | Empty bot name         | Show SnackBar warning                     |
| **Processing**          | Network error          | Show error message + Retry button         |
| **Processing**          | Server error (4xx/5xx) | Show error message + Retry button         |
| **Backend: Validation** | Missing user_id        | Return 400: "user_id is required"         |
| **Backend: Validation** | Missing name           | Return 400: "name is required"            |
| **Backend: Groq API**   | GROQ_API_KEY not set   | Use fallback instructions, log warning    |
| **Backend: Groq API**   | API timeout            | Use fallback instructions, log error      |
| **Backend: Groq API**   | API auth failed        | Use fallback instructions, log error      |
| **Backend: Groq API**   | Malformed JSON         | Store raw text, log warning               |
| **Backend: DB**         | Insert fails           | Return 500: "Database error"              |
| **Chat**                | Bot not found          | Return error message                      |
| **Chat**                | Groq API fails         | Return fallback: "I encountered an issue" |

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      USER ACTIONS                                │
│  (Enter plan → Enter bot name/grade → Wait 10s → Chat)          │
└─────────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────────┐
│               FLUTTER FRONTEND (Client)                          │
│  ✓ Collects inputs                                               │
│  ✓ Validates inputs locally                                      │
│  ✓ Shows 10-second progress animation                            │
│  ✓ Sends POST to /api/create-study-bot                           │
│  ✓ Waits for response (min 10 seconds)                           │
│  ✓ Navigates to Chat Screen                                      │
└─────────────────────────────────────────────────────────────────┘
                           ↓ HTTP POST
┌─────────────────────────────────────────────────────────────────┐
│              NODE.JS/EXPRESS BACKEND (Server)                    │
│  ✓ Validates request (user_id, name)                             │
│  ✓ Calls Groq AI API                                             │
│  ✓ Parses/stores AI instructions                                 │
│  ✓ Creates bot_id                                                │
│  ✓ Generates initial state                                       │
│  ✓ Inserts into PostgreSQL                                       │
│  ✓ Returns bot object (JSON)                                     │
└─────────────────────────────────────────────────────────────────┘
                           ↓ HTTP POST /ai/ask
┌─────────────────────────────────────────────────────────────────┐
│                   GROQ API (External)                            │
│  ✓ Receives prompt + system instructions                         │
│  ✓ Generates personalized tutor response                         │
│  ✓ Returns JSON response                                         │
└─────────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────────┐
│              POSTGRESQL DATABASE (Render)                        │
│  ✓ Stores bot record with all metadata                           │
│  ✓ Stores system_instructions (JSONB)                            │
│  ✓ Stores state (JSONB)                                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Features

### **State Awareness**

- Bot knows what module/subtopic student is on
- Bot tracks mastery levels and weak areas
- Bot adjusts difficulty based on grade level

### **Error Resilience**

- If Groq API fails → Use fallback instructions
- If DB insert fails → Return error to user (can retry)
- If network fails → User sees friendly error + retry button

### **Personalization**

- Groq AI generates custom instructions based on:
  - Topic (e.g., "Nutrition Fundamentals")
  - Description (e.g., "Learn about macronutrients...")
  - Grade Level (e.g., "Senior Secondary")
- Each bot has unique system instructions

### **Timing**

- Processing Screen shows at least 10 seconds
- Gives illusion of "processing"
- Ensures API call has time to complete in background

---

## Environment Variables Required

**On Render (Backend):**

```
GROQ_API_KEY=gsk_xxxxx...  (from Groq Console)
DB_USER=postgres
DB_HOST=your-postgres-host.render.com
DB_NAME=myai_db
DB_PASSWORD=your_db_password
DB_PORT=5432
PORT=3000
```

**In Flutter (Frontend):**

```
BACKEND_URL=http://10.0.2.2:3000  (Android emulator)
         OR https://your-render-url.onrender.com  (Production)
```

---

## Testing the Flow Locally

### **1. Start Backend**

```bash
cd backend
export GROQ_API_KEY=gsk_xxxxx
npm install  # if not done
node server.js
# Should see: "[Server Started] Running on port 3000"
```

### **2. Test API Endpoint**

```bash
curl -X POST http://localhost:3000/api/create-study-bot \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test_user_123",
    "name": "Dr. Nutrition",
    "description": "Learn about nutrition science",
    "topic": "Nutrition",
    "grade_level": "Senior Secondary"
  }'

# Expected response:
# {
#   "status": "success",
#   "message": "Study Bot created successfully",
#   "bot": { ...full bot object... },
#   "timestamp": "2026-01-09T14:32:15.000Z"
# }
```

### **3. Run Flutter App**

```bash
flutter clean
flutter pub get
flutter run --dart-define=BACKEND_URL=http://10.0.2.2:3000

# Or for production Render URL:
# flutter run --dart-define=BACKEND_URL=https://your-app.onrender.com
```

### **4. Test End-to-End**

1. Enter study plan name: "Nutrition Fundamentals"
2. Enter description: "Learn about macronutrients and vitamins"
3. Wait for modal, enter bot name: "Dr. Nutrition"
4. Select grade level: "Senior Secondary"
5. Tap "Create Study Bot"
6. Watch 10-second progress animation
7. Chat Screen loads with bot ready
8. Type a question and see bot respond with its system instructions in mind

---

## Summary

**The bot creation flow is:**

1. **User Input** → Name, grade, topic via Phase 1 screen + modal
2. **Processing** → 10-second visual feedback while backend works
3. **AI Generation** → Groq AI creates personalized tutor instructions
4. **Database Save** → Bot stored with state, instructions, metadata
5. **Chat Ready** → Bot loaded into chat screen with state awareness
6. **Intelligent Responses** → Bot uses system instructions + state to answer questions

**Every step has error handling:**

- Validation at frontend and backend
- Graceful fallbacks if AI fails
- User-friendly error messages
- Retry capability

This creates a seamless, intelligent study bot experience! 🎓
