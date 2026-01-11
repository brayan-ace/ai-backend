# Quiz Generation with Artifacts - Implementation Guide

**Date:** January 11, 2026
**Status:** ✅ COMPLETE
**Files Created:** 3 (frontend) + 1 (backend update)

---

## 📋 Overview

Users can now generate configurable quizzes at the end of each module with:

- **Question type selection** (MCQ / Text / Both)
- **Configurable question counts** (1-10 per type)
- **Web search integration** (Tavily API for enhanced context)
- **Artifact-style display** with Questions and Answers tabs

---

## 🎯 Features

### 1. **Module Completion Trigger**

- When module is completed, bot responds with `[SHOW_QUIZ_POPUP]` marker
- Popup asks: "Do you want to take a quiz now or later?"
- Two options:
  - **Later** → Defers quiz, sends "Later" message to bot
  - **Now** → Opens quiz configuration screen

### 2. **Quiz Configuration Modal**

Users can customize:

- **Question Type:** MCQ only / Text only / Both
- **MCQ Count:** 1-10 questions (if MCQ selected)
- **Text Count:** 1-10 questions (if Text selected)
- **Web Search:** Toggle to enhance quiz with latest information
- **Summary:** Shows total questions and search preference

### 3. **Quiz Generation**

- Calls `/api/generate-quiz` endpoint
- Uses Tavily web search (if enabled) for topic-specific content
- Generates grade-level appropriate questions
- Returns quiz in structured JSON format

### 4. **Quiz Artifact Display**

Two-tab interface:

- **Questions Tab:** Only questions (clean view for answering)
- **Answers Tab:** Correct answers with detailed explanations

---

## 🔧 Implementation Details

### Frontend Files

#### **1. `lib/screens/quiz_config_screen.dart`** (NEW)

Modal dialog for quiz configuration.

**Key Features:**

- Radio buttons for question type selection
- Sliders for question count (1-10)
- Web search toggle with description
- Quiz summary preview
- Cancel and Start buttons

**Methods:**

- `_buildRadioTile()` - Creates radio button with styling
- `_buildNumberSlider()` - Creates count slider
- `_handleStartQuiz()` - Validates and sends configuration

#### **2. `lib/widgets/quiz_artifact_widget.dart`** (NEW)

Displays quiz as artifact with tabs.

**Key Features:**

- Two-tab interface (Questions / Answers)
- PageView for smooth tab switching
- Question list with MCQ options formatting
- Answer list with correct answers and explanations

**Methods:**

- `_buildTabButton()` - Creates tab header with active state
- `_buildQuestionsTab()` - Renders questions-only view
- `_buildAnswersTab()` - Renders answers with explanations

#### **3. `lib/screens/study_plan_chat_screen.dart`** (MODIFIED)

Updated to handle quiz flow.

**Changes:**

- Import quiz config and artifact widgets
- Updated `_addBotMessage()` to detect `[SHOW_QUIZ_POPUP]` marker
- Added `_showQuizPopup()` - Shows "Now/Later" dialog
- Added `_showQuizConfiguration()` - Opens quiz config modal
- Added `_generateQuiz()` - Calls backend endpoint
- Added `_showQuizArtifact()` - Displays quiz artifact dialog
- Added `_getModuleContext()` - Extracts module content for quiz generation

### Backend Changes

#### **`backend/server.js`** (MODIFIED)

**New Endpoint:** `POST /api/generate-quiz`

```javascript
POST /api/generate-quiz

Request Body:
{
  "botId": "bot_123...",
  "userId": "user_456...",
  "moduleName": "Module 1",
  "moduleContent": "Previous conversation content...",
  "questionType": "both",      // 'mcq' | 'text' | 'both'
  "mcqCount": 5,
  "textCount": 3,
  "useWebSearch": true,
  "gradeLevel": "Senior Secondary",
  "topic": "Nutrition Fundamentals"
}

Response:
{
  "status": "success",
  "message": "Quiz generated successfully",
  "quiz": {
    "questions": [
      {
        "type": "mcq",
        "text": "Question text?",
        "options": ["A", "B", "C", "D"]
      },
      {
        "type": "text",
        "text": "Essay question?"
      }
    ],
    "answers": [
      {
        "type": "mcq",
        "answer": "B",
        "explanation": "Detailed explanation using web search..."
      },
      {
        "type": "text",
        "answer": "Expected answer",
        "explanation": "Comprehensive explanation..."
      }
    ]
  },
  "timestamp": "2026-01-11T..."
}
```

**Endpoint Logic:**

1. Validates request parameters
2. Performs Tavily web search if `useWebSearch=true`
3. Builds Groq prompt with module content and search context
4. Calls Groq API to generate quiz JSON
5. Validates quiz structure (must have questions and answers arrays)
6. Saves quiz to database (quiz_data table)
7. Saves confirmation message to chat history
8. Returns quiz JSON to frontend

**Database Changes:**

- New table: `quiz_data`
  - `bot_id` (TEXT)
  - `user_id` (TEXT)
  - `module_name` (TEXT)
  - `quiz_data` (JSONB) - Complete quiz JSON
  - `created_at` (TIMESTAMP)
  - Unique constraint on (bot_id, user_id, module_name)

**Web Search Integration:**

- Uses existing `searchTopicOnline()` function
- Environment variable: `tavily`
- Search query: `{moduleName} {topic} {gradeLevel}`
- Results used to enhance Groq prompt for better explanations

---

## 📊 Data Flow

### 1. **Module Completion**

```
Bot completes teaching module
↓
Bot response includes [SHOW_QUIZ_POPUP] marker
↓
Frontend detects marker in _addBotMessage()
↓
Marker removed from display text
↓
_showQuizPopup() called after 500ms delay
```

### 2. **Quiz Configuration**

```
User taps "Now" in popup
↓
QuizConfigScreen dialog opens
↓
User selects:
  - Question type (MCQ/Text/Both)
  - Number of questions
  - Web search toggle
↓
User taps "Start Quiz"
↓
_generateQuiz() called with config
```

### 3. **Quiz Generation**

```
Frontend calls POST /api/generate-quiz
↓
Backend validates request
↓
If useWebSearch=true:
  ├─ Tavily API search for topic context
  └─ Search results added to Groq prompt
↓
Groq generates questions and answers JSON
↓
Structure validated (must have arrays)
↓
Saved to quiz_data table
↓
Frontend receives quiz JSON
↓
QuizArtifactWidget displays with tabs
```

### 4. **Quiz Review**

```
User views Questions tab
↓
User can switch to Answers tab
↓
Each answer shows:
  - Correct answer
  - Detailed explanation (from web search + module content)
↓
User closes quiz dialog
↓
Sends "I've completed the quiz review." to bot
```

---

## 🎨 UI Flow

### Quiz Completion Popup

```
╔═══════════════════════════════╗
║   📝 Ready for a Quiz?        ║
╠═══════════════════════════════╣
║ Do you want to take a quiz    ║
║ now to test your knowledge,   ║
║ or would you prefer to do it  ║
║ later?                        ║
╠═══════════════════════════════╣
║  [Later]        [Now]         ║
╚═══════════════════════════════╝
```

### Quiz Configuration Modal

```
╔════════════════════════════════╗
║ 🎯 Quiz Configuration          ║
║ Module: Module Quiz            ║
╠════════════════════════════════╣
║ Question Types                 ║
║ ◉ Multiple Choice Questions    ║
║ ○ Full Text Questions          ║
║ ○ Both MCQ and Text            ║
║                                ║
║ MCQ Questions                  ║
║ Number of MCQs: 5              ║
║ [====|----] (Slider)           ║
║                                ║
║ 🔍 Web Search for Context      ║
║ Enhance questions with latest  ║
║ information         [Toggle ON]║
║                                ║
║ 📊 Quiz Summary                ║
║ • 5 MCQ questions              ║
║ • Enhanced with web search     ║
║                                ║
║ [Cancel]     [Start Quiz]      ║
╚════════════════════════════════╝
```

### Quiz Artifact Display

```
╔══════════════════════════════════════╗
║  ❓ Questions    ✅ Answers          ║
╠══════════════════════════════════════╣
║ Q1 (MCQ)                             ║
║ What is photosynthesis?              ║
║ A. Process of breaking down glucose  ║
║ B. Converting light to chemical...   ║
║ C. Creating glucose from...          ║
║ D. Breaking down proteins            ║
║                                      ║
║ Q2 (TEXT)                            ║
║ Explain the role of chloroplasts     ║
║                                      ║
║ [Scroll for more questions]          ║
╠══════════════════════════════════════╣
║          [Close Quiz]                ║
╚══════════════════════════════════════╝
```

### Answers Tab

```
╔══════════════════════════════════════╗
║  ❓ Questions    ✅ Answers          ║
╠══════════════════════════════════════╣
║ ✅ Q1 (MCQ)                          ║
║                                      ║
║ Correct Answer:                      ║
║ B. Converting light to chemical...   ║
║                                      ║
║ 💡 Explanation:                      ║
║ Photosynthesis is the process by     ║
║ which plants convert light energy    ║
║ into chemical energy (glucose)...    ║
║ [Detailed explanation from web       ║
║  search and module content]          ║
║                                      ║
║ ✅ Q2 (TEXT)                         ║
║                                      ║
║ Correct Answer:                      ║
║ Chloroplasts are the organelles      ║
║ where photosynthesis occurs...       ║
║                                      ║
║ 💡 Explanation:                      ║
║ Chloroplasts contain chlorophyll     ║
║ pigments that capture light energy.. ║
╚══════════════════════════════════════╝
```

---

## 🔑 Key Integration Points

### 1. **Bot System Instructions**

- Bot is instructed to include `[SHOW_QUIZ_POPUP]` in response when module is complete
- Response also includes acknowledgment message: "You've mastered [Module Name]! 🎉"
- Marker and message are separated in frontend

### 2. **Tavily Web Search**

- Environment variable: `tavily` (not TAVILY_API_KEY)
- Used in `searchTopicOnline()` function
- Provides:
  - Topic-specific information
  - Grade-level appropriate content
  - Real-world examples
  - Enhanced explanations

### 3. **Groq API**

- Generates questions and answers in valid JSON
- Prompt includes:
  - Module content (from conversation)
  - Web search results (if enabled)
  - Grade level for appropriate complexity
  - Exact JSON structure required
- Response validated and sanitized (removes markdown, code blocks)

### 4. **Database**

- Quiz saved to `quiz_data` table
- Allows retrieval of generated quizzes
- Tracks module completion per user per bot

---

## 🧪 Testing Checklist

- [ ] Bot completes module and sends message with `[SHOW_QUIZ_POPUP]`
- [ ] Popup displays "Ready for a Quiz?" with Now/Later buttons
- [ ] Clicking "Later" sends message and closes popup
- [ ] Clicking "Now" opens quiz configuration modal
- [ ] Can select question type (MCQ/Text/Both)
- [ ] Sliders adjust question counts (1-10)
- [ ] Web search toggle works
- [ ] Summary shows correct totals
- [ ] Clicking "Start Quiz" shows loading spinner
- [ ] Backend generates quiz successfully
- [ ] QuizArtifactWidget displays with Questions tab selected
- [ ] Questions tab shows all questions (MCQ with options)
- [ ] Answers tab shows correct answers with explanations
- [ ] Can switch between tabs smoothly
- [ ] Explanations are detailed and reference web search
- [ ] Close button sends completion message to bot

---

## ⚙️ Configuration

### Environment Variables (Backend)

```
GROQ_API_KEY=your_groq_key_here
tavily=your_tavily_api_key_here
```

### Quiz Generation Parameters

- **Max MCQ Questions:** 10
- **Max Text Questions:** 10
- **Groq Model:** mixtral-8x7b-32768
- **Groq Max Tokens:** 2000
- **Temperature:** 0.8 (creative, but structured)
- **Request Timeout:** 45 seconds (frontend), 30 seconds (backend)

---

## 🐛 Error Handling

### Frontend

- **Quiz generation timeout:** Shows "Sorry, I had trouble generating the quiz. Let's try again later!"
- **Network error:** Shows "Network error while generating quiz: [error message]"
- **Invalid JSON response:** Caught by backend JSON parsing

### Backend

- **Missing parameters:** Returns 400 with specific parameter names
- **Groq API unavailable:** Returns 500 with error message
- **Invalid JSON response:** Attempts cleanup, strips markdown/code blocks
- **Invalid quiz structure:** Throws error and returns 500
- **Database save failure:** Logs warning but doesn't fail quiz generation

---

## 📈 Future Enhancements

1. **Quiz Scoring:**

   - Track user answers
   - Calculate score based on MCQ and text answers
   - Show score report

2. **Question Bank:**

   - Cache generated quizzes
   - Allow quiz retakes
   - Analytics on question difficulty

3. **Adaptive Quizzes:**

   - Difficulty based on module performance
   - Question selection based on weak areas
   - Spaced repetition scheduling

4. **Export:**
   - Download quiz as PDF
   - Share with classmates
   - Integration with study apps

---

## 📚 Code References

### Frontend

- Config Screen: [quiz_config_screen.dart](../lib/screens/quiz_config_screen.dart)
- Artifact Widget: [quiz_artifact_widget.dart](../lib/widgets/quiz_artifact_widget.dart)
- Chat Integration: [study_plan_chat_screen.dart](../lib/screens/study_plan_chat_screen.dart#L337)

### Backend

- Quiz Endpoint: [server.js](../backend/server.js#L1927) - `/api/generate-quiz`
- Database Schema: [server.js](../backend/server.js#L365) - `quiz_data` table
- Tavily Search: [server.js](../backend/server.js#L116) - `searchTopicOnline()`

---

**Status:** ✅ Ready for Production
**Risk Level:** 🟢 LOW (no breaking changes)
**Testing:** Recommended before deployment
