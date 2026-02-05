# Render to Railway Migration Guide

## Overview

This document outlines all changes made to migrate the backend from Render to Railway. Railway handles environment variables, database connections, and deployment differently, so specific code changes were required.

---

## Changes Made

### 1. ✅ Environment Variables (.env)

**File**: `.env`

**Changes**:

- Removed all hardcoded API keys and secrets
- Removed Render-specific comments and references
- Removed `RENDER_SERVICE_URL` variable
- Removed hardcoded `geoqapikey` and `tavily` values
- Changed database configuration section from Render-specific to Railway-compatible

**Old** (with secrets exposed):

```env
PORT=3000
GROQ_API_KEY=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
OPENROUTER_API_KEY=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
DEEPSEEK_API_KEY=sk-8d17e5b0c355485da07af11f552e37f9
TAVILY_API_KEY=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
ANDROID_API_KEY=AIzaSyDH-d9tC853bXoDpvxGJNW3IEka1hxcJA8

# PostgreSQL Database Configuration (Render)
DB_USER=nexa_db_uw9d_user
DB_HOST=dpg-d5g4d1er433s73b1i43g-a.onrender.com
DB_NAME=nexa_db_uw9d
DB_PORT=5432
DB_PASSWORD=kamPRCC4ui6CUoq6UH7ryVHc8QWc2IHF

geminiapikey=
geoqapikey=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
tavily=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
RENDER_SERVICE_URL=
```

**New** (secrets cleared for Railway):

```env
PORT=3000

# API Keys (set these in Railway environment variables)
GROQ_API_KEY=
OPENROUTER_API_KEY=
DEEPSEEK_API_KEY=
TAVILY_API_KEY=
ANDROID_API_KEY=

# PostgreSQL Database Configuration
# On Railway, use DATABASE_URL or set individual connection parameters
DATABASE_URL=

# Alternative individual database parameters (used if DATABASE_URL is not provided)
DB_USER=
DB_HOST=
DB_NAME=
DB_PORT=5432
DB_PASSWORD=

# Alternative API key variable names (optional, set in Railway environment variables)
GEMINI_API_KEY=
GEO_QA_API_KEY=

# Node environment
NODE_ENV=production
```

**Why**: Secrets should never be committed to version control. Railway provides them via environment variables.

---

### 2. ✅ Database Connection (db.js)

**File**: `backend/db.js`

**Changes**:

- Added support for Railway's `DATABASE_URL` environment variable
- Maintained backward compatibility with individual connection parameters
- Added logic to prefer `DATABASE_URL` if available

**Old**:

```javascript
const { Pool } = require("pg");

const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT ? parseInt(process.env.DB_PORT, 10) : 5432,
  ssl: {
    rejectUnauthorized: false,
  },
});

module.exports = { pool };
```

**New**:

```javascript
const { Pool } = require("pg");

// Support both Railway's DATABASE_URL and individual connection parameters
let pool;

if (process.env.DATABASE_URL) {
  // Railway uses DATABASE_URL - use it directly
  pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: {
      rejectUnauthorized: false,
    },
  });
} else {
  // Fallback to individual connection parameters
  pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT ? parseInt(process.env.DB_PORT, 10) : 5432,
    ssl: {
      rejectUnauthorized: false,
    },
  });
}

module.exports = { pool };
```

**Why**: Railway's PostgreSQL plugin automatically provides `DATABASE_URL`. This change allows the app to use it seamlessly while maintaining backward compatibility.

---

### 3. ✅ dotenv Configuration (server.js)

**File**: `backend/server.js`

**Changes**:

- Made dotenv loading conditional on NODE_ENV
- Only loads `.env` file in non-production environments
- Ensures Railway's native environment variables are used in production

**Old**:

```javascript
require("dotenv").config();
```

**New**:

```javascript
// Load .env only in development (Railway uses environment variables directly)
if (process.env.NODE_ENV !== "production") {
  require("dotenv").config();
}
```

**Why**: In production on Railway, environment variables are provided by the platform. Loading `.env` unnecessarily can cause issues. This ensures dotenv only affects local development.

---

## Configuration Already Correct ✅

The following items were already correct and required no changes:

### 4. ✅ Server PORT

- **Line 3877 in server.js**:

```javascript
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(
    `[Server Started] Running on port ${PORT} at ${new Date().toISOString()}`,
  );
});
```

- ✅ Correctly reads from `process.env.PORT`
- ✅ Has sensible fallback (3000)
- ✅ Logs startup information

### 5. ✅ Health Check Endpoint

- **Line 922 in server.js**:

```javascript
app.get("/", (req, res) => {
  try {
    res.send("Backend alive");
  } catch (error) {
    console.error("[GET /] Error:", error.message);
    res.status(500).json({
      error: "Root endpoint failed",
      message: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});
```

- ✅ Returns 200 OK for Railway health checks
- ✅ Properly handles errors

### 6. ✅ API Key Handling

- All API keys (GROQ, OpenRouter, DeepSeek, Tavily, etc.) are read from `process.env`
- No hardcoded keys in the codebase
- Consistent usage across all endpoints

### 7. ✅ Logging

- Uses standard `console.log()` and `console.error()`
- Logs are automatically captured by Railway
- Includes timestamps for debugging

### 8. ✅ Start Command

- **package.json**:

```json
{
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  }
}
```

- ✅ Correct start script
- ✅ Main file matches start script

---

## Railway Deployment Checklist

### Before Deploying to Railway:

1. **Set Environment Variables in Railway Dashboard**:
   - Go to your Railway project → Variables
   - Add all required variables (do NOT use .env file):
     ```
     PORT=3000
     NODE_ENV=production
     DATABASE_URL=[Railway PostgreSQL connection string]
     GROQ_API_KEY=[your-groq-key]
     OPENROUTER_API_KEY=[your-openrouter-key]
     DEEPSEEK_API_KEY=[your-deepseek-key]
     TAVILY_API_KEY=[your-tavily-key]
     ANDROID_API_KEY=[your-android-key]
     GEMINI_API_KEY=[your-gemini-key]
     GEO_QA_API_KEY=[your-geo-qa-key]
     ```

2. **Database Setup**:
   - Add a PostgreSQL plugin to your Railway project
   - Railway automatically provides `DATABASE_URL`
   - No need to manually configure `DB_HOST`, `DB_USER`, etc.
   - The app will automatically use the provided connection string

3. **Verify Code**:
   - ✅ All changes have been made
   - ✅ No hardcoded secrets in code
   - ✅ No .env file needed in production
   - ✅ PORT defaults to 3000
   - ✅ Health check available at GET /

4. **Deploy**:
   - Push code to GitHub
   - Railway will automatically:
     - Install dependencies (`npm install`)
     - Run start script (`npm start`)
     - Restart on crashes
     - Provide PORT via environment variable

### Local Development:

1. **Create `.env` file locally** with your keys:

   ```env
   PORT=3000
   NODE_ENV=development
   GROQ_API_KEY=your-key
   OPENROUTER_API_KEY=your-key
   # ... other keys
   DATABASE_URL=postgresql://user:password@localhost:5432/dbname
   ```

2. **Run locally**:

   ```bash
   npm install
   npm start
   ```

3. **The app will**:
   - Load `.env` file (because NODE_ENV !== "production")
   - Use your local database
   - Listen on port 3000

---

## Summary of Changes

| File        | Change                              | Reason                              |
| ----------- | ----------------------------------- | ----------------------------------- |
| `.env`      | Cleared all hardcoded secrets       | Security best practice              |
| `.env`      | Removed Render-specific comments    | Clarify Railway compatibility       |
| `.env`      | Removed `RENDER_SERVICE_URL`        | Not needed for Railway              |
| `db.js`     | Added `DATABASE_URL` support        | Railway provides this automatically |
| `server.js` | Made dotenv conditional on NODE_ENV | Prevent issues in production        |

---

## No Changes Required In:

- ✅ `server.js` (PORT, health check, error handling already correct)
- ✅ `package.json` (start script already correct)
- ✅ All API key usage (already reading from process.env)
- ✅ Database query logic (no schema changes needed)
- ✅ Routes and endpoints (fully compatible with Railway)

---

## Deployment Steps

1. Ensure changes are committed and pushed to GitHub
2. In Railway dashboard:
   - Create new project
   - Connect your GitHub repository
   - Add PostgreSQL plugin
   - Set environment variables (see checklist above)
   - Deploy will happen automatically
3. Monitor logs in Railway dashboard
4. If database tables don't exist, they'll be created automatically on first run

---

## Troubleshooting

**Issue**: `DATABASE_URL is not defined`

- **Solution**: Verify PostgreSQL plugin is added to Railway project, or set individual `DB_*` variables

**Issue**: Port connection errors

- **Solution**: Railway automatically assigns PORT, ensure code reads `process.env.PORT` (✅ already done)

**Issue**: API keys not loading

- **Solution**: Verify environment variables are set in Railway dashboard (not in .env file)

**Issue**: Database connection timeout

- **Solution**: Ensure Railway PostgreSQL plugin is running and `DATABASE_URL` includes correct credentials

---

## Questions?

Refer to Railway documentation: https://docs.railway.app/
