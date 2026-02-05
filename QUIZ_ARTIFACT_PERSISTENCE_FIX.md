# Quiz Artifact Persistence Fix

## Problem

Quiz artifacts were disappearing when the app was relaunched because:

- Quiz data was only stored in memory (`_artifacts` map)
- While artifact messages were saved to Firebase, the quiz data inside them wasn't
- On app restart, messages were loaded but without the quiz data
- The `_artifacts` map couldn't be reconstructed

## Solution Implemented

### 1. Enhanced Message Metadata Storage

**File**: `lib/services/study_bot_storage_service.dart`

Updated `saveMessage()` method to:

- Accept optional `senderType` parameter
- Allow artifact messages to be saved with custom sender type
- Store all metadata (including artifact data) in Firebase

```dart
Future<void> saveMessage({
  required String botId,
  required String text,
  required bool fromUser,
  Map<String, dynamic>? metadata,
  String? senderType,  // ← NEW: Support artifact type
}) async {
  // Now saves with senderType: 'artifact' if provided
}
```

### 2. Store Artifact Data with Message

**File**: `lib/screens/study_plan_chat_screen.dart` - `_showQuizArtifact()` method

When creating an artifact:

- Store artifact data in message metadata: `metadata['artifactData']`
- Save the message to Firebase with all metadata
- Includes quiz questions, answers, and configuration

```dart
final artifactMessage = StudyBotMessage(
  metadata: {
    'type': 'quiz',
    'artifactId': artifactId,
    'artifactData': quiz,  // ← NEW: Store quiz data
  },
);

// Save to Firebase
await _storageService.saveMessage(
  metadata: artifactMessage.metadata,
  senderType: 'artifact',
);
```

### 3. Restore Artifacts on App Launch

**File**: `lib/screens/study_plan_chat_screen.dart` - Init method

When loading messages from Firebase or backend:

**Firebase Loading**:

```dart
// Reconstruct artifacts from saved messages
for (final msg in messages) {
  if (msg.senderType == 'artifact' && msg.metadata != null) {
    final artifactId = msg.metadata!['artifactId'];
    final artifactData = msg.metadata!['artifactData'];
    if (artifactId != null && artifactData != null) {
      _artifacts[artifactId] = artifactData;  // ← Reconstruct
      print('[ChatScreen] 📦 Restored artifact: $artifactId');
    }
  }
}
```

**Backend Fallback Loading**:

```dart
// Same reconstruction logic for backend history
```

## Data Flow

### Creating Quiz (First Time)

```
User takes quiz
    ↓
_showQuizPopup() generates quiz data
    ↓
_showQuizArtifact() stores:
  - In memory: _artifacts[artifactId]
  - In message: StudyBotMessage with metadata
    ↓
Save to Firebase:
  - Message text, sender type
  - metadata['artifactData'] = full quiz object
    ↓
User closes app
```

### Reopening App (Quiz Still Available)

```
App starts
    ↓
Load messages from Firebase
    ↓
Parse each message:
  - If senderType == 'artifact'
  - Extract artifactData from metadata
  - Reconstruct: _artifacts[artifactId] = artifactData
    ↓
User sees quiz card in chat history
    ↓
User taps quiz → _artifacts contains quiz data
    ↓
Quiz opens with all original data intact
```

## What Gets Persisted

✅ **Quiz Questions** - All questions saved
✅ **Quiz Answers** - User responses preserved
✅ **Quiz Options** - Multiple choice options stored
✅ **Quiz Metadata** - Quiz ID, type, timestamp
✅ **User Progress** - Answers and selections
✅ **Artifact Reference** - Link in chat messages

## Storage Structure

Firebase message with artifact:

```json
{
  "text": "Quiz Artifact",
  "senderType": "artifact",
  "fromUser": false,
  "timestamp": "2026-02-01T...",
  "metadata": {
    "type": "quiz",
    "artifactId": "quiz_1738419600000",
    "artifactData": {
      "id": "quiz_123",
      "title": "Chapter 5 Quiz",
      "questions": [...],
      "answers": [...],
      "timeLimit": 300,
      "difficulty": "medium"
    }
  }
}
```

## Files Modified

1. **lib/screens/study_plan_chat_screen.dart**
   - Updated Firebase message loading to include metadata and reconstruct artifacts
   - Updated backend history loading with artifact reconstruction
   - Enhanced `_showQuizArtifact()` to save artifact data to Firebase
   - Added artifact restoration logic on app startup

2. **lib/services/study_bot_storage_service.dart**
   - Added `senderType` parameter to `saveMessage()` method
   - Allows saving artifact messages with custom sender type

## Testing Checklist

- [ ] Create a quiz by talking to bot
- [ ] Complete/partial the quiz
- [ ] Close the app completely
- [ ] Reopen the app
- [ ] Navigate back to the study bot
- [ ] Verify quiz card appears in chat history
- [ ] Click quiz card to reopen it
- [ ] Verify all quiz data is intact (questions, answers, etc.)
- [ ] Test multiple artifacts in same session
- [ ] Test on both light and dark themes
- [ ] Verify other message types still work

## Debug Logging

Watch for these console messages:

```
💾 Artifact saved to Firebase: quiz_1738419600000
📦 Restored artifact: quiz_1738419600000
📦 Restored artifact from backend: quiz_1738419600000
```

## Backwards Compatibility

- Old messages without artifact data load normally
- Artifact reconstruction gracefully handles missing data
- No breaking changes to message structure
- Existing quizzes remain accessible

## Future Enhancements

- Add artifact expiration (optional cleanup after X days)
- Compress artifact data before storage to save space
- Add artifact edit history
- Support other artifact types (documents, worksheets, etc.)
