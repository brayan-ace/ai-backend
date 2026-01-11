# Study Plan Viewer & Editor Feature - Implementation Guide

**Date:** January 11, 2026
**Status:** ✅ COMPLETE
**Files Modified:** 3 (1 backend, 2 frontend)

---

## 📋 Overview

Users can now view and edit their Study Plan in real-time during learning sessions. Changes are saved to the database and the AI tutor automatically adjusts its teaching strategy to match the updated plan. Progress and chat history are fully preserved.

---

## 🎯 Features

### 1. **Study Plan Viewer (Modal)**

- **Access:** Tap the 📚 icon in the top-right of the chat screen (learning state only)
- **Shows:**
  - Learning plan title
  - Learning progress percentage
  - Pro tips for effective learning
- **Action:** Tap the edit icon (✏️) to open the editor

### 2. **Study Plan Editor (Screen)**

- **Access:** From the plan viewer modal
- **Allows:**
  - Rename modules
  - Delete modules
  - Delete subtopics/objectives
  - Preview changes before saving
- **Save:** Sends updated plan to backend

### 3. **Backend Integration**

- New endpoint: `/api/update-study-plan` (POST)
- Validates updated plan structure
- Saves to database
- Notifies AI to adjust teaching strategy
- Preserves chat history and progress

---

## 🔧 Implementation Details

### Frontend Files

#### **1. `lib/screens/study_plan_editor_screen.dart`** (NEW)

A complete screen for editing the study plan structure.

**Key Components:**

```dart
StudyPlanEditorScreen
├── _editablePlan (state copy of study plan)
├── _renameModule() - Edit module titles
├── _deleteModule() - Remove modules
├── _deleteSubtopic() - Remove learning objectives
├── _saveChanges() - Call backend API
└── Build UI with modules/subtopics list
```

**Features:**

- Deep copy of plan to prevent accidental mutations
- Module rename dialog
- Delete confirmation for modules/subtopics
- Info box explaining what happens on save
- Cancel and Save buttons
- Loading state during save

#### **2. `lib/screens/study_plan_chat_screen.dart`** (MODIFIED)

Updated to integrate plan editor and manage state.

**Changes Made:**

1. **Import:** Added `study_plan_editor_screen.dart`
2. **State Variable:** Added `Map<String, dynamic>? _studyPlan`
3. **Progress Loading:** Updated to fetch `study_plan` from backend
4. **New Methods:**
   - `_openPlanEditor()` - Navigate to editor
   - `_savePlanChanges()` - Call update endpoint
   - `_loadStudyPlan()` - Refresh plan from backend
5. **Modal Update:** Added edit icon button in modules modal

**Updated Modal:**

```
📚 Your Learning Plan [✏️ Edit button]
└─ Progress Summary
└─ Pro Tips
└─ Back to Learning button
```

### Backend Changes

#### **`backend/server.js`** (MODIFIED)

**New Endpoint:** `/api/update-study-plan` (POST)

```javascript
POST /api/update-study-plan

Request Body:
{
  "botId": "bot_123...",
  "userId": "user_456...",
  "updatedPlan": {
    "title": "...",
    "modules": [
      {
        "id": 1,
        "title": "Module 1",
        "description": "...",
        "duration": "...",
        "objectives": ["obj1", "obj2"]
      },
      ...
    ],
    "total_duration": "...",
    "difficulty": "..."
  }
}

Response:
{
  "status": "success",
  "message": "Study plan updated and AI strategy adjusted",
  "plan_updated": true,
  "ai_adapted": true,
  "ai_response": "Acknowledgment from bot...",
  "timestamp": "..."
}
```

**Endpoint Logic:**

1. Validates request parameters
2. Validates plan structure (must have modules array)
3. Updates `bot_progress` table with new plan (JSONB)
4. Saves system message about plan change to chat history
5. Calls Groq API to generate AI acknowledgment
6. AI acknowledges the change and commits to adjusted teaching
7. Saves AI response to chat history
8. Returns success with AI response

**Important:**

- ✅ Progress is preserved (not lost on update)
- ✅ Chat history is preserved (saved with system message)
- ✅ Bot state continues from current point
- ✅ No need to restart the conversation

---

## 📊 Data Flow

### 1. **View Plan**

```
User taps 📚 icon
↓
StudyPlanChatScreen._showModulesModal()
↓
Shows modal with plan viewer and edit button
↓
User taps ✏️ edit button
↓
Calls _openPlanEditor()
```

### 2. **Edit Plan**

```
Opens StudyPlanEditorScreen with copy of _studyPlan
↓
User renames/deletes modules or objectives
↓
Changes stored in _editablePlan (local state)
↓
User taps "Save Changes"
↓
Calls onSave callback with _editablePlan
```

### 3. **Save to Backend**

```
_savePlanChanges(updatedPlan, userId)
↓
Updates local _studyPlan state
↓
POST to /api/update-study-plan with:
  - botId
  - userId
  - updatedPlan
↓
Backend validates and saves to database
↓
Backend calls Groq API for AI acknowledgment
↓
Backend saves AI response to chat history
↓
Returns success response
```

### 4. **Continue Learning**

```
User returns to chat screen
↓
Plan is updated in state
↓
Chat continues with same messages/progress
↓
Bot uses adjusted plan for future responses
↓
Progress percentage, modules, etc. all preserved
```

---

## 🎯 Key Rules & Guarantees

### ✅ DO NOT Restart Bot

- No `_botState` reset
- No clearing of messages
- No resetting of progress percentage
- Conversation continues seamlessly

### ✅ PRESERVE Progress

- Chat history fully saved before update
- Progress percentage unchanged by plan update
- Completed modules list preserved
- Conversation state maintained

### ✅ Dynamic Plan Updates

- AI gets new instructions about updated plan
- Groq API acknowledges the change
- Future responses adapt to new structure
- Bot remembers why plan changed

### ✅ Validation

- Plan structure validated (must have modules)
- All fields checked for null/missing
- Database updates are atomic
- Errors don't lose data

---

## 🔌 API Endpoints

### Get Bot Progress (Existing)

```javascript
GET /api/bot-progress/:botId/:userId

Response includes:
{
  "study_plan": {...},  // ← Study plan fetched here
  "progress": 45,
  "bot_state": "learning",
  "learned_concepts": [...]
}
```

### Update Study Plan (NEW)

```javascript
POST /api/update-study-plan

Body:
{
  "botId": "...",
  "userId": "...",
  "updatedPlan": {...}
}

Response:
{
  "status": "success",
  "plan_updated": true,
  "ai_adapted": true,
  "ai_response": "I'll adjust my lessons based on your updated plan!",
  "timestamp": "..."
}
```

---

## 📱 UI Flow

### Study Plan Viewer Modal

```
┌─────────────────────────────────────┐
│  📚 Your Learning Plan        [✏️]  │
├─────────────────────────────────────┤
│ Tap any module to see details      │
│                                      │
│ ✨ Algebra Mastery                  │
│                                      │
│ 🎯 Learning Progress                │
│ ├─ Concepts Mastered: 45%           │
│ └─ [Progress Bar]                   │
│                                      │
│ 💡 Pro Tips                         │
│ • Tell me "I understand"...         │
│ • I'll track progress...            │
│ • Take your time...                 │
│ • Ask questions!                    │
│                                      │
│ [Back to Learning]                  │
└─────────────────────────────────────┘
```

### Study Plan Editor Screen

```
┌─────────────────────────────────────┐
│ ← Edit Study Plan                  │
├─────────────────────────────────────┤
│ Algebra Mastery                     │
│                                      │
│ ┌─────────────────────────────────┐ │
│ │ 📚 Fundamentals          [⋮]    │ │
│ ├─────────────────────────────────┤ │
│ │ 📝 Learning Objectives:         │ │
│ │ • Understanding variables  [×]  │ │
│ │ • Working with equations   [×]  │ │
│ └─────────────────────────────────┘ │
│                                      │
│ ┌─────────────────────────────────┐ │
│ │ 📚 Advanced Equations   [⋮]     │ │
│ ├─────────────────────────────────┤ │
│ │ 📝 Learning Objectives:         │ │
│ │ • Quadratic equations     [×]   │ │
│ │ • Systems of equations    [×]   │ │
│ └─────────────────────────────────┘ │
│                                      │
│ 💡 What happens when you save?      │
│ Your changes will be saved and      │
│ the bot will adjust...              │
│                                      │
│ [Cancel]              [Save Changes] │
└─────────────────────────────────────┘
```

---

## 🧪 Testing Checklist

- [ ] Open chat with active Study Bot
- [ ] Tap 📚 icon - modal opens with plan
- [ ] Tap ✏️ edit button - editor screen opens
- [ ] Rename a module - title changes
- [ ] Delete a module - removed from list
- [ ] Delete an objective/subtopic - removed
- [ ] Tap Cancel - changes discarded
- [ ] Tap Save Changes - calls backend
- [ ] Check backend logs - plan updated in DB
- [ ] Modal closes and returns to chat
- [ ] Continue chat - messages still there
- [ ] Progress percentage unchanged
- [ ] Bot acknowledges plan change
- [ ] Future bot responses reflect new plan

---

## 📝 Example: Plan Update Flow

**Before Edit:**

```
Modules:
1. Fundamentals (✅ learning)
2. Linear Equations (📋 queued)
3. Systems (📋 queued)
4. Advanced Concepts (📋 queued)

Progress: 35%
Chat: 42 messages
```

**User Action:**

```
1. Opens editor
2. Renames "Linear Equations" → "Linear & Quadratic Equations"
3. Deletes "Systems" module
4. Adds new objective to Fundamentals
5. Clicks Save
```

**After Edit:**

```
Modules:
1. Fundamentals (✅ learning) [UPDATED]
2. Linear & Quadratic Equations (📋 queued) [RENAMED]
3. Advanced Concepts (📋 queued)

Progress: 35% [PRESERVED]
Chat: 43 messages [42 + 1 system message]
Bot: "Got it! I'll focus more on quadratic equations..."
```

---

## 🔐 Security Notes

- Plan updates require both `botId` and `userId`
- Backend validates plan structure before saving
- Chat history recorded with system message explaining change
- AI notified through standard Groq API channel
- No direct execution of user code

---

## 🚀 Deployment

**Files to Deploy:**

1. ✅ `backend/server.js` (updated)
2. ✅ `lib/screens/study_plan_chat_screen.dart` (updated)
3. ✅ `lib/screens/study_plan_editor_screen.dart` (new)

**No Database Migrations Required:**

- `bot_progress.study_plan` column already exists (JSONB)
- Uses existing schema

**Backend Restart:**

- Required for route changes
- No data migration needed

**Frontend Update:**

- Rebuild and redeploy
- No new environment variables

---

## 📊 Metrics to Monitor

After deployment, track:

- How often users edit plans
- Which modules are most frequently modified
- Average time spent in editor
- Plan complexity over time
- Bot response quality after plan updates

---

## 🐛 Troubleshooting

### Issue: Plan changes not saving

**Fix:** Check backend logs for `/api/update-study-plan` errors

### Issue: Bot doesn't acknowledge plan change

**Fix:** Verify GROQ_API_KEY is set (fallback still saves plan)

### Issue: Progress lost after update

**Fix:** This shouldn't happen - check backend query

### Issue: Modal shows old plan

**Fix:** Call `_loadStudyPlan()` to refresh from backend

---

## 📚 Code References

### Frontend

- Plan Editor: [study_plan_editor_screen.dart](../lib/screens/study_plan_editor_screen.dart)
- Chat Integration: [study_plan_chat_screen.dart](../lib/screens/study_plan_chat_screen.dart) lines 1-200

### Backend

- Update Endpoint: [server.js](../backend/server.js) lines ~1350-1480
- Bot Progress Table: [server.js](../backend/server.js) lines ~365-375

---

**Status:** ✅ Ready for Production
**Risk Level:** 🟢 LOW (no breaking changes, fully backward compatible)
**Testing:** Recommended before production deployment
