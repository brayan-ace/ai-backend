# Phase 2: Testing & Verification Guide

## Pre-Testing Checklist

- [ ] App compiles without errors
- [ ] All new files created successfully
- [ ] No import errors
- [ ] Study Bot from Phase 1 available
- [ ] Device/emulator ready

## Manual Testing Scenarios

### Test 1: Basic Flow - Happy Path

**Objective:** Verify complete flow from Phase 1 to Phase 2 completion

**Steps:**

1. Launch app
2. Go to Study Plans → Create Study Bot (Phase 1)
   - Plan Name: "Physics 101"
   - Description: "Learn basic physics concepts"
   - Bot Name: "Professor Newton"
   - Education Level: "High School"
3. Click "Confirm" to create bot
4. Verify confirmation screen shows all details
5. Click "What's Next?" button
6. **EXPECT:** Phase 2 chat screen loads with INTRO state
7. Chat should show: "Hi! I'm Professor Newton..."
8. Type: "yes"
9. **EXPECT:** State transitions to PLAN_PROPOSAL, TOC generated
10. Bot shows TOC with 9 modules (High School = 9)
11. Type: "approve"
12. **EXPECT:** State transitions to PLAN_APPROVED
13. Bot says: "Excellent! We're ready..."
14. Type: "start"
15. **EXPECT:** State transitions to LESSON_ACTIVE
16. Bot shows ready-for-lessons message
17. **RESULT:** ✅ PASS if all transitions smooth and correct

**Failure Points:**

- ❌ "What's Next?" doesn't navigate
- ❌ Chat screen shows loading spinner indefinitely
- ❌ Bot message doesn't appear
- ❌ State doesn't change after user input
- ❌ TOC not generated or doesn't display

---

### Test 2: Plan Modification Flow

**Objective:** Verify TOC modification and regeneration

**Steps:**

1. Complete Test 1 up to PLAN_PROPOSAL state
2. Bot shows TOC with 9 modules
3. Type: "modify"
4. **EXPECT:** State transitions to PLAN_MODIFICATION
5. Bot asks: "What would you like to adjust?"
6. Type: "I want to go slower"
7. **EXPECT:** Bot regenerates TOC
8. **EXPECT:** State returns to PLAN_PROPOSAL
9. Bot shows: "Based on your feedback, I've adjusted..."
10. Verify modules are still 9 but descriptions may differ
11. Type: "approve"
12. **EXPECT:** State transitions to PLAN_APPROVED
13. **RESULT:** ✅ PASS if modification cycle completes

**Failure Points:**

- ❌ State doesn't go to PLAN_MODIFICATION
- ❌ TOC not regenerated
- ❌ State doesn't return to PLAN_PROPOSAL
- ❌ Can't approve after modification

---

### Test 3: Table of Contents Display

**Objective:** Verify TOC rendering and formatting

**Expected TOC Structure (9 modules, High School):**

```
✓ Module 1: Foundations of Topic (beginner, 30 min)
✓ Module 2: Core Concepts (beginner, 30 min)
✓ Module 3: Developing Understanding (intermediate, 45 min)
✓ Module 4: Intermediate Applications (intermediate, 45 min)
✓ Module 5: Advanced Topics (intermediate, 45 min)
✓ Module 6: Synthesis and Connection (intermediate, 45 min)
✓ Module 7: Practical Application (advanced, 60 min)
✓ Module 8: Critical Analysis (advanced, 60 min)
✓ Module 9: Integration and Mastery (advanced, 60 min)
```

**Steps:**

1. Get to PLAN_PROPOSAL state
2. Look for modules displayed in chat
3. Count modules: should be 9
4. Verify each has:
   - Module number (1-9)
   - Title (descriptive)
   - Estimated time
   - Difficulty level
5. Verify progression: beginner → intermediate → advanced
6. **RESULT:** ✅ PASS if all modules display correctly

**Failure Points:**

- ❌ Wrong number of modules
- ❌ Missing module information
- ❌ Incorrect difficulty progression
- ❌ Time estimates not showing
- ❌ Formatting issues/unreadable

---

### Test 4: Session Persistence

**Objective:** Verify session state saves and resumes correctly

**Steps:**

1. Complete Test 1 up to PLAN_APPROVED state
2. Close the app completely (kill process)
3. **Verify:** SharedPreferences saved data
   - Use DevTools or device file explorer
   - Check: `shared_preferences.xml`
   - Should contain `myai_bot_states_v1`
4. Reopen app
5. Navigate back to Study Bots → select the bot from Test 1
6. Click "What's Next?" again
7. **EXPECT:** Chat screen loads with previous conversation
8. Messages should show:
   - Bot greeting
   - User: "yes"
   - Bot: TOC message
   - User: "approve"
   - Bot: PLAN_APPROVED message
9. Current state should be PLAN_APPROVED
10. User should be able to type new messages
11. **RESULT:** ✅ PASS if session fully resumed

**Failure Points:**

- ❌ SharedPreferences not saved
- ❌ Chat history lost
- ❌ State doesn't resume
- ❌ Messages missing
- ❌ Can't continue from where left off

---

### Test 5: Different Education Levels

**Objective:** Verify TOC generation for different levels

**Test 5a: Primary/Elementary (6 modules)**

- Create bot with level: "Primary"
- Get to PLAN_PROPOSAL
- Count modules: should be 6
- **EXPECT:** Mostly beginner difficulty
- ✅ PASS if 6 modules, beginner-heavy

**Test 5b: Secondary/Middle (8 modules)**

- Create bot with level: "Secondary"
- Get to PLAN_PROPOSAL
- Count modules: should be 8
- **EXPECT:** Mix of beginner and intermediate
- ✅ PASS if 8 modules, balanced difficulty

**Test 5c: University/College (10 modules)**

- Create bot with level: "University"
- Get to PLAN_PROPOSAL
- Count modules: should be 10
- **EXPECT:** Full spectrum beginner to advanced
- ✅ PASS if 10 modules, full progression

**Test 5d: Advanced/Professional (12 modules)**

- Create bot with level: "Advanced"
- Get to PLAN_PROPOSAL
- Count modules: should be 12
- **EXPECT:** Heavy on advanced difficulty
- ✅ PASS if 12 modules, advanced-heavy

---

### Test 6: Invalid Transitions Prevention

**Objective:** Verify state machine blocks invalid transitions

**Test 6a: Can't skip states**

1. Create bot, get to INTRO state
2. Type: "start module 1" (trying to skip)
3. **EXPECT:** Bot asks to approve plan first
4. **EXPECT:** State stays at INTRO
5. ✅ PASS if skipping prevented

**Test 6b: Can't go backward**

1. Get to PLAN_APPROVED state
2. Somehow attempt to go back to INTRO
3. **EXPECT:** System prevents transition
4. **EXPECT:** Error logged or transition ignored
5. ✅ PASS if prevented

---

### Test 7: Chat Message Display & Formatting

**Objective:** Verify messages display correctly

**Steps:**

1. Complete Test 1 to LESSON_ACTIVE state
2. Verify chat display:
   - Bot messages appear on LEFT with bot avatar (blue circle)
   - User messages appear on RIGHT with blue background
   - Messages have timestamps
   - Text wraps properly on small screens
3. Scroll through message history
4. Type new message: "This is a test message"
5. Verify message appears immediately
6. Verify message goes to right side, blue background
7. Wait for bot response
8. Verify response appears on left with bot avatar
9. **RESULT:** ✅ PASS if all formatting correct

**Failure Points:**

- ❌ Messages on wrong side
- ❌ Missing avatars/indicators
- ❌ Text not wrapping
- ❌ No timestamps
- ❌ Messages don't scroll

---

### Test 8: Input Field & Send Button

**Objective:** Verify message input works correctly

**Steps:**

1. Get to any chat state
2. Tap input field
3. **EXPECT:** Keyboard appears
4. Type: "Hello"
5. Tap send button (circle with arrow)
6. **EXPECT:** Message sends immediately
7. Input field clears
8. **EXPECT:** Loading spinner shows briefly
9. **EXPECT:** Bot response appears
10. Repeat with different messages
11. **RESULT:** ✅ PASS if input works smoothly

**Failure Points:**

- ❌ Input field not responsive
- ❌ Keyboard doesn't appear
- ❌ Send button disabled incorrectly
- ❌ Messages don't send
- ❌ Input field doesn't clear

---

### Test 9: Table of Contents Toggle Button

**Objective:** Verify TOC panel can be shown/hidden

**Steps:**

1. Get to PLAN_PROPOSAL state (TOC generated)
2. Look for book/menu icon in app bar (top right)
3. Tap TOC icon
4. **EXPECT:** TOC panel slides in showing modules
5. Verify all 9 modules visible
6. Scroll through TOC if needed
7. Tap TOC icon again
8. **EXPECT:** TOC panel slides out/closes
9. Chat area expands
10. Repeat toggle 3-4 times
11. **RESULT:** ✅ PASS if toggle works smoothly

**Failure Points:**

- ❌ Icon doesn't appear
- ❌ Panel doesn't slide
- ❌ Modules not visible in TOC
- ❌ Can't close TOC
- ❌ Animation stutters

---

### Test 10: Multiple Sessions

**Objective:** Verify app handles multiple Study Bots/sessions

**Steps:**

1. Create Bot 1: "Physics 101" (High School = 9 modules)
2. Get to PLAN_APPROVED state
3. Close chat, go back to Study Bots list
4. Create Bot 2: "Biology 101" (University = 10 modules)
5. Get to PLAN_PROPOSAL state
6. Close chat, go back to Study Bots list
7. Click on Bot 1 → "What's Next?"
8. **EXPECT:** Loads Bot 1's PLAN_APPROVED state (9 modules)
9. Go back, click on Bot 2 → "What's Next?"
10. **EXPECT:** Loads Bot 2's PLAN_PROPOSAL state (10 modules)
11. Verify each session maintains its own:
    - State
    - TOC
    - Chat history
    - Modifications
12. **RESULT:** ✅ PASS if sessions fully isolated

**Failure Points:**

- ❌ Bot 1 data mixes with Bot 2
- ❌ Sessions not independent
- ❌ Wrong TOC loaded
- ❌ Chat history from wrong bot

---

## Automated Testing (Future)

### Unit Tests to Add

```dart
// test/models/study_bot_state_test.dart
test('StudyBotState serialization roundtrip') { ... }
test('TableOfContentsItem with all fields') { ... }
test('StudyBotMessage JSON conversion') { ... }

// test/services/study_bot_flow_controller_test.dart
test('createNewSession initializes INTRO state') { ... }
test('generateTableOfContents respects education level') { ... }
test('canTransitionTo validates all transitions') { ... }
test('transitionTo updates timestamp') { ... }
test('getBotResponseForState returns appropriate text') { ... }

// test/services/study_plan_service_test.dart
test('saveBotState persists to SharedPreferences') { ... }
test('getBotState retrieves saved state') { ... }
test('getBotStatesByBotId returns correct sessions') { ... }

// test/screens/study_plan_chat_screen_test.dart
test('Phase 2 loads existing session') { ... }
test('Phase 2 creates new session if none exists') { ... }
test('Messages are added to chat history') { ... }
test('User messages trigger bot responses') { ... }
test('TOC displays when toggled') { ... }
```

---

## Performance Testing

### Metrics to Verify

- [ ] TOC generation < 100ms
- [ ] State transition < 50ms
- [ ] Message persistence < 200ms
- [ ] Chat screen loads < 500ms
- [ ] No memory leaks after 50+ messages
- [ ] App doesn't crash with 100+ messages

### How to Test

1. Open DevTools → Performance tab
2. Start recording
3. Complete full Phase 2 flow
4. Stop recording
5. Verify metrics are within acceptable ranges

---

## Edge Cases to Test

### Edge Case 1: Empty Input

- Type nothing and press send
- **EXPECT:** Nothing happens or warning shown
- ✅ PASS if handled gracefully

### Edge Case 2: Very Long Message

- Type 500+ character message
- **EXPECT:** Message displays properly, wraps correctly
- ✅ PASS if no layout issues

### Edge Case 3: Special Characters

- Type: "Test: @#$%^&\*()\_+-={}[]|:;<>,.?/"
- **EXPECT:** Displays correctly without errors
- ✅ PASS if no crashes

### Edge Case 4: Network Simulation

- Turn off wifi/data
- Attempt to save state
- **EXPECT:** Graceful error handling or offline queueing
- ✅ PASS if app doesn't crash

### Edge Case 5: Rapid State Changes

- Quickly send multiple messages
- **EXPECT:** States queue properly, no skipped transitions
- ✅ PASS if all transitions processed

### Edge Case 6: App Backgrounding

- Enter chat
- Send message to trigger state transition
- Background app immediately
- Foreground app
- **EXPECT:** State saved, can resume
- ✅ PASS if no data loss

---

## Debugging Tools

### Enable Debug Logging

Add to screen:

```dart
debugPrint('State: ${_botState?.currentState}');
debugPrint('Messages: ${_messages.length}');
debugPrint('TOC: ${_botState?.tableOfContents?.length} modules');
```

### Check SharedPreferences

```dart
// Add temporary debug button
ElevatedButton(
  onPressed: () async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('myai_bot_states_v1');
    debugPrint('SharedPrefs data: $data');
  },
  child: Text('Debug: Print SharedPrefs'),
),
```

### Use Flutter DevTools

1. Run: `flutter run`
2. Press 'd' to open DevTools
3. Go to Performance tab
4. Record interactions
5. Analyze frame times

---

## Test Results Template

```
Phase 2 Testing Results
========================

Date: ___________
Tester: ___________
Device: ___________
OS Version: ___________

Test Results:
[ ] Test 1: Basic Flow - PASS/FAIL
[ ] Test 2: Plan Modification - PASS/FAIL
[ ] Test 3: TOC Display - PASS/FAIL
[ ] Test 4: Session Persistence - PASS/FAIL
[ ] Test 5: Education Levels - PASS/FAIL
[ ] Test 6: Invalid Transitions - PASS/FAIL
[ ] Test 7: Message Display - PASS/FAIL
[ ] Test 8: Input Field - PASS/FAIL
[ ] Test 9: TOC Toggle - PASS/FAIL
[ ] Test 10: Multiple Sessions - PASS/FAIL

Total: __ PASS, __ FAIL

Issues Found:
1. [Describe issue]
2. [Describe issue]

Regression Testing:
[ ] Phase 1 still works
[ ] Legacy study plans still work
[ ] No crashes observed
[ ] No memory leaks detected

Overall Result: APPROVED / NEEDS WORK
```

---

## Sign-Off Checklist

- [ ] All 10 manual tests passing
- [ ] No compilation errors
- [ ] No runtime errors
- [ ] Session persistence working
- [ ] State machine logic correct
- [ ] TOC generation correct
- [ ] Message persistence working
- [ ] Multiple sessions independent
- [ ] No memory leaks
- [ ] Performance acceptable
- [ ] Ready for Phase 3

**Testing completed by:** ****\_\_\_****
**Date:** ****\_\_\_****
**Status:** ✅ READY FOR PHASE 3
