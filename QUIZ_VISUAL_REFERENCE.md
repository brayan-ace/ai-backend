# Quiz Generation - Visual Reference & Testing Guide

## 🎨 UI Components Layout

### 1. Quiz Popup Dialog

```
┌─────────────────────────────────────┐
│   📝 Ready for a Quiz?              │
├─────────────────────────────────────┤
│                                     │
│  Do you want to take a quiz now    │
│  to test your knowledge, or would  │
│  you prefer to do it later?        │
│                                     │
├─────────────────────────────────────┤
│  [Later]                  [Now]     │
└─────────────────────────────────────┘
```

**Position:** Center of screen
**Trigger:** When bot sends `[SHOW_QUIZ_POPUP]` marker
**Buttons:** Later (closes), Now (opens config)

---

### 2. Quiz Configuration Modal

```
╔═════════════════════════════════════╗
║ 🎯 Quiz Configuration               ║
║                                     ║
║ Module: Module Quiz                 ║
╠═════════════════════════════════════╣
║                                     ║
║ Question Types                      ║
║ ◉ Multiple Choice Questions (MCQ)   ║
║ ○ Full Text Questions               ║
║ ○ Both MCQ and Text                 ║
║                                     ║
║ MCQ Questions                       ║
║ Number of MCQs: 5                   ║
║ ├──────●───────┤ (Slider)           ║
║      1        10                    ║
║                                     ║
║ 🔍 Web Search for Context           ║
║ Enhance questions with latest       ║
║ information            [Toggle: ON] ║
║                                     ║
║ 📊 Quiz Summary                     ║
║ • 5 MCQ questions                   ║
║ • Enhanced with web search          ║
║                                     ║
║ [Cancel]            [Start Quiz]    ║
╚═════════════════════════════════════╝
```

**Position:** Center of screen, fullscreen
**Auto-dismiss:** No (user must click Cancel or Start)
**Configuration Saved:** Temporarily (for session)

---

### 3. Quiz Artifact Display

```
╔════════════════════════════════════════╗
║  ❓ Questions     ✅ Answers           ║  ← Tab Headers
╠════════════════════════════════════════╣
║                                        ║
║ Q1 (MCQ)                               ║
║ What is photosynthesis?                ║
│                                        │
║ A. Process of breaking down glucose    ║
║ B. Converting light to chemical...     ║
║ C. Creating glucose from light...      ║
║ D. Breaking down proteins              ║
║                                        ║
║ Q2 (TEXT)                              ║
║ Explain the role of chloroplasts.      ║
║                                        ║
║ [Scroll for more questions...]         ║
║                                        ║
╠════════════════════════════════════════╣
║       [Close Quiz]                     ║
╚════════════════════════════════════════╝
```

**Questions Tab:**

- Shows MCQ with A/B/C/D options
- Shows text questions as plain text
- Scrollable list
- No answers visible

**Answers Tab:**

```
╔════════════════════════════════════════╗
║  ❓ Questions     ✅ Answers           ║  ← Answers selected
╠════════════════════════════════════════╣
║                                        ║
║ ✅ Q1 (MCQ)                            ║
║                                        ║
║ Correct Answer:                        ║  ← Answer box
║ ┌──────────────────────────────────┐  ║
║ │ B. Converting light to chemical  │  ║
║ │    energy (glucose)              │  ║
║ └──────────────────────────────────┘  ║
║                                        ║
║ 💡 Explanation:                        ║  ← Explanation section
║ Photosynthesis is the process by       ║
║ which plants convert light energy      ║
║ into chemical energy called glucose.   ║
║ This happens in the chloroplasts of    ║
║ the plant cells, where the pigment     ║
║ chlorophyll absorbs sunlight...        ║
║                                        ║
║ ✅ Q2 (TEXT)                           ║
║                                        ║
║ Correct Answer:                        ║
║ ┌──────────────────────────────────┐  ║
║ │ Chloroplasts are the organelles  │  ║
║ │ within plant cells where         │  ║
║ │ photosynthesis occurs. They      │  ║
║ │ contain chlorophyll pigments...  │  ║
║ └──────────────────────────────────┘  ║
║                                        ║
║ 💡 Explanation:                        ║
║ [Detailed explanation with web        ║
║  search context...]                   ║
║                                        ║
╠════════════════════════════════════════╣
║       [Close Quiz]                     ║
╚════════════════════════════════════════╝
```

**Position:** Full dialog covering most of screen
**Height:** Max 85% of screen height
**Scrollable:** Yes, for long questions/answers
**Tab Switching:** Smooth PageView animation

---

## 🧪 Testing Scenarios

### Scenario 1: MCQ-Only Quiz

```
Config:
- Question Type: MCQ only
- MCQ Count: 3
- Web Search: ON

Expected Result:
- 3 MCQ questions in Questions tab
- 3 answers with correct options in Answers tab
- 0 text questions

Backend Call:
POST /api/generate-quiz {
  questionType: "mcq",
  mcqCount: 3,
  textCount: 0,
  useWebSearch: true
}
```

### Scenario 2: Mixed Quiz (Both Types)

```
Config:
- Question Type: Both
- MCQ Count: 4
- Text Count: 2
- Web Search: OFF

Expected Result:
- 4 MCQ questions + 2 text questions = 6 total
- Each with detailed explanations
- No web search context (but module content used)

Backend Call:
POST /api/generate-quiz {
  questionType: "both",
  mcqCount: 4,
  textCount: 2,
  useWebSearch: false
}
```

### Scenario 3: Text-Only Quiz with Search

```
Config:
- Question Type: Text only
- Text Count: 5
- Web Search: ON

Expected Result:
- 5 text/essay questions
- Answers with web search enhanced explanations
- No MCQ questions

Backend Call:
POST /api/generate-quiz {
  questionType: "text",
  mcqCount: 0,
  textCount: 5,
  useWebSearch: true
}
```

---

## 🔍 Data Validation Checks

### Frontend Validation

- [ ] Question type radio button properly selected
- [ ] MCQ count in range 1-10
- [ ] Text count in range 1-10
- [ ] Web search toggle working
- [ ] Summary shows correct totals

### Backend Validation

- [ ] Required fields present: botId, userId, moduleName
- [ ] questionType is one of: 'mcq', 'text', 'both'
- [ ] Counts are positive integers
- [ ] gradeLevel and topic provided for web search

### Response Validation

- [ ] Questions array present and non-empty
- [ ] Answers array present and non-empty
- [ ] Each question has: type, text, (options for MCQ)
- [ ] Each answer has: type, answer, explanation
- [ ] Question count matches configured count
- [ ] Answer count equals question count

---

## 📱 Screen States

### Loading State

```
User clicks "Start Quiz"
↓
Button shows spinner: CircularProgressIndicator
Button text: "Start Quiz" → Hidden (only spinner visible)
Button disabled: true
Modal: Not dismissible during loading
Timeout: 45 seconds max
```

### Success State

```
Quiz received successfully
↓
Modal closes
↓
New dialog appears with QuizArtifactWidget
↓
Questions tab selected by default
↓
Both tabs interactive and switchable
```

### Error State

```
Quiz generation fails (backend error, timeout, etc.)
↓
Modal closes
↓
Bot message added: "Sorry, I had trouble generating the quiz..."
↓
User can retry by asking for quiz again
```

---

## 🐛 Common Issues & Debugging

### Issue: "Quiz popup doesn't show"

**Debug:**

- Check bot response contains `[SHOW_QUIZ_POPUP]`
- Check Flutter logs for `[ChatScreen]` messages
- Verify `_addBotMessage()` is called
- Check delay timer is working (500ms)

### Issue: "Config modal doesn't open"

**Debug:**

- Check "Now" button click is triggered
- Check `showDialog()` is called
- Check QuizConfigScreen is imported
- Verify no navigation errors in logs

### Issue: "Quiz generation timeout"

**Debug:**

- Check backend is running
- Check `tavily` env var is set (if web search enabled)
- Check `GROQ_API_KEY` is set
- Monitor backend logs for Groq API calls
- Increase timeout from 45s if needed

### Issue: "Invalid JSON from Groq"

**Debug:**

- Backend attempts JSON cleanup (removes markdown)
- If cleanup fails, returns 500 error
- Check Groq response in backend logs
- Verify prompt structure is correct

---

## 📊 Performance Metrics

| Operation             | Expected Time | Max Time |
| --------------------- | ------------- | -------- |
| Show popup            | <100ms        | 500ms    |
| Open config           | <300ms        | 1000ms   |
| Web search            | 2-5s          | 10s      |
| Groq generation       | 3-8s          | 30s      |
| Total quiz generation | 5-15s         | 45s      |
| Display artifact      | <500ms        | 1000ms   |
| Tab switch            | 300ms         | 500ms    |

---

## 🔐 Security Checks

- [ ] No student data exposure in logs
- [ ] Quiz content not cached where inappropriate
- [ ] Bot ID and User ID properly validated
- [ ] Groq API key not logged
- [ ] Tavily API key not logged
- [ ] Database queries use parameterized statements

---

## 📦 Deployment Checklist

- [ ] All 3 new Flutter files created
- [ ] Backend `/api/generate-quiz` endpoint added
- [ ] `quiz_data` table created in database
- [ ] Environment variables set: `GROQ_API_KEY`, `tavily`
- [ ] Dependencies included (http package for Flutter)
- [ ] System instructions updated with `[SHOW_QUIZ_POPUP]` marker
- [ ] Database migration run (ensureTables creates quiz_data)
- [ ] Test on device with real Groq API
- [ ] Test with web search enabled and disabled
- [ ] Test with different question type combinations
- [ ] Monitor backend logs for errors
- [ ] Monitor frontend logs for navigation issues

---

## 🚀 Go-Live Verification

**Before deploying to production:**

1. **Backend Tests**

   ```bash
   POST /api/generate-quiz
   - Test with all question type combinations
   - Test with web search ON and OFF
   - Verify database saves quiz correctly
   - Check response JSON structure
   ```

2. **Frontend Tests**

   - Complete end-to-end flow from module completion
   - Verify all UI states work correctly
   - Test on multiple devices/orientations
   - Check performance on slow connections

3. **Integration Tests**

   - Bot completes module → Popup shows
   - User configures quiz → Generation starts
   - Quiz displays → Tab switching works
   - User closes → Message sent to bot
   - Bot continues normally

4. **Error Scenarios**
   - Timeout handling
   - Network disconnection
   - Invalid Groq response
   - Database failure
   - Missing environment variables

---

**Status:** All components ready for testing ✅
**Next Step:** Device testing and validation
