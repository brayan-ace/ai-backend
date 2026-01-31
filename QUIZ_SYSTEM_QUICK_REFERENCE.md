# Quiz System - Quick Reference Guide

## What Changed (TL;DR)

| File                          | Bug                       | Fix                             | Impact                                  |
| ----------------------------- | ------------------------- | ------------------------------- | --------------------------------------- |
| `quiz_config_screen.dart`     | Loading state never reset | Removed `_isLoading` variable   | Button no longer appears stuck          |
| `study_plan_chat_screen.dart` | No data validation        | Added `_isValidQuizData()`      | Invalid quiz data caught before display |
| `study_plan_chat_screen.dart` | Generic error messages    | Added emoji + specific messages | Users understand what happened          |
| `quiz_artifact_widget.dart`   | Field name mismatch       | Added fallback field names      | Quiz displays correctly                 |

---

## Testing the Quiz

### Normal Flow

1. Chat: "Let me test you with a quiz"
2. Bot: "📝 Ready for a Quiz?" (popup appears)
3. User: Click "Now"
4. Config: Select options and click "Start Quiz"
5. Chat: Loading spinner shows... (45 second timeout)
6. Quiz: Full screen dialog with questions & answers tabs
7. Close: Back to chat

### What Should NOT Happen Anymore

- ❌ "Start Quiz" button stuck with loading spinner after dialog closes
- ❌ Quiz displays as empty/incomplete even though backend returned data
- ❌ User sees raw error like "TimeoutException: Connection timed out"
- ❌ Questions show as blank even though they were generated

---

## Key Code Locations

### Quiz Configuration

```dart
lib/screens/quiz_config_screen.dart         // User selects MCQ/text, count, web search
  └─ _handleStartQuiz()  [LINE 409]         // NOW: Just calls callback, no loading state
```

### Quiz Generation

```dart
lib/screens/study_plan_chat_screen.dart
  ├─ _isValidQuizData()  [LINE ~3140]       // NEW: Validates quiz structure
  ├─ _generateQuiz()  [LINE ~3285]          // UPDATED: Better error handling
  ├─ _showQuizConfiguration()  [LINE ~3270] // Calls config screen
  ├─ _showQuizPopup()  [LINE ~3206]         // Initial popup
  └─ _showQuizArtifact()  [LINE ~3370]      // Display quiz
```

### Quiz Display

```dart
lib/widgets/quiz_artifact_widget.dart       // Display questions & answers
  ├─ _buildQuestionsTab()  [LINE ~165]      // UPDATED: Better field name handling
  └─ _buildAnswersTab()  [LINE ~275]        // UPDATED: Support multiple field names
```

---

## Error Messages

| Scenario       | Message                                                        | Action                     |
| -------------- | -------------------------------------------------------------- | -------------------------- |
| Timeout (45s+) | ⏱️ "The quiz generation took too long. Please try again..."    | Retry with fewer questions |
| Bad config     | ❌ "I couldn't generate the quiz with those parameters..."     | Try different options      |
| Server error   | 🔧 "Our quiz generator is having trouble right now..."         | Wait and retry             |
| Invalid data   | 📝 "Quiz generation completed, but structure seems invalid..." | System retries             |
| Network error  | ⚠️ "I had trouble... Please check internet connection..."      | Check WiFi/mobile          |

---

## Validation Rules

**Quiz is VALID if:**

- ✅ Questions array has at least 1 item
- ✅ Answers array has at least 1 item
- ✅ Each question has a text field (supports 'question' or 'text')
- ✅ Each answer has an answer field (supports 'answer' or 'correct_answer')
- ✅ All text fields are non-empty strings

**Quiz is INVALID if:**

- ❌ Either array is empty or missing
- ❌ Any item is not a Map/dictionary
- ❌ Any text field is null or empty string
- ❌ Exception thrown during validation

---

## Common Issues & Solutions

### Issue: Quiz button shows loading spinner forever

**Cause**: Old code had loading state in config screen that was never reset

**Status**: ✅ FIXED (removed loading state from config screen)

**Test**: Click "Start Quiz" → button should be normal (not spinner), dialog closes immediately

---

### Issue: Quiz displays as empty

**Cause**: Backend field names different than expected (e.g., 'question' vs 'text')

**Status**: ✅ FIXED (added fallback field names)

**Test**: Questions should appear even if backend uses different field names

---

### Issue: User sees "Network error while generating quiz: TimeoutException: ..."

**Cause**: Raw exception text shown instead of friendly message

**Status**: ✅ FIXED (added user-friendly error messages with emoji)

**Test**: After 45 seconds with no response, should see: "⏱️ The quiz generation took too long..."

---

### Issue: Invalid quiz data crashes display widget

**Cause**: No validation before sending quiz to display widget

**Status**: ✅ FIXED (added \_isValidQuizData() validation)

**Test**: Invalid data shows message: "📝 Quiz generation completed, but structure seems invalid..."

---

## Debug Mode

### Enable Detailed Logging

Look for these in console:

```
[ChatScreen] Quiz generated successfully
[ChatScreen] Quiz questions count: 8
[ChatScreen] Quiz answers count: 8
[ChatScreen] Showing quiz artifact with ID: 42

[QuizArtifactWidget] Question 0 text: "What is..."
```

### Monitor Loading State

The `_isLoading` boolean should:

- Be `true` while POST request is pending
- Be `false` after response received (success or error)
- Be in `study_plan_chat_screen.dart` ONLY (not in quiz_config_screen)

### Check Validation

If quiz doesn't display, check console for:

```
[ChatScreen] Invalid quiz: no questions
[ChatScreen] Question 2 missing text
[ChatScreen] Answer 1 missing answer text
```

---

## Performance Targets

| Operation                | Target  | Acceptable | Poor    |
| ------------------------ | ------- | ---------- | ------- |
| Config dialog open/close | < 100ms | < 500ms    | > 500ms |
| Quiz generation          | < 30s   | < 45s      | > 45s   |
| Validation check         | < 50ms  | < 100ms    | > 100ms |
| Quiz display render      | < 200ms | < 500ms    | > 500ms |

---

## Integration Checklist

- ✅ Backend /api/generate-quiz endpoint tested
- ✅ Quiz configuration screen properly calls callback
- ✅ Chat screen manages loading state during generation
- ✅ Quiz data validated before display
- ✅ Error messages are user-friendly
- ✅ Field name compatibility verified
- ✅ No console errors or warnings
- ✅ Quiz displays with questions and answers
- ✅ Explanation callback functional
- ✅ Analytics tracking working

---

## File Modification Summary

### quiz_config_screen.dart

```dart
- Line 27: Removed `bool _isLoading = false;`
- Lines 409-429: Updated _handleStartQuiz() to not set loading state
- Lines 367-399: Simplified Start Quiz button (removed conditional loading UI)
```

### study_plan_chat_screen.dart

```dart
+ Lines ~3140-3190: NEW _isValidQuizData() method
+ Lines ~3285-3370: UPDATED _generateQuiz() with better error handling
  - Added timeout exception handling
  - Added status-code specific error messages
  - Added exception-specific handling
  - Added mounted checks
  - Added quiz validation
```

### quiz_artifact_widget.dart

```dart
+ Line ~165-260: UPDATED _buildQuestionsTab() for field name compatibility
+ Line ~275-290: UPDATED _buildAnswersTab() for field name compatibility
  - Added fallback field name checking
  - Added validation before display
  - Added warning logging for invalid data
```

---

## Backend Reference

**Endpoint**: `POST /api/generate-quiz`
**Location**: `backend/server.js` line 2275

**Request**:

```json
{
  "botId": "bot_xxx",
  "userId": "user_uid",
  "moduleName": "Module 1",
  "moduleContent": "Recent conversation...",
  "questionType": "both",
  "mcqCount": 5,
  "textCount": 3,
  "useWebSearch": true,
  "gradeLevel": "10th Grade",
  "topic": "Biology"
}
```

**Response**:

```json
{
  "success": true,
  "quiz": {
    "questions": [
      {
        "id": 1,
        "question": "What is photosynthesis?",
        "type": "mcq",
        "options": ["A...", "B...", "C...", "D..."]
      }
    ],
    "answers": [
      {
        "question_id": 1,
        "answer": "A",
        "explanation": "..."
      }
    ]
  },
  "quizId": 42,
  "metadata": {
    "enhanced": true,
    "personalized": true,
    "generatedAt": "2024-01-15T..."
  }
}
```

---

## Related Documentation

- 📖 [Full Analysis](QUIZ_SYSTEM_COMPREHENSIVE_ANALYSIS.md)
- 🔧 [Implementation Details](QUIZ_SYSTEM_FIXES_IMPLEMENTATION.md)
- 📊 [Visual Flow Diagrams](QUIZ_SYSTEM_VISUAL_FLOW_GUIDE.md)

---

## Support

### For Developers

1. Check console for `[ChatScreen]` and `[QuizArtifactWidget]` logs
2. Verify quiz data structure matches backend response format
3. Check network tab for POST /api/generate-quiz request/response
4. Ensure 45-second timeout is appropriate for your backend

### For QA/Testing

1. Test with all question type combinations (MCQ, text, both)
2. Test with different question counts (1, 5, 10)
3. Test with web search ON and OFF
4. Simulate network timeout (disconnect internet after 45s)
5. Verify error messages appear for different failure modes
6. Check quiz data displays correctly with loaded questions

### For Users

1. ✅ Quiz generation works with any topic
2. ✅ Quizzes are personalized based on conversation
3. ✅ Error messages explain what to do next
4. ✅ Can request deeper explanations for answers
5. ✅ Quiz history tracked for analytics
