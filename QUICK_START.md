# ⚡ Quick Start & Verification Checklist

## Before Running `flutter run`

### Backend Setup

- [ ] `backend/.env` contains:
  ```
  PORT=3000
  GROQ_API_KEY=<your-key>
  tavily=<your-key>
  geminiapikey=<your-key>
  ```
- [ ] Node.js installed (`node -v`)
- [ ] Dependencies installed (`npm install` in backend folder)
- [ ] Backend tested locally: `node backend/server.js`

### Frontend Setup

- [ ] Flutter installed (`flutter --version`)
- [ ] Dependencies installed (`flutter pub get`)
- [ ] `lib/services/api_service.dart` has correct backend URL:
  - Local: `http://localhost:3000`
  - Render: `https://ai-backend-vf75.onrender.com`
- [ ] No compile errors (`flutter analyze`)

### Environment Variables

- [ ] `.env` file exists in `backend/`
- [ ] All three API keys are valid and active
- [ ] Render has env vars configured (if deploying)

---

## Testing the 3 APIs

### 1️⃣ Chat API (Groq)

```bash
# Test with curl
curl -X POST http://localhost:3000/api/ask \
  -H "Content-Type: application/json" \
  -d '{"type":"chat","data":{"message":"Hello"}}'
```

✅ Should respond with `{"provider":"groq","reply":"...","status":"success"}`

### 2️⃣ Search API (Tavily)

```bash
curl -X POST http://localhost:3000/api/ask \
  -H "Content-Type: application/json" \
  -d '{"type":"search","data":{"query":"weather today"}}'
```

✅ Should respond with search results

### 3️⃣ Image API (Gemini)

```bash
curl -X POST http://localhost:3000/api/ask \
  -H "Content-Type: application/json" \
  -d '{"type":"image","data":{"imageUrl":"https://upload.wikimedia.org/wikipedia/commons/thumb/4/4d/Cat_November_2010-1a.jpg/1200px-Cat_November_2010-1a.jpg","prompt":"What is this?"}}'
```

✅ Should respond with image analysis

---

## Run the App

```bash
# From project root
cd c:\android\flutter_application_1\myai

# Clean and get dependencies
flutter clean
flutter pub get

# Run
flutter run

# For release (Android)
flutter build apk

# For release (iOS)
flutter build ios
```

---

## In-App Testing Flow

1. **Open "Online AI" tab** (main chat interface)

2. **Test Chat**:

   - Type: "Explain machine learning"
   - Send
   - ✅ Should see Groq response

3. **Test Web Search**:

   - Type: "What is the weather today"
   - Send
   - ✅ Should show "Searching the web..." then results

4. **Test Image Analysis**:
   - Tap 📷 icon
   - Select or take a photo
   - Type: "What's in this image?"
   - Send
   - ✅ Should see Gemini analysis

---

## Common Issues & Fixes

| Issue                     | Check           | Fix                                      |
| ------------------------- | --------------- | ---------------------------------------- |
| "API configuration error" | Env vars        | Add missing keys to `.env`               |
| "Network error"           | Backend URL     | Verify `baseUrl` in `api_service.dart`   |
| "Request timeout"         | API slowness    | Increase timeout or check API status     |
| "Invalid request format"  | Request body    | Check frontend is sending `{type, data}` |
| "Backend not responding"  | Server running  | Start backend: `node backend/server.js`  |
| Image not analyzing       | API key         | Ensure `geminiapikey` is correct         |
| Search returns 404        | Tavily endpoint | Verify `tavily` key is valid             |

---

## Key Files Modified

```
lib/services/
├── api_service.dart ✅ (updated to /api/ask)
├── gemini_services.dart ✅ (updated image handling)
└── web_search_service.dart ✅ (updated to Tavily)

backend/
└── server.js ✅ (has all 3 APIs ready)
```

---

## Production Deployment (Render)

1. Push changes to GitHub:

   ```bash
   git add .
   git commit -m "feat: complete API integration testing"
   git push origin main
   ```

2. Render auto-deploys. Verify:

   - Backend logs in Render dashboard
   - No deployment errors
   - Environment variables are set

3. Test with Render URL:

   ```bash
   curl https://ai-backend-vf75.onrender.com/
   # Should return "Backend alive"
   ```

4. Update frontend `baseUrl` if needed and redeploy

---

## Success Indicators ✅

- [ ] Chat works: Get responses in ~5s
- [ ] Search works: Get results in ~15s
- [ ] Images work: Get analysis in ~10s
- [ ] No errors in console
- [ ] All timestamps present in logs
- [ ] Firebase auth working (if enabled)
- [ ] App doesn't crash on API errors

---

## Contact Points

- **Backend**: `lib/services/api_service.dart` (base URL)
- **Chat**: `lib/services/gemini_services.dart` → `generateContent()`
- **Search**: `lib/services/web_search_service.dart` → `search()`
- **Images**: `lib/services/gemini_services.dart` → `generateContentWithImage()`
- **UI**: `lib/screens/online_ai_screen.dart`

---

**Status**: 🟢 All systems ready for testing
**Last Updated**: 2026-01-03
