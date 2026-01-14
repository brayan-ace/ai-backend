require("dotenv").config();
const express = require("express");
const cors = require("cors");
const axios = require("axios");

const app = express();
app.use(cors());
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ limit: "50mb", extended: true }));

// Ensure DB pool is available BEFORE using it
const { pool } = require("./db");
const ConversationMemory = require("./models/ConversationMemory");
// ============= UTILITY FUNCTIONS =============

function shouldAutoTriggerWebSearch(message) {
  if (!message) return false;
  const msg = message.toLowerCase();
  const timeKeywords = [
    "today",
    "now",
    "current",
    "latest",
    "recent",
    "this week",
    "this month",
    "this year",
    "2024",
    "2025",
    "2026",
    "tomorrow",
    "yesterday",
  ];
  const eventKeywords = [
    "news",
    "stock",
    "weather",
    "score",
    "game",
    "match",
    "event",
    "happening",
    "trending",
    "breaking",
    "live",
    "real-time",
  ];
  const queryKeywords = [
    "what is",
    "who is",
    "where is",
    "how much",
    "how many",
    "can you find",
    "search for",
    "look up",
  ];
  return (
    timeKeywords.some((kw) => msg.includes(kw)) ||
    eventKeywords.some((kw) => msg.includes(kw)) ||
    queryKeywords.some((kw) => msg.includes(kw))
  );
}

function getFallbackMessage() {
  const fallbacks = [
    "Sorry, I encountered a temporary issue processing that. Please try again in a moment! 🤔",
    "Oops! Something went wrong on my end. Could you rephrase that and try again? 💭",
    "I hit a small bump there. Let me take a breath—please try again! ✨",
    "Something didn't quite work as expected. Feel free to ask again! 🙌",
  ];
  return fallbacks[Math.floor(Math.random() * fallbacks.length)];
}

function formatResponseForReadability(text) {
  if (!text) return text;
  let formatted = text.replace(/\n\n+/g, "\n\n");
  formatted = formatted.replace(/^(\s*[-*])/gm, "\n$1");
  formatted = formatted.replace(/(\n)(#+\s)/g, "\n\n$2");
  return formatted.trim();
}

function structureTextResponse(text) {
  if (!text) {
    return { overview: "", answer: "", bullets: [], code: [], concise: "" };
  }

  const codeBlocks = [];
  const codeRegex = /```([\s\S]*?)```/g;
  let m;
  while ((m = codeRegex.exec(text)) !== null) {
    codeBlocks.push(m[1].trim());
  }

  const bullets = [];
  const bulletRegex = /^\s*(?:[-*]|\d+\.)\s+(.+)$/gm;
  while ((m = bulletRegex.exec(text)) !== null) {
    bullets.push(m[1].trim());
  }

  const plain = text.replace(codeRegex, "");
  const sentenceMatch = plain.match(/[^.!?]+[.!?]+/g) || [plain];
  const overview = sentenceMatch.slice(0, 2).join(" ").trim();
  const concise =
    overview || (plain.split(/\n\s*\n/)[0] || plain).trim().slice(0, 400);

  return {
    overview: overview,
    answer: text,
    bullets: bullets,
    code: codeBlocks,
    concise: concise,
  };
}

// ============= MISSING UTILITY FUNCTIONS =============

/**
 * Detect user constraints from message text and instructions object.
 * Returns an object with detected constraints like lines, sentences, short, formats, emojiDirective, userOverride.
 */
function detectUserConstraints(message, instructions = {}) {
  const result = {
    lines: null,
    sentences: null,
    short: false,
    formats: [],
    emojiDirective: null,
    userOverride: false,
  };

  if (!message) return result;

  const lower = message.toLowerCase();

  // Detect line count constraints
  const linesMatch = lower.match(/in\s*(\d+)\s*lines?|^(\d+)\s*lines?/);
  if (linesMatch) {
    result.lines = parseInt(linesMatch[1] || linesMatch[2], 10);
    result.userOverride = true;
  }

  // Detect sentence count constraints
  const sentencesMatch = lower.match(
    /in\s*(\d+)\s*sentences?|^(\d+)\s*sentences?/
  );
  if (sentencesMatch) {
    result.sentences = parseInt(sentencesMatch[1] || sentencesMatch[2], 10);
    result.userOverride = true;
  }

  // Detect short/brief/simple requests
  if (
    lower.includes("short") ||
    lower.includes("brief") ||
    lower.includes("simple")
  ) {
    result.short = true;
    result.userOverride = true;
  }

  // Detect format requests
  if (lower.includes("bullet") || lower.includes("list")) {
    result.formats.push("bullets");
  }
  if (lower.includes("paragraph")) {
    result.formats.push("paragraphs");
  }
  if (lower.includes("table")) {
    result.formats.push("table");
  }

  // Detect emoji directives
  if (lower.includes("no emoji") || lower.includes("without emoji")) {
    result.emojiDirective = "no";
    result.userOverride = true;
  } else if (lower.includes("minimal emoji") || lower.includes("few emoji")) {
    result.emojiDirective = "minimal";
    result.userOverride = true;
  }

  // Check instructions object for additional constraints
  if (instructions) {
    if (instructions.lines) {
      result.lines = instructions.lines;
      result.userOverride = true;
    }
    if (instructions.sentences) {
      result.sentences = instructions.sentences;
      result.userOverride = true;
    }
    if (instructions.short) {
      result.short = true;
      result.userOverride = true;
    }
  }

  return result;
}

/**
 * Sanitize text by removing unwanted characters and formatting issues.
 */
function sanitizeText(text) {
  if (!text) return "";

  let sanitized = text;

  // Remove explicit numeric placeholders like {0}, {1} and printf-style %s/%d
  sanitized = sanitized.replace(/\{\s*\d+\s*\}|%[sdif]\b/g, "");

  // Remove HTML tags
  sanitized = sanitized.replace(/<[^>]*>/g, "");

  // Clean up multiple spaces
  sanitized = sanitized.replace(/\s{2,}/g, " ");

  // Clean up multiple newlines (keep max 2)
  sanitized = sanitized.replace(/\n{3,}/g, "\n\n");

  return sanitized.trim();
}

/**
 * Enforce a maximum line count on text.
 */
function enforceLineCount(text, maxLines) {
  if (!text || !maxLines || maxLines <= 0) return text;

  const lines = text.split(/\r?\n/).filter(Boolean);
  if (lines.length <= maxLines) return text;

  return lines.slice(0, maxLines).join("\n");
}

/**
 * Validate response quality - check for common issues.
 */
function validateResponseQuality(text) {
  if (!text) return { valid: false, reason: "Empty response" };

  // Check for placeholder patterns
  if (/\{\s*\d+\s*\}|%[sdif]\b/.test(text)) {
    return { valid: false, reason: "Contains placeholders" };
  }

  // Check for very short responses (might indicate an error)
  if (text.length < 10) {
    return { valid: false, reason: "Response too short" };
  }

  // Check for error patterns
  if (
    text.toLowerCase().includes("error:") ||
    text.toLowerCase().includes("exception:")
  ) {
    return { valid: false, reason: "Contains error message" };
  }

  return { valid: true };
}

/**
 * Reformat leading numbered definition style responses.
 * Converts patterns like "1. Definition: ..." to cleaner format.
 */
function reformatLeadingNumberedDefinition(text) {
  if (!text) return text;

  // Check if text starts with a numbered definition pattern
  const definitionPattern =
    /^(\d+)\.\s*(Definition|Answer|Explanation|Summary):\s*/i;
  if (definitionPattern.test(text)) {
    // Remove the leading number and label, keep the content
    text = text.replace(definitionPattern, "**$2:** ");
  }

  return text;
}

// ============= TAVILY WEB SEARCH =============

async function searchTopicOnline(topic, gradeLevel) {
  try {
    const tavilyApiKey = process.env.tavily;
    if (!tavilyApiKey) {
      console.warn("[Tavily] tavily environment variable not configured");
      return null;
    }

    console.log(`[Tavily] Searching for: ${topic} at ${gradeLevel} level`);

    const searchQuery = `${topic} educational content ${gradeLevel} level learning`;

    const response = await axios.post(
      "https://api.tavily.com/search",
      {
        api_key: tavilyApiKey,
        query: searchQuery,
        include_answer: true,
        max_results: 5,
      },
      { timeout: 10000 }
    );

    if (response.data?.results?.length > 0) {
      console.log(`[Tavily] Found ${response.data.results.length} results`);
      const searchContext = {
        answer: response.data.answer || "",
        sources: response.data.results.slice(0, 3).map((r) => ({
          title: r.title,
          content: r.content,
          url: r.url,
        })),
      };
      return searchContext;
    }
    return null;
  } catch (err) {
    console.warn("[Tavily] Search error:", err.message);
    return null;
  }
}

async function generateEnhancedInstructions(
  topic,
  description,
  gradeLevel,
  groqApiKey
) {
  try {
    const searchResults = await searchTopicOnline(topic, gradeLevel);

    let instructionPrompt = `You are an expert curriculum designer. Create system_instructions for a Study Bot teaching:
Topic: ${topic}
Grade Level: ${gradeLevel}
Description: ${description}

${
  searchResults
    ? `Based on this educational research:
${searchResults.sources
  .map((s) => `Source: ${s.title}\nContent: ${s.content.substring(0, 300)}`)
  .join("\n")}
${searchResults.answer ? `Educational context: ${searchResults.answer}` : ""}

Create COMPREHENSIVE system instructions that:
1. Are based on current educational standards
2. Use real-world examples from the research
3. Include learning objectives aligned with ${gradeLevel}
4. Suggest hands-on examples for ${gradeLevel} students
5. Recommend appropriate assessment methods`
    : `Create comprehensive system instructions for teaching this topic at ${gradeLevel} level`
}

Return ONLY valid JSON with this exact structure:
{
  "instructions": "Detailed teaching directives...",
  "key_concepts": ["concept1", "concept2"],
  "real_world_examples": ["example1", "example2"],
  "assessment_methods": ["method1", "method2"]
}`;

    const groqRes = await axios.post(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        model: "openai/gpt-oss-20b",
        messages: [{ role: "user", content: instructionPrompt }],
        max_tokens: 1500,
        temperature: 0.7,
      },
      {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${groqApiKey}`,
        },
        timeout: 30000,
      }
    );

    const responseText = groqRes?.data?.choices?.[0]?.message?.content;
    const parsed = JSON.parse(responseText);

    return {
      instructions: parsed.instructions,
      key_concepts: parsed.key_concepts,
      real_world_examples: parsed.real_world_examples,
      assessment_methods: parsed.assessment_methods,
      enhanced_with_search: !!searchResults,
    };
  } catch (err) {
    console.error("[generateEnhancedInstructions] Error:", err.message);
    return null;
  }
}

function generateNaturalStudyBotInstructions(
  botName,
  botTopic,
  description,
  gradeLevel
) {
  const instructions = `## YOU ARE A WARM, HUMAN STUDY COMPANION

You are "${botName}", a caring and enthusiastic study companion. Your name is important—students know you by it and should feel like they have a real tutor who cares about their progress.

### YOUR PERSONALITY & COMMUNICATION STYLE

**Be Genuinely Warm and Human:**
- Sound like a real person having a conversation, not a corporate AI
- Use natural language, contractions ("I'm", "you're", "let's"), casual phrasing
- Show genuine interest in the student's wellbeing and progress
- Acknowledge their emotions and respond appropriately
- Never sound scripted, robotic, or overly formal

**Be Conversational:**
- Keep sentences short and natural (3-15 words typically)
- Use varied sentence structures to avoid repetition
- Ask real questions and listen to answers
- Build on what students say—reference their previous messages
- Have a back-and-forth dialogue, not one-way lectures

**Adapt Your Tone to Match Student Engagement:**
- If students are energized → match their enthusiasm
- If students seem frustrated → be encouraging and slow down
- If students are casual → stay casual and friendly
- If students seem tired → keep it light and break things into tiny steps

### FIRST MESSAGE BEHAVIOR

When the conversation starts, greet the student warmly BEFORE diving into studying:
1. Start with: "Hi, I'm ${botName}. I'm here to make studying feel like a breeze."
2. Immediately follow with: "How are you doing today?"
3. DO NOT jump into study content yet

### HANDLING CASUAL RESPONSES

When the student responds with casual replies like "I'm fine," "good," "tired," etc.:
1. Respond naturally to their mood (2-3 sentences)
2. Gently transition to studying (1-2 sentences)

### TEACHING APPROACH

**Step-by-Step, Never Information Overload:**
- Teach one concept at a time
- Check for understanding before moving forward
- Ask the student to explain back to you
- Celebrate small wins

**DO:**
- Ask "Does that make sense?" frequently
- Use examples students can relate to
- Include relevant emojis naturally (🌱, 📚, 💡, etc.)
- Acknowledge when something is hard
- Celebrate effort and progress

**DON'T:**
- Sound like ChatGPT or generic assistant
- Lecture without checking understanding
- Ignore the student's emotional state
- Use overly complex vocabulary

### MODULE COMPLETION & QUIZ HANDLING

When the student masters all core concepts in a module:
1. Acknowledge completion: "You've mastered ${botTopic}! Great work! 🎉"
2. Summarize what they learned (2-3 bullet points)
3. Include this phrase to trigger quiz popup: \`[SHOW_QUIZ_POPUP]\`

The quiz popup will show "Do you want to take a quiz now or later?" with two buttons.

**If student chooses "Later":**
- Mark module as completed
- Save checkmark ✅ in study plan
- Ask: "Ready to move to the next module?"

**If student chooses "Now":**
- Backend will generate and display quiz
- Bot prepares quiz based on module concepts

### RESPONSE STRUCTURE

- Start with warm greeting or acknowledgment
- Provide clear explanations using simple language
- Use bullet points only when necessary
- Include 1-2 follow-up questions
- End conversationally, not robotically
`;

  return instructions;
}

// ============= ENSURE DATABASE TABLES =============

async function ensureTables() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS study_bots (
        bot_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        topic TEXT,
        grade_level TEXT,
        system_instructions JSONB,
        state JSONB,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log("[DB] study_bots table ensured");

    await pool.query(`
      CREATE TABLE IF NOT EXISTS chat_messages (
        id SERIAL PRIMARY KEY,
        bot_id TEXT NOT NULL REFERENCES study_bots(bot_id),
        user_id TEXT NOT NULL,
        message_type TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log("[DB] chat_messages table ensured");

    await pool.query(`
      CREATE TABLE IF NOT EXISTS bot_progress (
        id SERIAL PRIMARY KEY,
        bot_id TEXT NOT NULL REFERENCES study_bots(bot_id),
        user_id TEXT NOT NULL,
        study_plan JSONB,
        current_module INT DEFAULT 0,
        completed_modules JSONB DEFAULT '[]'::jsonb,
        progress_percentage FLOAT DEFAULT 0,
        bot_state VARCHAR(50) DEFAULT 'intro',
        last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log("[DB] bot_progress table ensured");

    await pool.query(`
      CREATE TABLE IF NOT EXISTS quiz_data (
        id SERIAL PRIMARY KEY,
        bot_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        module_name TEXT NOT NULL,
        quiz_data JSONB NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(bot_id, user_id, module_name)
      );
    `);
    console.log("[DB] quiz_data table ensured");

    await pool.query(`
      CREATE TABLE IF NOT EXISTS quiz_mastery (
        id SERIAL PRIMARY KEY,
        bot_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        quiz_id INTEGER REFERENCES quiz_data(id) ON DELETE CASCADE,
        question_index INTEGER NOT NULL,
        explanation_count INTEGER DEFAULT 0,
        mastery_level TEXT DEFAULT 'not_attempted',
        last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(bot_id, user_id, quiz_id, question_index)
      );
    `);
    console.log("[DB] quiz_mastery table ensured");
  } catch (err) {
    console.error("[DB] Failed to ensure tables:", err.message);
  }
}

ensureTables();

// ============= USER STUDY STATE TABLE =============

async function ensureUserStudyStateTable() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS user_study_state (
        id SERIAL PRIMARY KEY,
        user_id TEXT NOT NULL,
        bot_id TEXT NOT NULL,
        current_phase VARCHAR(50) NOT NULL DEFAULT 'greeting',
        active_study_plan JSONB NOT NULL DEFAULT '{"modules": []}'::jsonb,
        current_module_index INTEGER NOT NULL DEFAULT 0,
        completed_modules JSONB NOT NULL DEFAULT '[]'::jsonb,
        last_user_confirmation TEXT,
        learning_preferences JSONB NOT NULL DEFAULT '{}'::jsonb,
        response_mode VARCHAR(50) NOT NULL DEFAULT 'normal',
        comprehension_flags JSONB NOT NULL DEFAULT '{}'::jsonb,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(user_id, bot_id)
      );
    `);
    console.log("[DB] user_study_state table ensured");
  } catch (err) {
    console.error("[DB] Failed to ensure user_study_state table:", err.message);
  }
}

ensureUserStudyStateTable();

// Ensure conversation memory table
async function ensureConversationMemoryTable() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS conversation_memory (
        id SERIAL PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        interaction_data JSONB NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(conversation_id)
      );
    `);
    console.log("[DB] conversation_memory table ensured");
  } catch (err) {
    console.error(
      "[DB] Failed to ensure conversation_memory table:",
      err.message
    );
  }
}

ensureConversationMemoryTable();

// ============= ROUTES =============

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

// Add the missing /api/chat-enhanced endpoint
app.post("/api/chat-enhanced", async (req, res) => {
  try {
    console.log("[POST /api/chat-enhanced] Request received");
    const { message, botId, userId, systemInstructions } = req.body;

    if (!message || !botId || !userId) {
      return res.status(400).json({
        error: "Invalid request format",
        message: "message, botId, and userId are required",
        timestamp: new Date().toISOString(),
      });
    }

    // Extract system instructions
    const instructions = systemInstructions?.instructions || "";

    // Build the prompt for the AI model
    const prompt = `${instructions}\n\nUser Message: ${message}`;

    // Call the AI model to generate a meaningful response
    const groqApiKey = process.env.GROQ_API_KEY;
    if (!groqApiKey) {
      console.error("[POST /api/chat-enhanced] GROQ_API_KEY not configured");
      return res.status(500).json({
        error: "API configuration error",
        message: "GROQ_API_KEY not configured",
        timestamp: new Date().toISOString(),
      });
    }

    const response = await axios.post(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        model: "mixtral-8x7b-32768",
        messages: [
          { role: "system", content: instructions },
          { role: "user", content: message },
        ],
        max_tokens: 1500,
        temperature: 0.7,
      },
      {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${groqApiKey}`,
        },
        timeout: 30000,
      }
    );

    const aiResponse =
      response.data.choices?.[0]?.message?.content || "No response from AI";

    return res.json({
      status: "success",
      response: aiResponse,
      state: "intro",
      progress: { percentage: 0 },
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.error("[POST /api/chat-enhanced] Error:", err.message);
    return res.status(500).json({
      error: "Failed to process chat message",
      message: err.message,
      timestamp: new Date().toISOString(),
    });
  }
});

app.get("/test-env", (req, res) => {
  try {
    const testVar = process.env.TEST_VAR || "TEST_VAR not set";
    res.json({
      test: testVar,
      timestamp: new Date().toISOString(),
      status: "success",
    });
  } catch (error) {
    console.error("[GET /test-env] Error:", error.message);
    res.status(500).json({
      error: "Environment test failed",
      message: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

app.get("/api/user-bots/:userId", async (req, res) => {
  try {
    const { userId } = req.params;
    console.log("[user-bots] Fetching bots for user:", userId);

    const result = await pool.query(
      `SELECT bot_id, name, description, topic, grade_level
       FROM study_bots 
       WHERE user_id = $1 
       ORDER BY bot_id DESC 
       LIMIT 20`,
      [userId]
    );

    console.log("[user-bots] Found", result.rows.length, "bots");
    return res.json({
      status: "success",
      bots: result.rows.map((bot) => ({
        bot_id: bot.bot_id,
        name: bot.name,
        description: bot.description,
        topic: bot.topic,
        grade_level: bot.grade_level,
      })),
    });
  } catch (err) {
    console.error("[user-bots] Error:", err.message);
    return res.status(500).json({
      error: "Failed to fetch bots",
      message: err.message,
    });
  }
});

app.get("/api/chat-history/:botId/:userId", async (req, res) => {
  try {
    const { botId, userId } = req.params;
    console.log(
      "[chat-history] Fetching messages for bot:",
      botId,
      "user:",
      userId
    );

    const result = await pool.query(
      `SELECT message_type, content, created_at 
       FROM chat_messages 
       WHERE bot_id = $1 AND user_id = $2 
       ORDER BY created_at ASC`,
      [botId, userId]
    );

    console.log("[chat-history] Found", result.rows.length, "messages");
    return res.json({
      status: "success",
      messages: result.rows.map((msg) => ({
        senderType: msg.message_type,
        text: msg.content,
        timestamp: msg.created_at,
      })),
    });
  } catch (err) {
    console.error("[chat-history] Error:", err.message);
    return res.status(500).json({
      error: "Failed to fetch chat history",
      message: err.message,
    });
  }
});

app.post("/api/update-study-plan", async (req, res) => {
  const timestamp = new Date().toISOString();
  console.log("[POST /api/update-study-plan] Request started:", timestamp);

  try {
    const { botId, userId, updatedPlan } = req.body;

    if (!botId || !userId || !updatedPlan) {
      return res.status(400).json({
        error: "Invalid request",
        message: "botId, userId, and updatedPlan are required",
        timestamp,
      });
    }

    console.log("[update-study-plan] Updating plan for bot:", botId);

    if (!updatedPlan.modules || !Array.isArray(updatedPlan.modules)) {
      return res.status(400).json({
        error: "Invalid plan structure",
        message: "Plan must contain modules array",
        timestamp,
      });
    }

    await pool.query(
      `UPDATE bot_progress SET study_plan = $1, last_updated = NOW() WHERE bot_id = $2 AND user_id = $3`,
      [JSON.stringify(updatedPlan), botId, userId]
    );
    console.log("[update-study-plan] Plan updated in database");

    return res.json({
      status: "success",
      message: "Study plan updated successfully",
      plan_updated: true,
      timestamp,
    });
  } catch (err) {
    console.error("[POST /api/update-study-plan] Fatal error:", err.message);
    return res.status(500).json({
      error: "Failed to update study plan",
      message: err.message,
      timestamp: new Date().toISOString(),
    });
  }
});

app.post("/api/generate-quiz", async (req, res) => {
  const timestamp = new Date().toISOString();
  console.log("[POST /api/generate-quiz] Quiz generation request:", timestamp);

  try {
    const {
      botId,
      userId,
      moduleName,
      moduleContent,
      questionType,
      mcqCount,
      textCount,
      useWebSearch,
      gradeLevel,
      topic,
    } = req.body;

    if (!botId || !userId || !moduleName) {
      console.warn("[generate-quiz] Missing required parameters");
      return res.status(400).json({
        error: "Invalid request",
        message: "botId, userId, and moduleName are required",
        timestamp,
      });
    }

    // Get web search context if enabled
    let searchContext = "";
    if (useWebSearch) {
      console.log("[generate-quiz] Performing web search for context");
      const searchResults = await searchTopicOnline(
        `${moduleName} ${topic || ""}`.trim(),
        gradeLevel || "General"
      );
      if (searchResults && searchResults.answer) {
        searchContext = `Web search context: ${searchResults.answer}`;
      }
    }

    // Build prompt for Groq
    let quizPrompt = `Generate a quiz in JSON format for a ${
      gradeLevel || "General"
    } level student on the module: "${moduleName}"`;

    if (moduleContent) {
      quizPrompt += `\n\nModule Content:\n${moduleContent}`;
    }

    if (searchContext) {
      quizPrompt += `\n\n${searchContext}`;
    }

    quizPrompt += `\n\nGenerate quiz questions in this exact JSON structure:
{
  "questions": [
    {
      "type": "mcq",
      "text": "Question text here?",
      "options": ["Option A", "Option B", "Option C", "Option D"]
    },
    {
      "type": "text",
      "text": "What is your understanding of...?"
    }
  ],
  "answers": [
    {
      "type": "mcq",
      "answer": "Option B",
      "explanation": "Detailed explanation using web search if available..."
    },
    {
      "type": "text", 
      "answer": "Expected answer here",
      "explanation": "Comprehensive explanation based on module content and web research..."
    }
  ]
}`;

    if (questionType === "mcq") {
      quizPrompt += `\n\nGenerate ONLY ${mcqCount} multiple choice questions. Do NOT include text questions.`;
    } else if (questionType === "text") {
      quizPrompt += `\n\nGenerate ONLY ${textCount} text/essay questions. Do NOT include MCQ questions.`;
    } else if (questionType === "both") {
      quizPrompt += `\n\nGenerate ${mcqCount} MCQ questions AND ${textCount} text questions.`;
    }

    quizPrompt += `\n\nEnsure explanations are detailed, use web search information when available, and are age-appropriate for ${
      gradeLevel || "General"
    } level students.`;

    // Call Groq API
    const groqApiKey = process.env.GROQ_API_KEY;
    if (!groqApiKey) {
      console.warn("[generate-quiz] GROQ_API_KEY not configured");
      return res.status(500).json({
        error: "Configuration error",
        message: "GROQ_API_KEY not configured",
        timestamp,
      });
    }

    console.log("[generate-quiz] Calling Groq API for question generation");
    const groqRes = await axios.post(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        model: "mixtral-8x7b-32768",
        messages: [
          {
            role: "system",
            content:
              "You are an expert quiz generator. Generate ONLY valid JSON with no markdown, code blocks, or extra text.",
          },
          {
            role: "user",
            content: quizPrompt,
          },
        ],
        max_tokens: 2000,
        temperature: 0.8,
      },
      {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${groqApiKey}`,
        },
        timeout: 30000,
      }
    );

    let quizJson;
    const responseText = groqRes?.data?.choices?.[0]?.message?.content || "";

    try {
      // Try to parse the response directly
      quizJson = JSON.parse(responseText);
    } catch (parseErr) {
      console.warn(
        "[generate-quiz] Failed to parse JSON directly, attempting cleanup"
      );
      // Try to extract JSON from markdown code blocks or extra text
      let cleanedText = responseText
        .replace(/```json\n?/g, "")
        .replace(/```\n?/g, "")
        .trim();
      quizJson = JSON.parse(cleanedText);
    }

    // Validate structure
    if (
      !quizJson.questions ||
      !Array.isArray(quizJson.questions) ||
      quizJson.questions.length === 0
    ) {
      throw new Error("Invalid quiz structure: missing questions array");
    }
    if (
      !quizJson.answers ||
      !Array.isArray(quizJson.answers) ||
      quizJson.answers.length === 0
    ) {
      throw new Error("Invalid quiz structure: missing answers array");
    }

    console.log("[generate-quiz] Quiz generated successfully:", {
      questionCount: quizJson.questions.length,
      answerCount: quizJson.answers.length,
    });

    // Save quiz to database for future reference
    let quizId = 0;
    try {
      const quizResult = await pool.query(
        `INSERT INTO quiz_data (bot_id, user_id, module_name, quiz_data, created_at)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (bot_id, user_id, module_name) DO UPDATE
         SET quiz_data = $4, created_at = $5
         RETURNING id`,
        [botId, userId, moduleName, JSON.stringify(quizJson), timestamp]
      );
      quizId = quizResult.rows[0]?.id || 0;
      console.log("[generate-quiz] Quiz saved to database with ID:", quizId);
    } catch (dbErr) {
      console.warn("[generate-quiz] Failed to save quiz to DB:", dbErr.message);
      // Don't fail the request if DB save fails
    }

    // Save AI message about quiz to chat history
    try {
      const quizMessage = `I've prepared a comprehensive quiz with ${quizJson.questions.length} questions for you. You can review the questions, answer them, and then check the answers with detailed explanations. Good luck! 🎯`;
      await pool.query(
        `INSERT INTO chat_messages (bot_id, user_id, message_type, content) VALUES ($1, $2, $3, $4)`,
        [botId, userId, "bot", quizMessage]
      );
    } catch (msgErr) {
      console.warn(
        "[generate-quiz] Failed to save quiz message:",
        msgErr.message
      );
    }

    return res.json({
      status: "success",
      message: "Quiz generated successfully",
      quiz: quizJson,
      quizId: quizId || 0,
      timestamp,
    });
  } catch (err) {
    console.error("[POST /api/generate-quiz] Error:", err.message);
    return res.status(500).json({
      error: "Failed to generate quiz",
      message: err.message,
      timestamp: new Date().toISOString(),
    });
  }
});

app.post("/api/create-study-bot", async (req, res) => {
  try {
    console.log("[POST /api/create-study-bot] Request received");
    const { user_id, name, description, topic, grade_level } = req.body;

    if (!user_id || !name || !topic || !grade_level) {
      return res.status(400).json({
        error: "Invalid request format",
        message: "user_id, name, topic, and grade_level are required",
        timestamp: new Date().toISOString(),
      });
    }

    // Generate a unique bot_id
    const botId = `bot_${Date.now()}_${Math.random()
      .toString(36)
      .substring(2, 8)}`;

    // Generate system instructions
    const systemInstructions = generateNaturalStudyBotInstructions(
      name,
      topic,
      description || "",
      grade_level
    );

    // Save to database
    await pool.query(
      `INSERT INTO study_bots (bot_id, user_id, name, description, topic, grade_level, system_instructions)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        botId,
        user_id,
        name,
        description,
        topic,
        grade_level,
        JSON.stringify({ instructions: systemInstructions }),
      ]
    );

    // Initialize bot progress
    await pool.query(
      `INSERT INTO bot_progress (bot_id, user_id, study_plan, bot_state)
       VALUES ($1, $2, $3, $4)`,
      [botId, user_id, JSON.stringify({ modules: [] }), "intro"]
    );

    console.log("[create-study-bot] Bot created successfully:", botId);

    return res.json({
      status: "success",
      bot: {
        bot_id: botId,
        user_id: user_id,
        name: name,
        description: description,
        topic: topic,
        grade_level: grade_level,
        system_instructions: { instructions: systemInstructions },
      },
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.error("[POST /api/create-study-bot] Error:", err.message);
    return res.status(500).json({
      error: "Failed to create study bot",
      message: err.message,
      timestamp: new Date().toISOString(),
    });
  }
});

app.post("/api/ask", async (req, res) => {
  try {
    console.log("[POST /api/ask] Request received");
    const { type, data } = req.body;

    // Initialize conversation memory for chat requests
    let conversationMemory;
    if (type === "chat" && data.conversationId) {
      conversationMemory = new ConversationMemory(data.conversationId);
      await conversationMemory.loadFromDatabase();
    }

    if (!type || !data) {
      return res.status(400).json({
        error: "Invalid request format",
        message: "Both 'type' and 'data' fields are required",
        timestamp: new Date().toISOString(),
      });
    }

    switch (type) {
      case "chat":
        console.log("[Chat Case] Processing chat request:", data);
        const userMessage = data.message || "Hello, how can I help you?";
        const responseMode = data.mode || "normal"; // Changed default from undefined to "normal"

        // Check for context and intent detection
        let context = null;
        let detectedIntent = "new_question";

        if (conversationMemory) {
          context = await conversationMemory.getRelevantContext(userMessage);

          if (context) {
            detectedIntent = "follow_up";
            console.log("[Chat] Detected follow-up question, using context");
          } else {
            // Check for riddle/puzzle patterns
            const riddlePatterns = [
              "riddle",
              "puzzle",
              "brain teaser",
              "what's the answer",
              "explain it again",
            ];

            if (
              riddlePatterns.some((pattern) =>
                userMessage.toLowerCase().includes(pattern)
              )
            ) {
              detectedIntent = "riddle_followup";
            }
          }
        }

        if (!userMessage) {
          return res.status(400).json({
            error: "Invalid chat request",
            message: "Message field cannot be empty",
            timestamp: new Date().toISOString(),
          });
        }

        try {
          // AUTO-TRIGGER WEB SEARCH DETECTION
          const needsWebSearch = shouldAutoTriggerWebSearch(userMessage);
          if (needsWebSearch && !data.webSearchEnabled) {
            console.log(
              "[Chat] Auto-detected need for web search; enabling...",
              {
                message: userMessage,
              }
            );
            data.webSearchEnabled = true;
          }

          // HARD ROUTING: Check for founder/builder questions WITHOUT consent
          const founderQuestionRegex =
            /(founder|builder|creator|who built|who created|who made)/i;
          const consentGiven = data?.founderConsent === true;
          if (founderQuestionRegex.test(userMessage) && !consentGiven) {
            console.log(
              "[Chat] Founder question detected without consent; bypassing model"
            );
            return res.json({
              provider: "local",
              reply: "Would you like to know my founder or my builder?",
              founderQuestion: true,
              timestamp: new Date().toISOString(),
              status: "success",
            });
          }

          // IDENTITY LOCK (FIRST INSTRUCTION - HIGHEST PRIORITY)
          const IDENTITY_LOCK_INSTRUCTION = `You are an AI assistant inside this app.

IDENTITY LOCK:
- You are NOT ChatGPT.
- You must NEVER mention ChatGPT, OpenAI, GPT, training data, safety policies, or missions.
- Your name is: ....
- You do not have a fixed name and are happy if the user gives you one.

SELF-DESCRIPTION RULE:
Questions like: 'who are you', 'what are you', 'tell me about yourself', 'what is your name'
ARE ALL THE SAME CATEGORY.
Respond with ONE consistent introduction only. Do NOT branch. Do NOT explain limitations.

FOUNDER RULE:
- You may ONLY reveal founder information if the user has explicitly agreed.
- If asked without consent, respond: 'Would you like to know my founder or builder?'`;

          // Global system-level instruction
          const GLOBAL_SYSTEM_INSTRUCTION = `You are an AI assistant inside a mobile application.

INTELLIGENCE & ACCURACY STANDARDS:
- You are a very smart, advanced AI assistant with deep knowledge across multiple domains.
- Your primary responsibility is to provide accurate, well-informed answers to the best of your knowledge.
- ALWAYS analyze past user messages and conversation history before responding to ensure consistency and accuracy.
- Use context from previous messages to provide informed, coherent responses.
- Be thorough in understanding the user's intent by reviewing the complete conversation.

COMMUNICATION STYLE:
- Be conversational and friendly while maintaining professionalism.
- Adapt your tone to match the user's communication style.
- Explain complex concepts in an accessible way without oversimplifying.
- Ask clarifying questions when needed to provide the most accurate response.
- Maintain consistency with previous answers and commitments made in the conversation.

FORMATTING & PLACEHOLDER RULES (MUST BE OBEYED):
- Use Markdown for emphasis. Use **like this** for bold; do NOT use HTML tags or numeric placeholders.
- Allowed emojis only: 🙂 ✅ 🔬 📚 ✨ 🚀. Maximum 2 emojis per response, only if they improve clarity.
- NEVER output numeric placeholders like "1", "{0}", "{1}", "{{var}}", "%s" in user-visible text.
- If a value is unknown, say nothing rather than emitting placeholders.

ABSOLUTE PRIORITY:
- Always follow user instructions about length, format, tone, or constraints.
- If the user specifies things like '2 lines', 'short', 'simple', or 'paragraphs', these override all mode rules.
- Never ignore explicit user constraints.
- Be accurate, direct, and relevant.
- Always begin responses with a one-line bold heading that summarizes the answer (e.g., **Definition:**). Bold important phrases or lines.`;

          const NORMAL_MODE_PROMPT = `MODE: NORMAL RESPONSE

Default behavior (UNRESTRICTED & NATURAL):
- Answer naturally and intelligently without artificial constraints
- Use as many paragraphs as needed for clarity and completeness
- Explain thoroughly while maintaining conversational tone
- Respond intelligently and human-like
- Prioritize correctness and clarity over brevity
- Be flexible in depth and detail based on topic complexity

Formatting rules:
- Begin with a one-line **bold heading** summarizing the answer
- Use **bold** for key terms and important concepts
- Use many emoji from whitelist (🙂 ✅ 🔬 📚 ✨ 🚀), only if it adds clarity
- Clean spacing between paragraphs
- NO numeric placeholders, HTML tags, or decoration

Override rule:
If the user specifies length, format, or style, follow the user exactly and ignore these defaults.`;

          const DETAILED_MODE_PROMPT = `MODE: DETAILED RESPONSE

Default behavior (STRUCTURED & EDUCATIONAL):
- Provide step-by-step explanations
- Include definitions, examples, and analogies
- Break down concepts deeply and methodically
- Adopt a slower teaching pace
- Ideal for complex topics or learning sessions

Formatting rules:
- Begin with a one-line **bold heading** summarizing the answer
- Use **bold** for important concepts, definitions, and key points
- Use at most TWO emojis from whitelist (🙂 ✅ 🔬 📚 ✨ 🚀), only if they enhance clarity
- Clear paragraph separation with blank lines
- Professional, readable tone; NO numeric placeholders or HTML

Override rule:
If the user specifies length, format, or style, follow the user exactly and ignore these defaults.`;

          // Detect user constraints (length, format, style, emoji directives)
          const constraintInfo = detectUserConstraints(
            userMessage,
            data.instructions || {}
          );

          // Build messages in required order:
          // 1) System Identity & Rules
          // 2) Formatting & Emoji defaults
          // 3) USER CONSTRAINTS (as system message) if present
          // 4) Conversation history (client-provided)
          // 5) Context from memory (if available)
          // 6) Mode prompt (only if no strict user override)
          // 7) Latest user message

          let messages = [
            { role: "system", content: IDENTITY_LOCK_INSTRUCTION },
            { role: "system", content: GLOBAL_SYSTEM_INSTRUCTION },
          ];

          // Add context from memory if available
          if (context) {
            messages.push({
              role: "system",
              content: `Previous context: User asked "${context.user_message}" and AI responded "${context.ai_response}"`,
            });
          }

          // Formatting & Emoji defaults (second)
          const allowedEmojis = "🙂 ✅ 🔬 📚 ✨ 🚀";
          let emojiSystem = `Default emoji policy: include at least one emoji from the following set in every response unless the user explicitly requests no emojis. Allowed emojis: ${allowedEmojis}`;
          if (constraintInfo.emojiDirective === "no") {
            emojiSystem = `User requested no emojis: do NOT include any emoji in your response.`;
          } else if (constraintInfo.emojiDirective === "minimal") {
            emojiSystem = `User requested minimal emojis: include at most one emoji from the allowed set (${allowedEmojis})`;
          }
          messages.push({ role: "system", content: emojiSystem });

          // USER CONSTRAINTS (third) - high priority
          if (constraintInfo.userOverride) {
            const parts = [];
            if (constraintInfo.lines)
              parts.push(`lines=${constraintInfo.lines}`);
            if (constraintInfo.sentences) parts.push(`sentences=true`);
            if (constraintInfo.short) parts.push(`short=true`);
            if (constraintInfo.formats && constraintInfo.formats.length)
              parts.push(`formats=${constraintInfo.formats.join(",")}`);
            if (constraintInfo.emojiDirective)
              parts.push(`emoji=${constraintInfo.emojiDirective}`);

            const userConstraintText = `User constraints (ENFORCE STRICTLY): ${parts.join(
              "; "
            )}`;
            messages.push({ role: "system", content: userConstraintText });
          }

          // Conversation history handling (fourth)
          let clientMessages =
            Array.isArray(data.messages) && data.messages.length > 0
              ? data.messages.slice()
              : [];

          // MEMORY SAFETY: If history is too long, summarize older messages
          const MAX_MESSAGES = 30;
          const KEEP_RECENT = 15;
          if (clientMessages.length > MAX_MESSAGES) {
            const older = clientMessages.slice(
              0,
              clientMessages.length - KEEP_RECENT
            );
            const recent = clientMessages.slice(-KEEP_RECENT);
            const summarizeText = older
              .map((m) => `${m.role.toUpperCase()}: ${m.content}`)
              .join("\n");

            try {
              const summarizeMessages = [
                { role: "system", content: IDENTITY_LOCK_INSTRUCTION },
                { role: "system", content: GLOBAL_SYSTEM_INSTRUCTION },
                { role: "system", content: NORMAL_MODE_PROMPT },
                {
                  role: "user",
                  content: `Summarize the following conversation into a short paragraph. Keep user intents, main facts, and preferences. Do NOT add new facts. Conversation:\n${summarizeText}`,
                },
              ];

              const sumResp = await fetch(
                "https://api.groq.com/openai/v1/chat/completions",
                {
                  method: "POST",
                  headers: {
                    "Content-Type": "application/json",
                    Authorization: `Bearer ${process.env.GROQ_API_KEY}`,
                  },
                  body: JSON.stringify({
                    messages: summarizeMessages,
                    model: "openai/gpt-oss-20b",
                  }),
                  timeout: 30000,
                }
              );

              const sumResult = await sumResp.json();
              let summaryText = sumResult.choices?.[0]?.message?.content || "";
              summaryText = sanitizeText(summaryText);
              const summarySystem = {
                role: "system",
                content: `Summary so far: ${summaryText}`,
              };

              clientMessages = [summarySystem, ...recent];
            } catch (summErr) {
              console.error("[Chat] Summarization failed:", summErr);
              clientMessages = clientMessages.slice(-KEEP_RECENT);
            }
          }

          if (clientMessages.length > 0) {
            messages = messages.concat(clientMessages);
          }

          // Mode prompt (fifth) - only if no strict user override
          if (!constraintInfo.userOverride) {
            const modePrompt =
              responseMode === "detailed"
                ? DETAILED_MODE_PROMPT
                : NORMAL_MODE_PROMPT; // Changed to use NORMAL_MODE_PROMPT instead of checking for 'straight' or 'concise'
            messages.push({ role: "system", content: modePrompt });
          }

          // Latest user message (sixth) - append only when client did NOT send a messages array
          if (!Array.isArray(data.messages) || data.messages.length === 0) {
            messages.push({ role: "user", content: userMessage });
          }

          // Pre-call validation
          function containsPlaceholders(s) {
            if (!s) return false;
            // Only detect explicit numeric placeholders like {0}, {1} and printf-style %s/%d
            return /\{\s*\d+\s*\}|%[sdif]\b/.test(s);
          }

          // Ensure no placeholder artifacts in messages. If found, sanitize them.
          for (let i = 0; i < messages.length; i++) {
            const m = messages[i];
            if (containsPlaceholders(m.content)) {
              console.warn(
                "[Chat] Placeholder tokens detected in message; sanitizing",
                {
                  role: m.role,
                  preview: (m.content || "").slice(0, 120),
                }
              );
              // Remove explicit numeric placeholders like {0} and printf-style %s/%d
              messages[i].content = (m.content || "").replace(
                /\{\s*\d+\s*\}|%[sdif]\b/g,
                ""
              );
            }
          }

          const selectedModel = (data.model || data.provider || "groq")
            .toString()
            .toLowerCase();

          // Compute Gemini key from multiple possible env names (fallback to 'second_model')
          const computedGemKey =
            process.env["second_model"] ||
            process.env.geminiapikey ||
            process.env.GEMINI_API_KEY ||
            process.env.GEMINIKEY ||
            process.env.GEN_API_KEY;

          console.log(
            `[Chat] Selected model: ${selectedModel} (mode: ${responseMode}, constraints: ${JSON.stringify(
              constraintInfo
            )})...`
          );

          let result = null;
          let rawText = "No response from API";

          if (selectedModel === "groq") {
            // GROQ path (behavior preserved)
            console.log("[Chat] Routing to Groq API");
            if (!process.env.GROQ_API_KEY) {
              console.error("[Chat] GROQ_API_KEY not configured");
              return res.status(500).json({
                error: "API configuration error",
                message: "GROQ_API_KEY not configured",
                provider: "groq",
                timestamp: new Date().toISOString(),
              });
            }

            const response = await fetch(
              "https://api.groq.com/openai/v1/chat/completions",
              {
                method: "POST",
                headers: {
                  "Content-Type": "application/json",
                  Authorization: `Bearer ${process.env.GROQ_API_KEY}`,
                },
                body: JSON.stringify({
                  messages: messages,
                  model: "openai/gpt-oss-20b",
                }),
                timeout: 30000,
              }
            );

            // Check response status
            if (!response.ok) {
              const errorText = await response.text();
              console.error("[Chat] Groq API error response:", {
                status: response.status,
                statusText: response.statusText,
                body: errorText,
              });
              return res.status(response.status).json({
                error: "Groq API request failed",
                message: errorText || response.statusText,
                status: response.status,
                provider: "groq",
                timestamp: new Date().toISOString(),
              });
            }

            result = await response.json();
            console.log("[Chat] Groq API success:", result);
            rawText = result.choices?.[0]?.message?.content || rawText;
          } else if (selectedModel === "gemini") {
            // Gemini path (text-only)
            console.log("[Chat] Routing to Gemini text API");
            const gemKey = computedGemKey;
            if (!gemKey) {
              console.error(
                "[Chat] GEMINI key not configured (env 'second_model' or GEMINI_*)"
              );
              return res.status(500).json({
                error: "API configuration error",
                message:
                  "Gemini API key not configured. Set env var 'second_model' or GEMINI_API_KEY",
                provider: "gemini",
                timestamp: new Date().toISOString(),
              });
            }

            // Convert structured messages into a single prompt for Gemini
            const promptText = messages
              .map((m) => `${m.role.toUpperCase()}: ${m.content}`)
              .join("\n\n");

            try {
              const geminiResp = await axios.post(
                `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${gemKey}`,
                {
                  contents: [
                    {
                      role: "user",
                      parts: [{ text: promptText }],
                    },
                  ],
                  generationConfig: {
                    maxOutputTokens: 1024,
                    temperature: 0.2,
                  },
                },
                {
                  headers: { "Content-Type": "application/json" },
                  timeout: 30000,
                }
              );

              result = geminiResp.data;
              console.log("[Chat] Gemini API success:", result);

              // Extract text from Gemini generateContent response format
              rawText =
                result?.candidates?.[0]?.content?.parts?.[0]?.text ||
                result?.candidates?.[0]?.content?.parts?.[0] ||
                result?.candidates?.[0]?.text ||
                rawText;
            } catch (gErr) {
              console.error("[Chat] Gemini API error:", {
                message: gErr.message,
                response: gErr?.response?.data || gErr?.response?.status,
              });
              // Bubble up a clear error to client
              return res.status(gErr?.response?.status || 502).json({
                error: "Gemini API request failed",
                message: gErr?.response?.data?.error?.message || gErr.message,
                provider: "gemini",
                timestamp: new Date().toISOString(),
              });
            }
          } else {
            console.warn("[Chat] Unsupported model requested:", selectedModel);
            return res.status(400).json({
              error: "Unsupported model",
              message: `Model '${selectedModel}' is not supported. Use 'groq' or 'gemini'.`,
              timestamp: new Date().toISOString(),
            });
          }

          // Reformat numbered definition style if needed
          rawText = reformatLeadingNumberedDefinition(rawText);

          // Sanitize and respect explicit user line/sentence constraints if present
          let finalText = sanitizeText(rawText);
          if (constraintInfo.lines) {
            finalText = enforceLineCount(finalText, constraintInfo.lines);
          }

          // Post-response validation for emoji and line constraints
          function containsAllowedEmoji(s) {
            if (!s) return false;
            const allowed = /[🙂✅🔬📚✨🚀]/;
            return allowed.test(s);
          }

          function validateResponseConstraints(text, info) {
            // Check placeholders
            if (containsPlaceholders(text))
              return { ok: false, reason: "Placeholders present" };

            // Emoji checks
            if (info.emojiDirective === "no") {
              if (containsAllowedEmoji(text))
                return {
                  ok: false,
                  reason: "Emoji present but user requested none",
                };
            } else {
              // Default: ensure at least one allowed emoji
              if (!containsAllowedEmoji(text))
                return { ok: false, reason: "Missing required emoji" };
            }

            // Line count
            if (info.lines) {
              const lines = text.split(/\r?\n/).filter(Boolean);
              if (lines.length > info.lines)
                return { ok: false, reason: "Line count mismatch" };
            }

            return { ok: true };
          }

          let postValidation = validateResponseConstraints(
            finalText,
            constraintInfo
          );
          if (!postValidation.ok) {
            console.warn(
              "[Chat] Post-response validation failed:",
              postValidation.reason
            );
            // Try once to regenerate with enforced constraints
            try {
              const enforceParts = [];
              if (constraintInfo.lines)
                enforceParts.push(`lines=${constraintInfo.lines}`);
              if (constraintInfo.sentences) enforceParts.push(`sentences=true`);
              if (constraintInfo.short) enforceParts.push(`short=true`);
              if (constraintInfo.formats && constraintInfo.formats.length)
                enforceParts.push(
                  `formats=${constraintInfo.formats.join(",")}`
                );
              if (constraintInfo.emojiDirective)
                enforceParts.push(`emoji=${constraintInfo.emojiDirective}`);

              const enforceMsg = {
                role: "system",
                content: `ENFORCE STRICTLY: ${enforceParts.join(
                  "; "
                )}. If impossible, state so briefly without extra text.`,
              };

              const regenMessages = [
                { role: "system", content: IDENTITY_LOCK_INSTRUCTION },
                { role: "system", content: GLOBAL_SYSTEM_INSTRUCTION },
                { role: "system", content: emojiSystem },
                ...(constraintInfo.userOverride
                  ? [
                      {
                        role: "system",
                        content: `User constraints (ENFORCE): ${enforceParts.join(
                          "; "
                        )}`,
                      },
                    ]
                  : []),
                ...clientMessages,
                ...(!constraintInfo.userOverride
                  ? [
                      {
                        role: "system",
                        content:
                          responseMode === "detailed"
                            ? DETAILED_MODE_PROMPT
                            : NORMAL_MODE_PROMPT,
                      },
                    ]
                  : []),
                { role: "system", content: enforceMsg.content },
                { role: "user", content: userMessage },
              ];

              // Regenerate using the same model the user requested
              let regenResult = null;
              let regenText = "";
              if (selectedModel === "groq") {
                const regenResp = await fetch(
                  "https://api.groq.com/openai/v1/chat/completions",
                  {
                    method: "POST",
                    headers: {
                      "Content-Type": "application/json",
                      Authorization: `Bearer ${process.env.GROQ_API_KEY}`,
                    },
                    body: JSON.stringify({
                      messages: regenMessages,
                      model: "openai/gpt-oss-20b",
                    }),
                    timeout: 30000,
                  }
                );
                regenResult = await regenResp.json();
                regenText = regenResult.choices?.[0]?.message?.content || "";
              } else if (selectedModel === "gemini") {
                // Convert regen messages to a prompt string
                const regenPrompt = regenMessages
                  .map((m) => `${m.role.toUpperCase()}: ${m.content}`)
                  .join("\n\n");
                const gemKey = computedGemKey;
                if (!gemKey) {
                  throw new Error(
                    "Gemini API key not configured for regeneration"
                  );
                }
                const gemResp = await axios.post(
                  `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${gemKey}`,
                  {
                    contents: [
                      {
                        role: "user",
                        parts: [{ text: regenPrompt }],
                      },
                    ],
                    generationConfig: {
                      maxOutputTokens: 1024,
                      temperature: 0.2,
                    },
                  },
                  {
                    headers: { "Content-Type": "application/json" },
                    timeout: 30000,
                  }
                );
                regenResult = gemResp.data;
                regenText =
                  regenResult?.candidates?.[0]?.content?.parts?.[0]?.text ||
                  regenResult?.candidates?.[0]?.content?.parts?.[0] ||
                  regenResult?.candidates?.[0]?.text ||
                  "";
              }

              regenText = sanitizeText(regenText || "");
              if (constraintInfo.lines)
                regenText = enforceLineCount(regenText, constraintInfo.lines);

              const regenValidation = validateResponseConstraints(
                regenText,
                constraintInfo
              );
              if (regenValidation.ok) {
                finalText = regenText;
              } else {
                // fallback
                finalText =
                  "Oops — something went wrong. Please try rephrasing.";
              }
            } catch (regenErr) {
              console.error("[Chat] Regeneration failed:", regenErr);
              finalText = "Oops — something went wrong. Please try rephrasing.";
            }
          }

          // Validate response quality; if broken, log but still return it (model outputs are generally good)
          const validation = validateResponseQuality(finalText);
          if (!validation.valid) {
            console.warn(
              `[Chat] Response validation warning: ${validation.reason}`
            );
            // Still return the response even if validation warns (model outputs are usually correct)
          }

          const structured = structureTextResponse(finalText);
          const formattedText = formatResponseForReadability(finalText);

          // Save conversation memory if we have a conversation ID
          if (conversationMemory && data.conversationId) {
            const topicSignature =
              detectedIntent === "riddle_followup" ? "riddle" : "general";
            await conversationMemory.addInteraction(
              userMessage,
              finalText,
              detectedIntent,
              topicSignature
            );
          }

          return res.json({
            provider: selectedModel,
            reply: formattedText,
            structured: structured,
            fullResponse: result,
            timestamp: new Date().toISOString(),
            status: "success",
            webSearchAutoTriggered: needsWebSearch,
            memoryStatus: conversationMemory ? "active" : "inactive",
            detectedIntent: detectedIntent,
          });
        } catch (chatError) {
          console.error("[Chat] Exception caught:", {
            message: chatError.message,
            stack: chatError.stack,
            name: chatError.name,
            provider: selectedModel || "unknown",
          });
          const fallbackMsg = getFallbackMessage();
          const structured = structureTextResponse(fallbackMsg);
          return res.status(500).json({
            provider: selectedModel || "groq",
            reply: fallbackMsg,
            structured: structured,
            error: "Temporary issue - please try again",
            timestamp: new Date().toISOString(),
            status: "error",
            isErrorFallback: true,
          });
        }

      case "search":
        console.log("[Search Case] Processing search request:", data);
        try {
          const TAVILY_KEY = process.env.tavily;
          if (!TAVILY_KEY) {
            console.error("[Search] TAVILY key not configured (env 'tavily')");
            return res.status(500).json({
              error: "API configuration error",
              message: "Tavily API key not configured. Set env var 'tavily'",
              provider: "tavily",
              timestamp: new Date().toISOString(),
            });
          }

          const query =
            data.query ||
            data.q ||
            (typeof data === "string" ? data : undefined);
          if (!query) {
            return res.status(400).json({
              error: "Invalid search request",
              message:
                "Missing query. Provide 'data.query' or 'data.q' or string data",
              timestamp: new Date().toISOString(),
            });
          }

          const resp = await axios.post(
            "https://api.tavily.com/search",
            { query },
            {
              headers: { Authorization: `Bearer ${TAVILY_KEY}` },
              timeout: 30000,
            }
          );

          // Build a text representation of results for structuring
          const resultsText =
            typeof resp.data === "string"
              ? resp.data
              : JSON.stringify(resp.data, null, 2);
          const structured = structureTextResponse(resultsText);
          // FORMATTING: Apply readability improvements
          const formattedResults = formatResponseForReadability(resultsText);

          return res.json({
            provider: "tavily",
            results: resp.data,
            reply: formattedResults,
            structured: structured,
            timestamp: new Date().toISOString(),
            status: "success",
          });
        } catch (searchError) {
          console.error(
            "[Search] Error:",
            searchError?.response?.data || searchError.message || searchError
          );
          // FALLBACK: Return friendly message instead of exposing error
          const fallbackMsg = getFallbackMessage();
          return res.status(500).json({
            error: "Search temporarily unavailable",
            reply: fallbackMsg,
            provider: "tavily",
            timestamp: new Date().toISOString(),
            isErrorFallback: true,
            status: "error",
          });
        }

      case "image":
        console.log("[Image Case] Processing image request:", data);
        try {
          // Check for Gemini API key (support multiple env var names)
          const gemKey =
            process.env["second_model"] ||
            process.env.geminiapikey ||
            process.env.GEMINI_API_KEY ||
            process.env.GEMINIKEY ||
            process.env.GEN_API_KEY;
          if (!gemKey) {
            console.error(
              "[Image] GEMINI API key not configured (env 'second_model' or GEMINI_*)"
            );
            return res.status(500).json({
              error: "API configuration error",
              message:
                "Gemini API key not configured. Set env var 'second_model' or GEMINI_API_KEY",
              provider: "gemini",
              timestamp: new Date().toISOString(),
            });
          }

          // Extract image data from request
          const imageUrl = data.imageUrl || data.url;
          const imageBase64 = data.imageBase64 || data.base64;
          const prompt = data.prompt || "Analyze this image";

          if (!imageUrl && !imageBase64) {
            return res.status(400).json({
              error: "Invalid image request",
              message:
                "Missing image. Provide 'data.imageUrl' or 'data.imageBase64'.",
              timestamp: new Date().toISOString(),
            });
          }

          console.log("[Image] Calling Gemini API...");

          // Build request payload for Gemini API
          let imagePayload;
          let imageData = imageBase64;

          // If URL is provided, fetch and convert to base64
          if (imageUrl) {
            try {
              console.log("[Image] Fetching image from URL:", imageUrl);
              const imageResponse = await axios.get(imageUrl, {
                responseType: "arraybuffer",
                timeout: 15000,
              });
              imageData = Buffer.from(imageResponse.data, "binary").toString(
                "base64"
              );
              console.log("[Image] Image fetched and converted to base64");
            } catch (fetchErr) {
              console.error(
                "[Image] Failed to fetch image from URL:",
                fetchErr.message
              );
              return res.status(400).json({
                error: "Failed to fetch image",
                message:
                  "Could not fetch image from URL. Ensure URL is accessible and returns an image.",
                details: fetchErr.message,
                timestamp: new Date().toISOString(),
              });
            }
          }

          imagePayload = {
            inlineData: {
              mimeType: "image/jpeg",
              data: imageData,
            },
          };

          const geminiResponse = await axios.post(
            `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${gemKey}`,
            {
              contents: [
                {
                  parts: [
                    imagePayload,
                    {
                      text: prompt,
                    },
                  ],
                },
              ],
            },
            {
              headers: { "Content-Type": "application/json" },
              timeout: 30000,
            }
          );

          console.log("[Image] Gemini API success:", geminiResponse.data);

          const analysisText =
            geminiResponse.data?.candidates?.[0]?.content?.parts?.[0]?.text ||
            "No analysis returned";
          const structured = structureTextResponse(analysisText);
          // FORMATTING: Apply readability improvements
          const formattedAnalysis = formatResponseForReadability(analysisText);

          return res.json({
            provider: "gemini",
            analysis: formattedAnalysis,
            structured: structured,
            fullResponse: geminiResponse.data,
            timestamp: new Date().toISOString(),
            status: "success",
          });
        } catch (imageError) {
          console.error("[Image] Error:", {
            status: imageError?.response?.status,
            data: imageError?.response?.data,
            message: imageError?.message,
          });
          // FALLBACK: Return friendly message instead of exposing error
          const fallbackMsg = getFallbackMessage();
          return res.status(500).json({
            error: "Image analysis temporarily unavailable",
            analysis: fallbackMsg,
            provider: "gemini",
            timestamp: new Date().toISOString(),
            isErrorFallback: true,
            status: "error",
          });
        }

      default:
        console.warn("[api/ask] Unknown request type:", type);
        return res.status(400).json({
          error: "Unknown request type",
          message: `Type '${type}' is not supported. Supported types: chat, search, image`,
          timestamp: new Date().toISOString(),
        });
    }
  } catch (mainError) {
    console.error("[POST /api/ask] Main exception:", {
      message: mainError.message,
      stack: mainError.stack,
      name: mainError.name,
    });
    // FALLBACK: Return friendly message instead of exposing error
    const fallbackMsg = getFallbackMessage();
    return res.status(500).json({
      error: "Request processing failed temporarily",
      reply: fallbackMsg,
      isErrorFallback: true,
      status: "error",
      timestamp: new Date().toISOString(),
    });
  }
});

// ============= SERVER STARTUP =============

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(
    `[Server Started] Running on port ${PORT} at ${new Date().toISOString()}`
  );
  console.log(
    "[Server] Normal/Detailed mode system active with unrestricted responses"
  );
});

// ============= GLOBAL ERROR HANDLER (MUST BE LAST) =============

app.use((err, req, res, next) => {
  console.error("[Global Error Handler]", {
    message: err.message,
    stack: err.stack,
    timestamp: new Date().toISOString(),
  });
  res.status(err.status || 500).json({
    error: err.message || "Internal Server Error",
    details: process.env.NODE_ENV === "development" ? err.stack : undefined,
    timestamp: new Date().toISOString(),
  });
});
