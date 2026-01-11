# Quick Reference: Testing System Instructions Updates

## Quick Test (2 minutes)

### 1️⃣ Get Your Bot ID

Open app logs and look for:

```
[BotProcessingScreen] Bot created successfully: bot_1768095418663_9978
```

### 2️⃣ Check Current Instructions

```bash
curl "https://ai-backend-vf75.onrender.com/api/debug/bot/bot_1768095418663_9978" | grep "You are"
```

### 3️⃣ Update Instructions

```bash
curl -X PUT "https://ai-backend-vf75.onrender.com/api/bot/bot_1768095418663_9978/instructions" \
  -H "Content-Type: application/json" \
  -d '{
    "systemInstructions": {
      "instructions": "You are a SILLY bot who answers everything with jokes and puns! Make every response fun and playful.",
      "bot_name": "nutri",
      "topic": "Autotrophs",
      "grade_level": "Senior Secondary",
      "generated_at": "2026-01-11T00:00:00Z",
      "is_natural_bot": true
    }
  }'
```

### 4️⃣ Verify Update in Database

```bash
curl "https://ai-backend-vf75.onrender.com/api/debug/bot/bot_1768095418663_9978" | grep "SILLY"
```

Should show: `"You are a SILLY bot..."`

### 5️⃣ Hot Restart App

```
Press R in Flutter terminal
```

### 6️⃣ Watch Logs

Should see:

```
[ChatScreen] ✅ Fresh system instructions fetched and updated
[ChatScreen] Bot: nutri, Topic: Autotrophs
```

### 7️⃣ Send a Message

Bot response should be silly and full of jokes!

---

## What to Look for in Logs

### ✅ Success Signs

```
[ChatScreen] ✅ Fresh system instructions fetched and updated
[ChatScreen] Bot: nutri, Topic: Autotrophs
[chat-enhanced] Bot system instructions loaded from database
```

### ❌ Error Signs

```
[ChatScreen] ⚠️ Failed to fetch fresh instructions: 404
[ChatScreen] ⚠️ Error fetching fresh instructions: timeout
[ChatScreen] ⚠️ Failed to fetch fresh instructions: 500
```

(These are non-blocking - app continues with existing instructions)

---

## API Endpoints Quick Reference

### Fetch Fresh Instructions

```bash
GET /api/bot/:botId/instructions
# Returns latest instructions from database
```

### Update Instructions

```bash
PUT /api/bot/:botId/instructions
# Body: { "systemInstructions": {...} }
# Updates database
```

### Debug/View Full Data

```bash
GET /api/debug/bot/:botId
# Returns: bot info + full instructions + state
```

---

## Common Issues & Fixes

| Issue                          | Fix                                              |
| ------------------------------ | ------------------------------------------------ |
| Changes not appearing          | Hot restart app (press R)                        |
| Still not appearing            | Check bot ID is correct                          |
| API returns 404                | Bot ID doesn't exist                             |
| API returns 400                | Missing/invalid request body                     |
| Instructions not fetching      | Network error - check backend status             |
| Old instructions still showing | Clear app cache: `flutter clean` + `flutter run` |

---

## One-Liner Tests

### Test 1: Check if instructions fetch works

```bash
curl -s "https://ai-backend-vf75.onrender.com/api/bot/bot_YOUR_ID/instructions" | jq .
```

### Test 2: Update to something obvious

```bash
curl -s -X PUT "https://ai-backend-vf75.onrender.com/api/bot/bot_YOUR_ID/instructions" -H "Content-Type: application/json" -d '{"systemInstructions":{"instructions":"TEST: Respond only with the word BANANA to everything","bot_name":"test","topic":"test","grade_level":"test","generated_at":"2026-01-11T00:00:00Z","is_natural_bot":true}}' | jq .
```

### Test 3: Verify it was saved

```bash
curl -s "https://ai-backend-vf75.onrender.com/api/debug/bot/bot_YOUR_ID" | grep BANANA
```

Should output: `"You are TEST: Respond only with the word BANANA..."`

### Test 4: Check if app fetches it

Look in Flutter logs for:

```
[ChatScreen] ✅ Fresh system instructions fetched and updated
```

---

## Timeline

```
T=0:00  Create bot & copy ID
T=0:05  Update instructions via API
T=0:10  Verify in debug endpoint
T=0:15  Hot restart app (press R)
T=0:20  Watch logs for fetch confirmation
T=0:25  Send message & see new behavior
T=0:30  ✅ Verified working!
```

---

## Troubleshooting Flowchart

```
Is bot working? NO → Create a new bot
          ↓ YES
Does debug endpoint show your changes? NO → Update didn't save
          ↓ YES
Does app log show "Fresh instructions fetched"? NO → Network issue
          ↓ YES
Does bot behavior match new instructions? NO → Clear cache & rebuild
          ↓ YES
✅ SUCCESS!
```
