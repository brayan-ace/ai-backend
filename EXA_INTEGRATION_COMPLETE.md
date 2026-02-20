# ✅ Exa API Integration Complete

## 🎯 End-to-End Web Search Flow

### **Main Flow: Frontend-Initiated Smart Web Search**

```
User Message
    ↓
_send() method
    ↓
No image? → Call _callWithFallback()
    ↓
_callWithFallback():
  1. Build conversation history
  ↓
  2. Detect if web search needed: _questionNeedsWebSearch()
     (Checks 44+ keywords for recent info queries)
  ↓
  3. Auto-enable logic:
     IF (questionNeedsSearch && !_webSearchEnabled):
       - Set _webSearchEnabled = true
       - Set _wasWebSearchAutoEnabledThisRequest = true
       - Toggle shows ON visually
       - Show snackbar: "Smart mode: Auto-enabling web search"
  ↓
  4. Determine shouldUseWebSearch = _webSearchEnabled && questionNeedsSearch
  ↓
  5. Send to BACKEND:
     POST /chat with {
       webSearchEnabled: true,
       message: prompt,
       messages: conversationHistory,
       mode: responseMode,
       model: selectedModel,
       systemPrompt: aiSystemPrompt,
       ...
     }
  ↓
  6. Backend Response:
     - If webSearchEnabled: Routes to Exa search handler
     - Calls Exa API (/api/exa.ai/search)
     - Gets search results (type: "auto", num_results: 5)
     - Processes with Groq AI (enhanceSearchResultsWithAI)
     - Returns { enhancedAnswer, reply, provider: "exa", ... }
  ↓
  7. Extract response:
     - prioritizes: enhancedAnswer (AI-processed search results)
     - fallback: reply (raw response)
  ↓
  8. If auto-enabled:
     - Receive response
     - Immediately set _webSearchEnabled = false
     - Set _wasWebSearchAutoEnabledThisRequest = false
     - Toggle switches back OFF visually
     - Temporary auto-enable is complete
  ↓
Display response to user
```

---

## 🔧 Configuration

### Frontend

- **Smart Detection**: `_questionNeedsWebSearch()` - 44+ keywords
- **Auto-Enable**: Temporary, per-request only
- **Toggle Behavior**:
  - ✅ User enables → Web search for all questions
  - ✅ User disables + question needs it → Auto-enable temporarily, then disable
  - ✅ Visual feedback → Toggle shows ON when auto-enabled

### Backend

- **Exa API Key**: `EXA_API_KEY` environment variable
- **Search Endpoint**: `https://api.exa.ai/search`
- **Search Type**: `auto` (balanced relevance & speed)
- **Results**: 5 per query
- **Content**: Full text (max 20,000 characters)
- **Headers**: `x-api-key: EXA_API_KEY`
- **AI Enhancement**: Groq (`openai/gpt-oss-20b`)

---

## 📊 Request/Response Examples

### Frontend Request (to /chat)

```javascript
{
  "message": "What's the latest AI news?",
  "messages": [
    {"role": "user", "content": "Tell me about AI"},
    {"role": "assistant", "content": "AI is..."}
  ],
  "webSearchEnabled": true,        // ← Smart auto-detect or user toggle
  "mode": "normal",
  "model": "groq-pro",
  "systemPrompt": "...",
  "conversationHistory": [...]
}
```

### Backend Processing (if webSearchEnabled)

```javascript
1. Check: data.webSearchEnabled || data.useWebSearch → TRUE
2. Extract: query = "What's the latest AI news?"
3. Enhance query with conversation context via Groq
4. Call Exa API:
   POST https://api.exa.ai/search {
     "query": "Latest AI news developments 2026",
     "type": "auto",
     "num_results": 5,
     "contents": {
       "text": { "max_characters": 20000 }
     }
   }
5. Receive Exa results
6. Process with AI: enhanceSearchResultsWithAI()
7. Return response
```

### Backend Response

```javascript
{
  "provider": "exa",
  "status": "success",
  "enhancedAnswer": "Based on recent news...",  // ← AI-processed answer
  "reply": "Formatted results summary...",
  "results": {
    "results": [ {title, url, text, ...}, ... ]
  },
  "originalQuery": "What's the latest AI news?",
  "enhancedQuery": "Latest AI news developments 2026",
  "timestamp": "2026-02-20T..."
}
```

### Frontend Response Extraction

```dart
// In _callWithSearchResults():
final enhancedAnswer = fullResp['enhancedAnswer'];
if (enhancedAnswer != null && enhancedAnswer.toString().isNotEmpty) {
  return enhancedAnswer.toString();  // ← Use AI-enhanced answer
}
// Fallback if needed
final reply = fullResp['reply'] ?? fullResp['response'] ?? '';
```

---

## 🔄 Fallback Flow (Backend Detection)

If backend detects web search need but frontend didn't request it:

```
Frontend sends: webSearchEnabled: false
    ↓
Backend checks: shouldAutoTriggerWebSearch(message)
    ↓
IF detected AND !requested:
  - Return: webSearchAutoTriggered: true
    ↓
Frontend sees webSearchAutoTriggered: true
    ↓
Do local web search as fallback:
  - _webSearchService.search()
  - _webSearchService.createEnhancedPrompt()
  - _callWithSearchResults() → sends to backend
```

---

## ✨ Key Features

✅ **Smart Auto-Enable**: Detects queries needing current info, auto-enables search temporarily
✅ **Visual Feedback**: Toggle shows ON when auto-enabled
✅ **Temporary Only**: Auto-enable resets after request sent
✅ **User Control**: Users can manually enable/disable toggle
✅ **Backend Integration**: All web search handled by backend via Exa API
✅ **AI Enhancement**: Search results processed by AI for better answers
✅ **Conversation Aware**: Uses conversation history for better search queries
✅ **Fallback Mechanism**: Backend can detect web search need as safety net

---

## 🚀 Testing Checklist

- [ ] Deploy with EXA_API_KEY environment variable set
- [ ] Test: "What's the weather today?" → Auto-enables web search
- [ ] Test: "Explain photosynthesis" → Does NOT auto-enable
- [ ] Test: Manually enable toggle, ask knowledge question → Toggle stays on
- [ ] Test: Manually disable toggle, ask recent info → Auto-enables, then disables
- [ ] Verify: Exa search results appear in response
- [ ] Verify: Enhanced answer from Groq appears (not raw search results)
- [ ] Check logs: `[Exa]`, `[Web Search]`, `[SMART WEB SEARCH]` entries

---

## 📝 Environment Variables

### Required

```bash
EXA_API_KEY=your_exa_api_key_here
GROQ_API_KEY=your_groq_api_key_here  # For AI enhancement
```

### Optional

```bash
EXA_SEARCH_TYPE=auto              # Default: auto (balanced)
EXA_MAX_RESULTS=5                 # Default: 5
EXA_MAX_CHARACTERS=20000          # Default: 20000
```

---

## 🔍 Monitoring

### Frontend Logs

- `[SMART WEB SEARCH] Question needs recent info - auto-enabling web search`
- `[SMART WEB SEARCH] Request sent - disabling web search toggle back off`

### Backend Logs

- `[Exa] Searching for: [query]`
- `[Exa] Found X results`
- `[Web Search] Enhanced query: [enhanced-query]`
- `[AI Enhancement] Processing results with Groq`

---

## 🎓 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTER FRONTEND                         │
│                                                             │
│  _send() → (no image)                                      │
│    └→ _callWithFallback()                                  │
│        ├─ _questionNeedsWebSearch() [44 keywords]          │
│        ├─ Auto-enable logic (temporary)                    │
│        └─ Send to backend with webSearchEnabled flag       │
│                                                             │
│  _callWithSearchResults() [Fallback only]                  │
└─────────────────────────────────────────────────────────────┘
                          ↓ HTTP POST
┌─────────────────────────────────────────────────────────────┐
│                   NODE.JS BACKEND                           │
│                                                             │
│  POST /chat                                                 │
│    ↓                                                        │
│  if (webSearchEnabled):                                     │
│    ├─ summarizeConversationForSearch() [Groq]             │
│    ├─ Call Exa API [EXA_API_KEY]                          │
│    │   └─ https://api.exa.ai/search                       │
│    │       └─ type: "auto", num_results: 5                │
│    │           contents: { text: {max_chars: 20000} }      │
│    ├─ enhanceSearchResultsWithAI() [Groq]                 │
│    └─ Return { enhancedAnswer, reply, provider: exa }     │
│                                                             │
│  else:                                                      │
│    └─ Normal chat, check shouldAutoTriggerWebSearch()     │
│       └─ Return webSearchAutoTriggered flag                │
└─────────────────────────────────────────────────────────────┘
                          ↓ JSON Response
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTER FRONTEND                         │
│                                                             │
│  Extract response:                                          │
│    ├─ enhancedAnswer (preferred)                           │
│    └─ reply (fallback)                                     │
│                                                             │
│  If auto-enabled:                                          │
│    └─ Reset _webSearchEnabled = false                      │
│       Reset toggle OFF                                     │
│                                                             │
│  Display to user                                            │
└─────────────────────────────────────────────────────────────┘
```

---

## Summary

✅ **Smart web search is now fully integrated with Exa API**

- Frontend detects when web search is needed
- Auto-enables temporarily with visual feedback
- Backend handles all Exa API calls
- Results are AI-enhanced for better user experience
- Toggle immediately disables after request (no persistence)
- Fallback mechanism for backend detection

The system is designed to be transparent to the user while intelligently determining when web search adds value!
