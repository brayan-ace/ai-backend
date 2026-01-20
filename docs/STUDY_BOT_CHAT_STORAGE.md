# Study Bot Chat Storage Implementation

## Overview

This document explains how conversation history is implemented for Study Bots using **Firebase Firestore** as the primary storage, with **PostgreSQL** as a backup.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        FLUTTER APP                               │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │           StudyPlanChatScreen                            │    │
│  │  - Sends/receives messages                               │    │
│  │  - Calls StudyBotStorageService for Firebase ops         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│                              ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │         StudyBotStorageService                           │    │
│  │  - Saves messages to Firebase Firestore                  │    │
│  │  - Loads conversation history                            │    │
│  │  - Formats history for AI context                        │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FIREBASE FIRESTORE                            │
│  users/{userId}/study_bot_chats/{botId}/                        │
│    ├── botName, topic, description                              │
│    ├── lastMessage, progressPercentage                          │
│    └── messages/ (subcollection)                                │
│          ├── {messageId}: { text, fromUser, timestamp }         │
│          └── ...                                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      BACKEND (Node.js)                           │
│  - Receives conversation history from frontend                  │
│  - Falls back to PostgreSQL if Firebase history not provided    │
│  - Sends full context to AI for coherent responses              │
│  - Also saves to PostgreSQL as backup                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Files

### 1. `lib/services/study_bot_storage_service.dart`

**Purpose:** Firebase Firestore service for study bot chat storage.

**Key Methods:**

| Method | Description |
|--------|-------------|
| `getOrCreateBotChat()` | Creates or retrieves a chat session for a bot |
| `saveMessage()` | Saves a user or bot message to Firestore |
| `getMessages()` | Retrieves all messages for a bot (one-time fetch) |
| `getMessagesStream()` | Real-time stream of messages |
| `getConversationHistoryForAI()` | Formats last N messages for AI context |
| `updateProgress()` | Updates bot progress in Firebase |
| `getStudyBotChats()` | Lists all study bot chats for the user |

**Firestore Structure:**
```
users/
  └── {userId}/
      └── study_bot_chats/
          └── {botId}/
              ├── botId: string
              ├── botName: string
              ├── topic: string
              ├── description: string
              ├── lastMessage: string
              ├── lastMessageTime: timestamp
              ├── messageCount: number
              ├── progressPercentage: number
              ├── currentModule: number
              ├── botState: string
              ├── createdAt: timestamp
              ├── updatedAt: timestamp
              └── messages/ (subcollection)
                  └── {messageId}/
                      ├── text: string
                      ├── fromUser: boolean
                      ├── senderType: string ('user' | 'bot')
                      ├── timestamp: timestamp
                      └── metadata: map (optional)
```

---

### 2. `lib/screens/study_plan_chat_screen.dart`

**Changes Made:**

1. **Import added:**
   ```dart
   import '../services/study_bot_storage_service.dart';
   ```

2. **Service initialized:**
   ```dart
   late final StudyBotStorageService _storageService;
   
   @override
   void initState() {
     // ...
     _storageService = StudyBotStorageService();
   }
   ```

3. **Loading messages from Firebase (in `_initPhase2`):**
   ```dart
   // Initialize Firebase chat session
   await _storageService.getOrCreateBotChat(
     botId: widget.botId!,
     botName: widget.botName ?? 'Study Bot',
     topic: widget.planName,
     description: widget.planDescription,
   );
   
   // Load chat history from Firebase
   final firebaseMessages = await _storageService.getMessages(widget.botId!);
   ```

4. **Saving user messages (in `_addUserMessage`):**
   ```dart
   await _storageService.saveMessage(
     botId: widget.botId!,
     text: text,
     fromUser: true,
   );
   ```

5. **Saving bot messages (in `_addBotMessage`):**
   ```dart
   await _storageService.saveMessage(
     botId: widget.botId!,
     text: adaptedText,
     fromUser: false,
   );
   ```

6. **Sending history to backend (in `_sendMessageToBackend`):**
   ```dart
   List<Map<String, String>> conversationHistory = [];
   conversationHistory = await _storageService.getConversationHistoryForAI(
     widget.botId!,
     limit: 20,
   );
   
   final payload = {
     'message': userMessage,
     'botId': widget.botId,
     'userId': userId,
     'conversationHistory': conversationHistory,  // <-- NEW
     // ...
   };
   ```

---

### 3. `backend/server.js`

**Changes Made:**

The backend now accepts `conversationHistory` from the frontend and uses it for AI context:

```javascript
// STEP 5.5: Use conversation history from Firebase (sent by frontend) OR fallback to database
const frontendHistory = req.body.conversationHistory;

if (frontendHistory && Array.isArray(frontendHistory) && frontendHistory.length > 0) {
  // Use conversation history from Firebase (sent by frontend)
  console.log(`[Chat-Enhanced] 🔥 Using ${frontendHistory.length} messages from Firebase`);
  for (const msg of frontendHistory) {
    if (msg.role && msg.content) {
      messages.push({ role: msg.role, content: msg.content });
    }
  }
} else {
  // Fallback: Fetch conversation history from PostgreSQL database
  // ...
}
```

---

## How Conversation History Works

### Flow Diagram

```
1. User opens Study Bot
        │
        ▼
2. _initPhase2() called
        │
        ├──► Firebase: getOrCreateBotChat() - Initialize session
        │
        ├──► Firebase: getMessages() - Load all previous messages
        │
        └──► Display messages in chat UI
        
3. User sends a message
        │
        ├──► Firebase: saveMessage(fromUser: true) - Save user message
        │
        ├──► Firebase: getConversationHistoryForAI() - Get last 20 messages
        │
        └──► Backend: POST /api/chat-enhanced with conversationHistory
                │
                ▼
        Backend uses history for AI context
                │
                ▼
        AI generates contextual response
                │
                ▼
4. Bot response received
        │
        └──► Firebase: saveMessage(fromUser: false) - Save bot message
```

### Why This Approach?

1. **Firebase as Primary Storage:**
   - Real-time sync across devices
   - Offline support
   - Fast reads for mobile apps
   - Matches the pattern used in `OnlineAiScreen`

2. **PostgreSQL as Backup:**
   - Server-side persistence
   - Fallback if Firebase fails
   - Useful for analytics/debugging

3. **Full History Sent to AI:**
   - AI has context of entire conversation
   - Prevents repetitive responses
   - Enables coherent multi-turn dialogue

---

## Testing the Implementation

1. **Create a new Study Bot** and start a conversation
2. **Send several messages** back and forth
3. **Close the app completely**
4. **Reopen the bot** - you should see all previous messages
5. **Continue the conversation** - AI should remember context

### Debug Logs to Watch

```
[ChatScreen] 🔥 Firebase chat session initialized
[ChatScreen] 🔥 Loaded X messages from Firebase
[ChatScreen] 🔥 User message saved to Firebase
[ChatScreen] 🔥 Bot message saved to Firebase
[ChatScreen] 🔥 Loaded X messages for AI context
[Chat-Enhanced] 🔥 Using X messages from Firebase (via frontend)
```

---

## Comparison with OnlineAiScreen

| Feature | OnlineAiScreen | StudyPlanChatScreen |
|---------|----------------|---------------------|
| Storage Service | `ChatStorageService` | `StudyBotStorageService` |
| Firestore Path | `users/{uid}/chats/{chatId}` | `users/{uid}/study_bot_chats/{botId}` |
| Chat ID | Auto-generated | Uses `botId` |
| Progress Tracking | No | Yes |
| Study Plan | No | Yes |
| AI Context | Local only | Sent to backend |

---

## Summary

- **Primary Storage:** Firebase Firestore
- **Backup Storage:** PostgreSQL (backend)
- **History Limit:** Last 20 messages sent to AI
- **Real-time:** Yes (via Firestore streams)
- **Offline Support:** Yes (Firestore caching)
