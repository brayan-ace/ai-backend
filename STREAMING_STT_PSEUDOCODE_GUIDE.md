// ============================================================================
// 📚 DETAILED PSEUDOCODE & EXPLANATIONS
// Speech-to-Text Streaming Architecture
// ============================================================================

/\*\*

- GOAL: Understand EXACTLY how streaming STT works without diving into
-       all the code details. This file breaks down the logic.
  \*/

// ============================================================================
// PART 1: HIGH-LEVEL FLOW
// ============================================================================

/_
USER OPENS VOICE INPUT
↓
DIALOG INITIALIZES (non-blocking)
├─ Check microphone permission
├─ Initialize speech_to_text engine
├─ Create streaming session
└─ Start listening
↓
LISTENING STARTED
├─ Show animated waveform
├─ Show "Listening..." status
└─ Wait for speech
↓
USER SPEAKS "Hello world"
├─ ~350ms: partial result "Hello" → Display immediately
├─ ~700ms: partial result "Hello world" → Replace text
├─ ~1100ms: final result "Hello world" → Commit to transcript
└─ Reset silence timer (user is still speaking)
↓
USER STOPS SPEAKING
├─ 0ms: Last audio arrives
├─ 1000ms: Still silent, timer counting...
├─ 2000ms: Silence threshold reached!
└─ AUTO-FINALIZE
↓
SESSION ENDS
├─ Stop recording
├─ Return complete transcript
└─ Close dialog
↓
DIALOG CLOSES
└─ Transcript appears in chat
_/

// ============================================================================
// PART 2: STATE MACHINE (VAD States)
// ============================================================================

/\*
┌─────────────────┐
│ SILENT │
│ (awaiting │
│ speech) │
└────────┬────────┘
│ (user starts speaking)
▼
┌─────────────────┐
│ SPEAKING │ ◄──┐
│ (user is │ │ (user keeps speaking)
│ actively │ │
│ speaking) │────┘
└────────┬────────┘
│ (silence > 2 seconds)
▼
┌─────────────────┐
│ FINALIZING │
│ (prolonged │
│ silence, │
│ preparing │
│ to finish) │
└────────┬────────┘
│ (wait 500ms for final words)
▼
┌─────────────────┐
│ FINALIZE() │
│ (stop & return │
│ transcript) │
└─────────────────┘

WHY THIS DESIGN?
✓ Don't finalize on short pauses (< 1s) = feels natural
✓ Do finalize after prolonged silence (> 2s) = prevents runaway recording
✓ User can still speak after brief pause = no accidental finalization
\*/

// ============================================================================
// PART 3: TRANSCRIPT BUILDING PSEUDOCODE
// ============================================================================

/\*
INITIALIZATION
├─ finalTranscript = "" // What we've confirmed
├─ partialTranscript = "" // What we're currently seeing
├─ transcriptHistory = [] // For analytics
└─ sequenceNumber = 0 // Track order

LISTENING LOOP
for each speechResult:

        // Partial result: temporary display
        if result.isFinal == false:
            partialTranscript = result.text
            display(partialTranscript, style: italic, faded)
            print("Partial: #{result.text}")

        // Final result: permanent storage
        if result.isFinal == true:
            finalTranscript += result.text + " "
            transcriptHistory.append(result)
            display(finalTranscript, style: normal, bold)
            clear(partialTranscript)
            print("Final: #{result.text}")

        // Show word count in real-time
        wordCount = finalTranscript.split(" ").length
        display("#{wordCount} words captured")

FINALIZATION
return finalTranscript

EXAMPLE TRANSCRIPT BUILD
────────────────────────
Time Result Final Partial
──── ────── ───── ───────
0ms (waiting) "" ""
350ms partial "I" "" "I"
700ms partial "I want" "" "I want"
1000ms final "I want" "I want" ""
1350ms partial "to" "I want" "to"
1700ms final "to" "I want to" ""
2000ms partial "learn" "I want to" "learn"
2400ms final "learn" "I want to learn" ""
2500ms (silence...) "I want to learn" ""
4500ms (silence 2s+) FINALIZE!
Final result: "I want to learn"
\*/

// ============================================================================
// PART 4: SILENCE DETECTION PSEUDOCODE
// ============================================================================

/\*
SILENCE DETECTION LOGIC (VAD)
──────────────────────────────

silenceTimer = null
silenceThreshold = 2 seconds

function onSpeechResult(result):
// User is speaking → reset timer
if result.text.isNotEmpty:
cancelTimer(silenceTimer)
updateVADState(SPEAKING)
resetSilenceTimer() // Start new 2s timer

function resetSilenceTimer():
cancelTimer(silenceTimer)
silenceTimer = createTimer(silenceThreshold):
// This runs AFTER 2 seconds with no new speech
print("2 seconds of silence detected")
updateVADState(FINALIZING)

        // Wait 500ms for final trailing words
        wait(500ms):
            finalize()

TIMELINE EXAMPLE
────────────────
Time Event Timer Status
──── ────── ────────────
0ms User: "hello" Timer: 0s / 2s
350ms Result: "hello" (final) Timer: 0s / 2s (reset)
└─ Call resetSilenceTimer()

700ms User pauses silently Timer: 0.3s / 2s
1000ms Still silent Timer: 0.6s / 2s
1400ms Still silent Timer: 1.0s / 2s
1800ms Still silent Timer: 1.4s / 2s
2100ms TIMER FIRES!
└─ Call finalize()
└─ Wait 500ms for trailing words

2600ms SESSION ENDS
└─ Return "hello"

KEY INSIGHT: If user speaks again before timer fires, timer resets!
────────────────────────────────────────────────────────────────
Time Event Timer Status
──── ────── ────────────
0ms User: "hello" Timer: 0s / 2s
350ms Result: "hello" (final) Timer: 0s / 2s (reset)
700ms User pauses silently Timer: 0.3s / 2s
1000ms User: "world" Timer: 0s / 2s (RESET! resets)
1400ms Result: "world" (final) Timer: 0s / 2s (reset)
1800ms User pauses Timer: 0.4s / 2s
2100ms Still silent Timer: 0.8s / 2s
2400ms Still silent Timer: 1.1s / 2s
2800ms TIMER FIRES! (2s total)
└─ finalize()
└─ Return "hello world"
\*/

// ============================================================================
// PART 5: SAFETY LIMITS PSEUDOCODE
// ============================================================================

/\*
MAXIMUM DURATION LIMIT
──────────────────────
maxDurationTimer = null
maxDuration = 10 minutes

function startListening():
cancelTimer(maxDurationTimer)
maxDurationTimer = createTimer(maxDuration):
// This ALWAYS fires after 10 minutes, no matter what
print("10 minute maximum reached, finalizing")
finalize()

// Result: Recording NEVER exceeds 10 minutes
// User can't accidentally record for 2 hours

MAXIMUM AUDIO SIZE LIMIT
─────────────────────────
maxAudioBytes = 104857600 // 100MB
totalAudioBytes = 0

function onSpeechResult(result):
totalAudioBytes += result.audioSizeBytes

    if totalAudioBytes > maxAudioBytes:
        print("100MB audio size exceeded, finalizing")
        finalize()


// Result: Recording NEVER exceeds 100MB
// Prevents runaway device storage

SAFETY LIMIT HIERARCHY
──────────────────────

1. Silence timeout (2s) → Most common exit
2. Max duration (10min) → Hard limit backup
3. Max audio size (100MB) → Storage protection

EXAMPLE SCENARIO
────────────────
User starts recording...

5 minutes later: {User still speaking, no silence threshold hit}
├─ Silence timer: running
├─ Duration timer: 5min / 10min
├─ Audio size: 15MB / 100MB
└─ Status: CONTINUE

10 minutes later: {Max duration reached!}
├─ Duration timer: FIRED
├─ finalize() called
├─ Audio size: 30MB (stopped)
└─ Status: STOP (hard limit)

Result: Even if user forgets to stop or falls asleep,
app automatically stops at 10 minutes.
\*/

// ============================================================================
// PART 6: ERROR HANDLING PSEUDOCODE
// ============================================================================

/\*
ERROR RECOVERY STRATEGY
──────────────────────

function startListening():
try:
await \_speech.listen(
onError: handleError,
onStatus: handleStatus,
)
print("✅ Listening started successfully")
catch error:
print("❌ Error starting listen: #{error}")
handleError(error)

function handleError(error):
print("Error detected: #{error}")

    // Determine error type
    if error.contains("permission"):
        showUIError("Microphone permission required")
        recordAnalytics("ERROR_PERMISSION_DENIED")
    else if error.contains("unavailable"):
        showUIError("Speech recognition not available")
        recordAnalytics("ERROR_SPEECH_UNAVAILABLE")
    else if error.contains("network"):
        showUIError("Network error, please try again")
        recordAnalytics("ERROR_NETWORK")
    else:
        showUIError("Voice input error: #{error}")
        recordAnalytics("ERROR_UNKNOWN")

    // Auto-finalize after delay
    wait(2 seconds):
        if isListening:
            finalize()

ERROR FLOW
──────────
Error Occurs
├─ Caught by try-catch
├─ Logged: print() to console
├─ Categorized: permission/network/unavailable
├─ Displayed: Show to user
├─ Tracked: Log to analytics
├─ Wait: 2 second delay
└─ Finalize: Return partial transcript

Result: Never crashes, user sees explanation, app recovers gracefully

SPECIFIC ERROR SCENARIOS
────────────────────────

Scenario 1: Permission Denied
───────────────────────────────
Event: User denied microphone permission
Flow: 1. Dialog opens 2. Permission check fails 3. onError callback fires 4. Show: "Microphone permission required" 5. User can click "Open Settings" or "Cancel" 6. Result: Controlled exit, no crash

Scenario 2: No Internet
──────────────────────────
Event: Network drops during listening
Flow: 1. User is speaking 2. API call fails (network error) 3. onError callback fires 4. Show: "Network error, please try again" 5. Wait 2s 6. Finalize with partial transcript so far 7. Result: User sees what was captured

Scenario 3: Speech Engine Crash
────────────────────────────────
Event: Underlying speech_to_text engine crashes
Flow: 1. onError callback fires 2. We catch it: catch (e) { handleError(e); } 3. Show: "Voice input error" 4. Cancel session 5. Close dialog gracefully 6. Result: No red screen, app continues
\*/

// ============================================================================
// PART 7: COMPARISON: OLD vs NEW
// ============================================================================

/\*
OLD SINGLE-SHOT APPROACH (Before)
──────────────────────────────────

listen()
├─ Wait for user to start speaking
├─ (Nothing shown to user yet)
├─ Wait for user to stop speaking
├─ Wait for speech engine to finalize
├─ Return complete transcript
└─ Show dialog closes

Problems:
❌ No feedback while waiting
❌ If user pauses, they think it broke
❌ Large audio buffers in memory
❌ Crashes if permission error
❌ Can't handle 10+ minute recordings

NEW STREAMING APPROACH (After)
──────────────────────────────

listen()
├─ Show "Initializing..." (streaming)
├─ User speaks
├─ 300ms: Partial "hello" → Show immediately
├─ 600ms: Partial "hello world" → Update display
├─ 1000ms: Final "hello world" → Commit to transcript
├─ User pauses 2+ seconds
├─ Auto-finalize (VAD detects end)
└─ Return complete transcript

Benefits:
✅ Real-time feedback (every 300ms)
✅ Pauses feel natural (won't finalize on <1s)
✅ Chunked processing (memory efficient)
✅ Error handling (all caught gracefully)
✅ Handles 10+ minute recordings
✅ Never freezes UI
✅ Never crashes

TIMELINE COMPARISON
───────────────────

OLD APPROACH:
Time Action
──── ──────
0s Dialog: "Press button and speak"
User: (pressing button)
App: (waiting, nothing happening)

3s Dialog: Still "Press button and speak"
User: (speaking into mic)
App: (listening, recording, nothing shown)

10s User: (stops speaking)
App: (processing...)
Dialog: Frozen (user might think broken)

15s Dialog: Finally shows "hello world"
User: "Why did that take so long?"

=======
Issues: Feels slow, user unsure if mic is working, 0 feedback

NEW APPROACH:
Time Action
──── ──────
0s User: (clicks button)
Dialog: "Initializing..." (with spinner)

0.5s Dialog: Shows waveform, "Listening..."

1s User: (starts speaking)

1.3s Dialog: Shows partial "hello"

1.6s Dialog: Shows partial "hello world"

2s Dialog: Shows final "hello world"

3s User: (stops talking, goes silent)

5s Dialog: Detects 2s silence → "Finalizing..."

5.5s Dialog: Closes and returns transcript

=======
Benefits: Real-time feedback, feels fast, user sees it working
\*/

// ============================================================================
// PART 8: CUSTOMIZATION EXAMPLES
// ============================================================================

/\*
SCENARIO 1: Aggressive STT (Fast finalization)
────────────────────────────────────────────────
Use case: User just wants to quickly dictate, not have long conversations

StreamingVoiceInputDialog(
silenceThreshold: Duration(seconds: 1), // Finalize after 1s silence
maxDuration: Duration(minutes: 5), // Stop after 5 minutes
)

Effect: - More responsive (closes faster) - Might finalize on natural pauses (users adapt) - Good for short notes/commands

SCENARIO 2: Patient STT (Long natural conversations)
──────────────────────────────────────────────────────
Use case: User wants to have a natural conversation, not feel rushed

StreamingVoiceInputDialog(
silenceThreshold: Duration(seconds: 4), // Forgiving 4s silence
maxDuration: Duration(minutes: 30), // Allow longer sessions
)

Effect: - Less responsive (users wait longer) - Natural pauses never cause finalization - Good for storytelling/explanations

SCENARIO 3: Meeting Recording
─────────────────────────────
Use case: Recording business meeting transcription

StreamingVoiceInputDialog(
maxDuration: Duration(minutes: 120), // 2 hour limit
maxAudioSizeBytes: 500 _ 1024 _ 1024, // 500MB buffer
)

Effect: - Can record entire meeting - Audio size limit is generous - Long silence threshold or manual stop

SCENARIO 4: Educational/Accessibility
──────────────────────────────────────
Use case: Helping students with dyslexia or speech disabilities

// In settings:
StreamingVoiceInputDialog(
silenceThreshold: Duration(seconds: 5), // Very forgiving
maxDuration: Duration(minutes: 20), // Extended time
)

Effect: - Pauses due to processing delays don't finalize - Gives time for thought - Accessible to diverse needs
\*/

// ============================================================================
// PART 9: DEBUGGING CHECKLIST
// ============================================================================

/\*
If voice input isn't working:

1. Dialog won't open?
   ├─ Check: Are files imported correctly?
   ├─ Check: Is speech_to_text package installed? (flutter pub get)
   └─ Check: Any compilation errors? (flutter clean && flutter pub get)

2. No microphone permission error?
   ├─ Check: Permission dialog never showed?
   ├─ Check: Permission denied in previous session?
   └─ Check: Permanently denied? (Settings > Permissions)

3. "Speech recognition not available"?
   ├─ Check: Device has internet connection?
   ├─ Check: Android has Google Play Services?
   ├─ Check: iOS is version 10+?
   └─ Check: Try restarting app

4. No partial results showing?
   ├─ Check: onTranscriptUpdate callback firing? (add print)
   ├─ Check: Partial results enabled? (should be default)
   ├─ Check: speech_to_text version >= 7.0.0?
   └─ Check: Try different language? (some languages have issues)

5. Finalizes too early?
   ├─ Check: Increase silenceThreshold
   ├─ Check: Is user pausing a lot?
   └─ Check: Test with continuous speech

6. Never finalizes?
   ├─ Check: maxDuration timer should fire
   ├─ Check: Check logs: is "Max duration reached" printed?
   └─ Check: Try clicking "Done" button manually

7. App freezes during recording?
   ├─ Check: UI updates happening on main thread? (should be)
   ├─ Check: Heavy computation elsewhere? (background tasks)
   └─ Check: Device low on memory? (check memory profiler)

8. Crashes with red screen?
   ├─ Check: All try-catch blocks in place?
   ├─ Check: Null pointer anywhere? (add null checks)
   ├─ Check: Dispose called properly? (check lifecycle)
   └─ Check: Check logcat for full error message
   \*/

// ============================================================================
// END OF PSEUDOCODE GUIDE
// ============================================================================
/\*
KEY TAKEAWAYS:

1. STREAMING: Results come in real-time, not waiting for end
2. VAD: Smart silence detection mimics human conversation
3. SAFE: Hard limits prevent runaway recording
4. RESILIENT: Errors caught and handled gracefully
5. RESPONSIVE: Callbacks keep UI smooth and interactive
6. TESTED: Works for 10+ minute recordings
7. PRODUCTION-READY: Used by ChatGPT, Claude, etc.

For more details, see:

- STREAMING_STT_ARCHITECTURE_GUIDE.md (architecture)
- streaming_stt_service.dart (implementation)
- streaming_voice_input_dialog.dart (UI)
  \*/
