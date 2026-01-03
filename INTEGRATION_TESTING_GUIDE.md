# Complete Integration Testing Guide - MyAI App

This guide ensures all three APIs (Groq Chat, Tavily Search, Gemini Image Analysis) are working end-to-end.

## System Architecture Overview

```
Flutter App (Frontend)
    ↓
    lib/services/api_service.dart (unified API adapter)
    ↓
Backend API (Node.js/Express)
    ↓
    ├─→ /api/ask?type=chat → Groq API
    ├─→ /api/ask?type=search → Tavily API
    └─→ /api/ask?type=image → Gemini API
```

---

## Environment Setup

### Backend (Node.js)

Ensure `backend/.env` has these variables:

```
PORT=3000
GROQ_API_KEY=<your-groq-key>
tavily=<your-tavily-key>
geminiapikey=<your-gemini-key>
ANDROID_API_KEY=<optional>
```

### Frontend (Flutter)

Update `lib/services/api_service.dart`:

```dart
static const String baseUrl = "https://ai-backend-vf75.onrender.com";
// For local testing, change to:
// static const String baseUrl = "http://localhost:3000";
```

---

## API Endpoint Testing

### 1. **Chat API (Groq)** ✅

**Purpose**: Send text messages and get AI responses

**Frontend Call**:

```dart
final response = await GeminiService().generateContent("What is Flutter?");
```

**Backend Processing**:

- **Route**: `POST /api/ask`
- **Request Body**:
  ```json
  {
    "type": "chat",
    "data": {
      "message": "What is Flutter?"
    }
  }
  ```
- **Response**:
  ```json
  {
    "provider": "groq",
    "reply": "Flutter is a UI framework...",
    "status": "success",
    "timestamp": "2026-01-03T..."
  }
  ```

**Testing Steps**:

1. Open the app and go to **Online AI** tab
2. Type a message: "Explain React.js"
3. Press send
4. ✅ Should see Groq's response within 10 seconds
5. Check backend logs for `[Chat] Groq API success`

**Expected Errors & Fixes**:
| Error | Cause | Fix |
|-------|-------|-----|
| `GROQ_API_KEY not configured` | Missing env var | Add `GROQ_API_KEY` to `.env` |
| `Request timeout` | API is slow | Increase timeout (currently 30s) |
| `401 Unauthorized` | Invalid API key | Verify key in Groq dashboard |

---

### 2. **Web Search API (Tavily)** 🔍

**Purpose**: Search the web for current information

**Frontend Call**:

```dart
final results = await WebSearchService().search(query: "latest AI news 2025");
```

**Backend Processing**:

- **Route**: `POST /api/ask`
- **Request Body**:
  ```json
  {
    "type": "search",
    "data": {
      "query": "latest AI news 2025",
      "maxResults": 5
    }
  }
  ```
- **Response**:
  ```json
  {
    "provider": "tavily",
    "results": {
      "results": [
        {
          "title": "...",
          "url": "...",
          "content": "..."
        }
      ]
    },
    "status": "success",
    "timestamp": "2026-01-03T..."
  }
  ```

**Testing Steps**:

1. In **Online AI** screen, type: "What are the latest Flutter updates 2025?"
2. The app should detect this needs web search (keywords: "latest", "2025")
3. Should see "Searching the web..." status
4. Results combine with Groq for a comprehensive answer
5. ✅ Should complete within 15 seconds

**Alternative Direct Test** (Postman):

```bash
curl -X POST http://localhost:3000/api/ask \
  -H "Content-Type: application/json" \
  -d '{"type":"search","data":{"query":"best pizza recipe"}}'
```

**Expected Errors & Fixes**:
| Error | Cause | Fix |
|-------|-------|-----|
| `Tavily API key not configured` | Missing `tavily` env var | Add `tavily=<key>` to `.env` |
| `404 Not Found` | Wrong API endpoint | Verify `https://api.tavily.com/search` |
| No results | Query issue | Try simpler query (e.g., "weather") |

---

### 3. **Image Analysis API (Gemini)** 🖼️

**Purpose**: Analyze images using Gemini Vision API

**Frontend Call**:

```dart
final analysis = await GeminiService().generateContentWithImage(
  prompt: "What's in this image?",
  base64Image: base64EncodedImage,
  mimeType: "image/jpeg",
);
```

**Backend Processing**:

- **Route**: `POST /api/ask`
- **Request Body**:
  ```json
  {
    "type": "image",
    "data": {
      "imageBase64": "iVBORw0KGgo...",
      "imageUrl": "https://example.com/image.jpg",
      "prompt": "What's in this image?"
    }
  }
  ```
- **Response**:
  ```json
  {
    "provider": "gemini",
    "analysis": "This image shows a cat sitting on a windowsill...",
    "status": "success",
    "timestamp": "2026-01-03T..."
  }
  ```

**Testing Steps**:

1. Go to **Online AI** screen
2. Tap the **image icon** (📷) to pick an image
3. Select a photo from gallery or camera
4. Type a prompt: "Describe what you see"
5. Send
6. ✅ Should see image analysis within 10 seconds
7. Check logs for `[Image] Gemini API success`

**Testing with URL**:

```bash
curl -X POST http://localhost:3000/api/ask \
  -H "Content-Type: application/json" \
  -d '{
    "type": "image",
    "data": {
      "imageUrl": "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4d/Cat_November_2010-1a.jpg/1200px-Cat_November_2010-1a.jpg",
      "prompt": "What breed is this cat?"
    }
  }'
```

**Backend automatically**:

- ✅ Fetches the image from URL
- ✅ Converts to base64
- ✅ Sends to Gemini API
- ✅ Returns analysis

**Expected Errors & Fixes**:
| Error | Cause | Fix |
|-------|-------|-----|
| `GEMINI API key not configured` | Missing `geminiapikey` env var | Add `geminiapikey=<key>` to `.env` |
| `Failed to fetch image` | Invalid URL or timeout | Ensure URL is public and accessible |
| `Not implemented (501)` | Old render service logic | Code is updated, redeploy to Render |
| Image too large | File > 4MB | Frontend limits to 1024×1024 (85% quality) |

---

## Feature-by-Feature Testing

### **Test 1: Simple Chat**

```
Input: "How do I learn Flutter?"
Expected: AI response about Flutter learning resources
API Used: Groq
Time: ~5-10 seconds
```

### **Test 2: Web Search Integration**

```
Input: "What are the latest JavaScript frameworks 2025?"
Expected: Web search results + AI synthesis
API Used: Tavily + Groq
Time: ~15 seconds
```

### **Test 3: Image Analysis**

```
Input: Photo of nature
Prompt: "Identify the trees and plants in this image"
Expected: Detailed botanical analysis
API Used: Gemini
Time: ~10-15 seconds
```

### **Test 4: Study Plans (Uses Chat API)**

```
Step 1: Create study plan with context "Act as a Python tutor"
Step 2: Ask: "Explain decorators in Python"
Expected: Contextual response following study plan
API Used: Groq (with custom system context)
Time: ~5-10 seconds
```

---

## Backend Logs Checklist

When testing, watch the backend logs for these patterns:

### ✅ Successful Chat

```
[Chat] Calling Groq API...
[Chat] Groq API success: {...}
```

### ✅ Successful Search

```
[Search Case] Processing search request: {...}
[Search] Calling Tavily API...
```

### ✅ Successful Image Analysis

```
[Image Case] Processing image request: {...}
[Image] Calling Gemini API...
[Image] Gemini API success: {...}
```

### ⚠️ Common Errors

```
[Error] GROQ_API_KEY not configured
[Error] Tavily API key not configured (env 'tavily')
[Error] GEMINI API key not configured (env 'geminiapikey')
[Error] Request timeout after 60 seconds
```

---

## Frontend Integration Points

### **api_service.dart**

Maps old provider/action calls to new `/api/ask` endpoint:

```
groq + chat → type: "chat"
tavily + search → type: "search"
gemini + image → type: "image"
```

### **gemini_services.dart**

- `generateContent(prompt)` → Groq chat
- `generateContentWithContext(prompt, context)` → Groq chat (study plans)
- `generateContentWithImage(prompt, base64Image, mimeType)` → Gemini image
- `generateQuiz(...)` → Groq chat (quiz generation)

### **web_search_service.dart**

- `search(query)` → Tavily search
- Detects web search keywords automatically
- Combines search results with Groq response

### **online_ai_screen.dart**

- Text input → Groq chat
- Image picker → Gemini image analysis
- Web search toggle → Tavily search
- Displays all responses in message bubbles

---

## Deployment Checklist

### Local Testing

- [ ] Backend running on `http://localhost:3000`
- [ ] All env vars set in `backend/.env`
- [ ] Frontend `baseUrl` points to local backend
- [ ] `flutter run` launches app without errors
- [ ] All three APIs respond correctly

### Render Deployment

- [ ] Backend pushed to GitHub (`git push origin main`)
- [ ] Render auto-deploys from GitHub
- [ ] Environment variables set in Render dashboard:
  - `GROQ_API_KEY`
  - `tavily`
  - `geminiapikey`
- [ ] Frontend `baseUrl` updated to `https://ai-backend-vf75.onrender.com`
- [ ] Frontend changes pushed to GitHub
- [ ] Test on Render-deployed backend

### Firebase Setup

- [ ] `google-services.json` in `android/app/`
- [ ] Firebase initialized in `main.dart`
- [ ] Auth, Firestore, Cloud Storage configured

---

## Quick Postman Test Script

Save as `test_apis.json` and import into Postman:

```json
{
  "info": {
    "name": "MyAI API Tests",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Chat - Groq",
      "request": {
        "method": "POST",
        "url": "{{baseUrl}}/api/ask",
        "body": {
          "type": "json",
          "raw": "{\"type\":\"chat\",\"data\":{\"message\":\"Hello, how are you?\"}}"
        }
      }
    },
    {
      "name": "Search - Tavily",
      "request": {
        "method": "POST",
        "url": "{{baseUrl}}/api/ask",
        "body": {
          "type": "json",
          "raw": "{\"type\":\"search\",\"data\":{\"query\":\"best pizza recipe\"}}"
        }
      }
    },
    {
      "name": "Image - Gemini",
      "request": {
        "method": "POST",
        "url": "{{baseUrl}}/api/ask",
        "body": {
          "type": "json",
          "raw": "{\"type\":\"image\",\"data\":{\"imageUrl\":\"https://upload.wikimedia.org/wikipedia/commons/thumb/4/4d/Cat_November_2010-1a.jpg/1200px-Cat_November_2010-1a.jpg\",\"prompt\":\"What is this?\"}}"
        }
      }
    }
  ],
  "variable": [
    {
      "key": "baseUrl",
      "value": "http://localhost:3000"
    }
  ]
}
```

---

## Troubleshooting Flow

```
Issue: API not responding
├─ Check backend is running
│  └─ Run: node backend/server.js
├─ Check env vars are set
│  └─ Review: backend/.env
├─ Check frontend baseUrl
│  └─ Update: lib/services/api_service.dart
└─ Check Render logs (if deployed)
   └─ Visit: Render dashboard → Logs

Issue: Specific API fails
├─ Check API key in .env
├─ Test with Postman directly
├─ Check backend error logs
├─ Verify API provider status
└─ Try with sample data from provider docs

Issue: Image not working
├─ Check image URL accessibility
├─ Verify file size < 4MB
├─ Confirm mimeType is correct
├─ Check Gemini API quota
└─ Try base64 upload instead of URL
```

---

## Success Criteria ✅

All tests pass when:

1. **Chat API**: Message sent → Response within 10s
2. **Search API**: Query sent → Results within 15s
3. **Image API**: Image uploaded → Analysis within 15s
4. **Study Plans**: Works with Groq chat API
5. **Error Messages**: Clear, helpful, show timestamps
6. **Logs**: All operations logged with timestamps
7. **Frontend**: No crashes, smooth UI updates
8. **Deployment**: Works on both local and Render

---

## Next Steps

Once all tests pass:

1. Run: `flutter build apk` (Android) or `flutter build ios` (iOS)
2. Test on physical device
3. Deploy to app stores
4. Monitor Render logs for production issues
5. Set up error tracking (e.g., Sentry)

---

Generated: 2026-01-03 | Version: 1.0
