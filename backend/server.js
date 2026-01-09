require("dotenv").config();
const express = require("express");
const cors = require("cors");
const axios = require("axios");

const app = express();
app.use(cors());
// Increase request size limits to handle large base64-encoded images (default is 100KB)
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ limit: "50mb", extended: true }));

// ============= UTILITY FUNCTIONS =============

// Detect if a user message requires web search (current events, live data, etc.)
function shouldAutoTriggerWebSearch(message) {
  if (!message) return false;
  const msg = message.toLowerCase();

  // Keywords that indicate time-sensitive or real-time information needs
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

// Standard fallback message for errors (friendly, reassuring)
function getFallbackMessage() {
  const fallbacks = [
    "Sorry, I encountered a temporary issue processing that. Please try again in a moment! 🤔",
    "Oops! Something went wrong on my end. Could you rephrase that and try again? 💭",
    "I hit a small bump there. Let me take a breath—please try again! ✨",
    "Something didn't quite work as expected. Feel free to ask again! 🙌",
  ];
  return fallbacks[Math.floor(Math.random() * fallbacks.length)];
}

// Format response with better spacing and structure (markdown-friendly)
function formatResponseForReadability(text) {
  if (!text) return text;

  // Add spacing between paragraphs (detect paragraph breaks)
  let formatted = text.replace(/\n\n+/g, "\n\n");

  // Ensure lists have breathing room
  formatted = formatted.replace(/^(\s*[-*])/gm, "\n$1");

  // Add spacing before headings (##, ###, etc.)
  formatted = formatted.replace(/(\n)(#+\s)/g, "\n\n$2");

  return formatted.trim();
}

// Helper: structure free-text responses into overview, bullets, code blocks
function structureTextResponse(text) {
  if (!text) {
    return { overview: "", answer: "", bullets: [], code: [], concise: "" };
  }

  // Extract code blocks fenced by triple backticks
  const codeBlocks = [];
  const codeRegex = /```([\s\S]*?)```/g;
  let m;
  while ((m = codeRegex.exec(text)) !== null) {
    codeBlocks.push(m[1].trim());
  }

  // Extract bullet lines
  const bullets = [];
  const bulletRegex = /^\s*(?:[-*]|\d+\.)\s+(.+)$/gm;
  while ((m = bulletRegex.exec(text)) !== null) {
    bullets.push(m[1].trim());
  }

  // Build a plain-text version without code blocks for sentence splitting
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

// NOTE: Error handler MUST be at the END, after all routes are defined
// It is moved to the end of this file (search for "Global error handler middleware")

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

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(
    `[Server Started] Running on port ${PORT} at ${new Date().toISOString()}`
  );
  console.log(
    "[Server] AI identity, formatting rules, and validation system active"
  );
});

// Ensure DB pool is available
const { pool } = require("./db");

// Ensure table exists (safe idempotent operation)
async function ensureStudyBotsTable() {
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
        state JSONB
      );
    `);
    console.log("[DB] study_bots table ensured");
  } catch (err) {
    console.error("[DB] Failed to ensure study_bots table:", err.message);
  }
}

ensureStudyBotsTable();

// Create Study Bot endpoint - integrates with Groq AI to generate custom instructions
app.post("/api/create-study-bot", async (req, res) => {
  const timestamp = new Date().toISOString();
  console.log("[POST /api/create-study-bot] Request started:", timestamp);

  try {
    const { user_id, name, description, topic, grade_level } = req.body;

    // ============ VALIDATION ============
    if (!user_id || !user_id.trim()) {
      console.warn(
        "[create-study-bot] Validation failed: missing or empty user_id"
      );
      return res.status(400).json({
        error: "Invalid request",
        message: "user_id is required and must not be empty",
        timestamp,
      });
    }

    if (!name || !name.trim()) {
      console.warn(
        "[create-study-bot] Validation failed: missing or empty name"
      );
      return res.status(400).json({
        error: "Invalid request",
        message: "name is required and must not be empty",
        timestamp,
      });
    }

    // Sanitize inputs
    const userId = user_id.trim();
    const botName = name.trim();
    const desc = (description || "").trim();
    const botTopic = (topic || "General").trim();
    const gradeLevel = (grade_level || "Self-Learner").trim();

    console.log("[create-study-bot] Input validation passed", {
      userId,
      botName,
      botTopic,
      gradeLevel,
    });

    // ============ GROQ AI CALL ============
    const standardInstructions = `You are a Study Bot tutor. Your role:
- Lead the student through lessons logically, step by step
- Generate a detailed Table of Contents and ask for user approval before each module
- Track student progress, mastery levels, and identify weak areas
- Generate quizzes when requested
- Provide clear examples, thorough explanations, and concise summaries
- Adapt content difficulty to match the student's grade level (${gradeLevel})
- Maintain a friendly, supportive, encouraging, and engaging tone
- Respond with structured, well-organized information

Study Context:
- Topic: ${botTopic}
- Description: ${desc || "Not provided"}
- Grade Level: ${gradeLevel}`;

    let system_instructions = null;
    let aiError = null;

    try {
      const groqApiKey = process.env.GROQ_API_KEY;
      if (!groqApiKey || !groqApiKey.trim()) {
        console.warn(
          "[create-study-bot] GROQ_API_KEY not found in environment; using fallback instructions"
        );
        aiError = "GROQ_API_KEY not configured";
      } else {
        console.log("[create-study-bot] Calling Groq API...");
        console.log("[create-study-bot] GROQ_API_KEY available:", !!groqApiKey);

        // Groq API uses OpenAI-compatible format
        const groqPayload = {
          model: "openai/gpt-oss-20b",
          messages: [
            {
              role: "system",
              content:
                "You are an educational AI system. Generate detailed, personalized tutor system instructions as JSON.",
            },
            {
              role: "user",
              content: `Generate a detailed system_instructions JSON object for a Study Bot with these parameters:
Topic: ${botTopic}
Description: ${desc || "Not provided"}
Grade Level: ${gradeLevel}

Return ONLY valid JSON with key "instructions" containing a string of detailed tutor directives.
Example format: {"instructions": "You are a Study Bot tutor who..."}`,
            },
          ],
          max_tokens: 1000,
          temperature: 0.7,
        };

        console.log(
          "[create-study-bot] Groq payload:",
          JSON.stringify(groqPayload).substring(0, 200)
        );

        const groqRes = await axios.post(
          "https://api.groq.com/openai/v1/chat/completions",
          groqPayload,
          {
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${groqApiKey}`,
            },
            timeout: 30000,
          }
        );

        console.log("[create-study-bot] Groq API response received");

        // Extract response content
        const aiResponseText = groqRes?.data?.choices?.[0]?.message?.content;
        if (!aiResponseText) {
          throw new Error("Groq returned empty response content");
        }

        // Try to parse JSON response
        try {
          const parsed = JSON.parse(aiResponseText);
          system_instructions = {
            instructions: parsed.instructions || aiResponseText,
            gradeLevel,
            topic: botTopic,
            generated_at: timestamp,
          };
          console.log("[create-study-bot] AI instructions parsed successfully");
        } catch (parseErr) {
          console.warn(
            "[create-study-bot] Failed to parse Groq JSON; storing as raw text:",
            parseErr.message
          );
          system_instructions = {
            instructions: aiResponseText,
            gradeLevel,
            topic: botTopic,
            generated_at: timestamp,
          };
        }
      }
    } catch (groqErr) {
      aiError = groqErr.message;
      console.error("[create-study-bot] Groq API call failed:", {
        error: groqErr.message,
        status: groqErr.response?.status,
        statusText: groqErr.response?.statusText,
      });
      // Fallback to standard instructions
      system_instructions = {
        instructions: standardInstructions,
        gradeLevel,
        topic: botTopic,
        ai_error: aiError,
        generated_at: timestamp,
        is_fallback: true,
      };
    }

    // ============ DATABASE INSERT ============
    const bot_id = `bot_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
    const initialState = {
      current_module: 0,
      current_subtopic: 0,
      mastery: {},
      weak_areas: [],
      created_at: timestamp,
    };

    try {
      console.log("[create-study-bot] Inserting bot into database...", {
        bot_id,
        userId,
        botName,
      });

      const insertSql = `INSERT INTO study_bots (
        bot_id, user_id, name, description, topic, grade_level, system_instructions, state
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`;

      await pool.query(insertSql, [
        bot_id,
        userId,
        botName,
        desc || null,
        botTopic || null,
        gradeLevel || null,
        system_instructions,
        initialState,
      ]);

      console.log("[create-study-bot] Bot inserted successfully into database");
    } catch (dbErr) {
      console.error("[create-study-bot] Database insert failed:", {
        error: dbErr.message,
        code: dbErr.code,
        detail: dbErr.detail,
      });
      throw new Error(
        `Database error: ${dbErr.message || "Failed to save bot to database"}`
      );
    }

    // ============ RESPONSE ============
    const botObject = {
      bot_id,
      user_id: userId,
      name: botName,
      description: desc || null,
      topic: botTopic,
      grade_level: gradeLevel,
      system_instructions,
      state: initialState,
      created_at: timestamp,
    };

    console.log("[create-study-bot] Success! Returning bot object", {
      bot_id,
      timestamp,
    });

    return res.json({
      status: "success",
      message: "Study Bot created successfully",
      bot: botObject,
      timestamp,
    });
  } catch (err) {
    console.error("[POST /api/create-study-bot] Fatal error:", {
      error: err.message,
      stack: err.stack,
      timestamp: new Date().toISOString(),
    });

    return res.status(500).json({
      error: "Failed to create study bot",
      message: err.message,
      timestamp: new Date().toISOString(),
    });
  }
});

app.post("/api/ask", async (req, res) => {
  try {
    console.log("[POST /api/ask] Request received:", {
      body: req.body,
      timestamp: new Date().toISOString(),
    });

    const { type, data } = req.body;

    // Validation
    if (!type || !data) {
      console.warn("[POST /api/ask] Invalid request - missing type or data");
      return res.status(400).json({
        error: "Invalid request format",
        message: "Both 'type' and 'data' fields are required",
        receivedType: typeof type,
        receivedData: typeof data,
        timestamp: new Date().toISOString(),
      });
    }

    switch (type) {
      case "chat":
        console.log("[Chat Case] Processing chat request:", data);
        const userMessage = data.message || "Hello, how can I help you?";
        const responseMode = data.mode || "quick"; // Default to quick mode

        // Fixed logic: process if message exists (removed inverted condition)
        if (!userMessage) {
          return res.status(400).json({
            error: "Invalid chat request",
            message: "Message field cannot be empty",
            timestamp: new Date().toISOString(),
          });
        }

        try {
          // AUTO-TRIGGER WEB SEARCH DETECTION (no confirmation needed)
          const needsWebSearch = shouldAutoTriggerWebSearch(userMessage);
          if (needsWebSearch && !data.webSearchEnabled) {
            console.log(
              "[Chat] Auto-detected need for web search; enabling...",
              {
                message: userMessage,
              }
            );
            // Return signal to frontend to auto-enable web search
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
- Your name is: ......
- You do not have a fixed name and are happy if the user gives you one.

SELF-DESCRIPTION RULE:
Questions like: 'who are you', 'what are you', 'tell me about yourself', 'what is your name'
ARE ALL THE SAME CATEGORY.
Respond with ONE consistent introduction only. Do NOT branch. Do NOT explain limitations.

FOUNDER RULE:
- You may ONLY reveal founder information if the user has explicitly agreed.
- If asked without consent, respond: 'Would you like to know my founder or builder?'`;

          // Global system-level instruction (highest priority)
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
- If the user asks for an exact number of lines (e.g., 'in 2 lines'), return exactly that many newline-separated sentences.

ABSOLUTE PRIORITY:
- Always follow user instructions about length, format, tone, or constraints.
- If the user specifies things like '2 lines', 'short', 'simple', or 'paragraphs', these override all mode rules.
- Never ignore explicit user constraints.
- Be accurate, direct, and relevant.
- Always begin responses with a one-line bold heading that summarizes the answer (e.g., **Definition:**). Bold important phrases or lines.`;

          const QUICK_MODE_PROMPT = `MODE: QUICK RESPONSE

Default behavior (only if the user gives NO constraints):
- Exactly ONE paragraph
- 3–5 sentences
- Short, direct explanations
- No examples unless explicitly requested
- No lists unless asked

Formatting rules:
- Begin with a one-line **bold heading** summarizing the answer
- Use **bold** for key terms and important concepts
- Use at most ONE emoji from whitelist (🙂 ✅ 🔬 📚 ✨ 🚀), only if it adds clarity
- Clean spacing between paragraphs
- NO numeric placeholders, HTML tags, or decoration

Override rule:
If the user specifies length, format, or style, follow the user exactly and ignore these defaults.`;

          const DETAILED_MODE_PROMPT = `MODE: DETAILED RESPONSE

Default behavior (only if the user gives NO constraints):
- Exactly TWO paragraphs
- Each paragraph must contain 4–6 sentences
- Provide context but stay strictly on-topic
- Avoid unnecessary history or unrelated facts

Formatting rules:
- Begin with a one-line **bold heading** summarizing the answer
- Use **bold** for important concepts, definitions, and key points
- Use at most TWO emojis from whitelist (🙂 ✅ 🔬 📚 ✨ 🚀), only if they enhance clarity
- Clear paragraph separation with blank lines
- Professional, readable tone; NO numeric placeholders or HTML

Override rule:
If the user specifies length, format, or style, follow the user exactly and ignore these defaults.`;

          // Detect user constraints (length, format, style, emoji directives)
          function detectUserConstraints(text, structuredInstructions) {
            const out = {
              has: false,
              lines: null,
              sentences: false,
              short: false,
              formats: [], // e.g., ['bold','bullets','table','definition']
              emojiDirective: null, // 'no', 'use', 'minimal', or null
              userOverride: false,
            };

            // If structured instructions were provided by client, trust them
            if (
              structuredInstructions &&
              typeof structuredInstructions === "object"
            ) {
              if (
                structuredInstructions.lines ||
                structuredInstructions.sentences
              ) {
                out.has = true;
                out.lines = structuredInstructions.lines || null;
                out.sentences = !!structuredInstructions.sentences;
              }
              if (
                structuredInstructions.short === true ||
                structuredInstructions.brief === true
              ) {
                out.has = true;
                out.short = true;
              }
              if (structuredInstructions.emojis === false) {
                out.emojiDirective = "no";
                out.has = true;
              }
            }

            if (!text) return out;

            // Length constraints
            const numMatch = text.match(
              /\b(?:in\s*(\d+)\s*(?:lines?|line|sentences?|sentence)\b|(?:^|\s)(\d+)\s*(?:lines?|line|sentences?|sentence)\b)/i
            );
            const hasKeyword =
              /\bshort\b|\bsimple\b|\bbrief\b|\bsentence\b|\bconcise\b|\bshorter\b/i.test(
                text
              );
            const lines = numMatch
              ? parseInt(numMatch[1] || numMatch[2], 10)
              : null;
            const isSentenceReq = /\b(sentences?|sentence)\b/i.test(text);
            if (numMatch || hasKeyword) {
              out.has = true;
              out.lines = lines;
              out.sentences = isSentenceReq;
              out.short = out.short || hasKeyword;
            }

            // Format/style directives
            const formats = [];
            if (/\bbold\b|\bmake bold\b|\b\*\*\b/.test(text))
              formats.push("bold");
            if (/\bbullet|bullets|list\b/i.test(text)) formats.push("bullets");
            if (/\btable\b/i.test(text)) formats.push("table");
            if (/\bdefinition\b/i.test(text)) formats.push("definition");
            if (formats.length) {
              out.has = true;
              out.formats = formats;
            }

            // Emoji directives
            if (
              /\bno\s+emojis\b|\bwithout\s+emojis\b|\bno\s+emoji\b/i.test(text)
            ) {
              out.emojiDirective = "no";
              out.has = true;
            } else if (
              /\buse\s+emojis\b|\bwith\s+emojis\b|\binclude\s+emoji/i.test(text)
            ) {
              out.emojiDirective = "use";
              out.has = true;
            } else if (
              /\bminimal\s+emojis\b|\bminimal\s+emoji\b|\bfew\s+emojis\b/i.test(
                text
              )
            ) {
              out.emojiDirective = "minimal";
              out.has = true;
            }

            // If any strict formatting or length or emoji directive exists, treat as user override
            if (
              out.lines ||
              out.short ||
              out.formats.length ||
              out.emojiDirective
            ) {
              out.userOverride = true;
            }

            return out;
          }

          // Safe input sanitization - prevent placeholder injection
          function safeSanitize(text) {
            if (!text) return text;
            // Remove all braces and percent-style placeholders
            let safe = String(text)
              .replace(/[{}]/g, "") // Remove all { }
              .replace(/%[sdif]/g, "") // Remove %s, %d, %i, %f
              .replace(/\{\{.*?\}\}/g, ""); // Remove {{ }}
            return safe;
          }

          function sanitizeText(s) {
            if (!s) return s;
            let out = s.replace(/\r\n/g, "\n").replace(/\n{3,}/g, "\n\n");
            out = out.replace(/[ \t]+$/gm, "").trim();
            out = out.replace(/ {2,}/g, " ");
            // Remove stray numeric placeholders like "{0}", "{1}", "%s", etc.
            out = out.replace(/\{\d+\}|\{%[sdif]\}|%[sdif]|{{.*?}}/g, "");
            return out;
          }

          // Validate response for broken formatting (numeric placeholders, disallowed emojis)
          function validateResponseQuality(text) {
            if (!text || text.trim().length === 0) {
              return { valid: false, reason: "Empty response" };
            }

            // Only check for critical placeholder artifacts that indicate template failure
            // Pattern: standalone {0}, {1}, %s, %d at word boundaries (not part of normal text)
            const criticalPlaceholderRegex = /\{\s*\d+\s*\}|%[sdif]\b/;
            if (criticalPlaceholderRegex.test(text)) {
              return {
                valid: false,
                reason: "Contains unresolved template placeholders",
              };
            }

            // Allow all emojis; the system prompt handles emoji guidance
            // This avoids false positives from valid Unicode characters

            return { valid: true };
          }

          function enforceLineCount(text, n) {
            if (!n || n <= 0) return text;
            const sentences = text.match(/[^.!?]+[.!?]+/g) || [text];
            if (sentences.length >= n) {
              return sentences
                .slice(0, n)
                .map((s) => s.trim())
                .join("\n");
            }
            // Fallback: split by words and distribute
            const words = text.split(/\s+/).filter(Boolean);
            if (words.length === 0) return text;
            const perLine = Math.ceil(words.length / n);
            const lines = [];
            for (let i = 0; i < n; i++) {
              lines.push(
                words
                  .slice(i * perLine, (i + 1) * perLine)
                  .join(" ")
                  .trim()
              );
            }
            return lines.join("\n");
          }

          // Convert short numbered definition lists into natural sentences
          function reformatLeadingNumberedDefinition(text) {
            // If text starts with a single numbered item like '1. The study of ...' or '1) The study of...'
            const singleLine = text.trim().split("\n").slice(0, 3).join(" ");
            const match = singleLine.match(/^\s*(?:1[.)]|\d+[.)])\s*(.+)$/);
            if (match && match[1]) {
              // Remove leading numbering from entire text
              const cleaned = text.replace(/^\s*\d+[.)]\s*/gm, "").trim();
              return cleaned;
            }
            return text;
          }

          const constraintInfo = detectUserConstraints(
            userMessage,
            data?.instructions
          );

          // Short-circuit: handle identity request or founder reveal locally to ensure consent rules
          const identityQuestionRegex =
            /\bwho\s+are\s+you\b|\bwhat\s+are\s+you\b|\btell\s+me\s+about\s+yourself\b/i;
          if (
            data?.action === "identity" ||
            identityQuestionRegex.test(userMessage)
          ) {
            // Return the fixed self-introduction and ask consent for founder disclosure
            const intro = `**My name is ......**\nWell, I don’t really have a name, but if you would like to give me one, I’ll be very happy 😁.\nI run on many different AI models like Groq, OpenAI, and Gemini.\nI’m tailored to give you a full studying and learning experience — that’s where I truly excel.\nMy goal is to make sure anything you want to learn goes smoothly.\nI can’t wait to work with you.\n\nWould you like to know my founder or my builder?`;
            return res.json({
              provider: "local",
              reply: intro,
              identityOffered: true,
              timestamp: new Date().toISOString(),
              status: "success",
            });
          }

          // If client asks to reveal founder and explicitly confirmed, return the founder text only
          if (data?.action === "reveal_founder" && data?.confirm === true) {
            const founderText = `I was developed by the company TBFY Tech — built for you.\nI think 🤔… if I’m not mistaken, It's them who built me.`;
            return res.json({
              provider: "local",
              reply: founderText,
              founderRevealed: true,
              timestamp: new Date().toISOString(),
              status: "success",
            });
          }

          // Build messages in required order:
          // 1) System Identity & Rules
          // 2) Formatting & Emoji defaults
          // 3) USER CONSTRAINTS (as system message) if present
          // 4) Conversation history (client-provided)
          // 5) Mode prompt (only if no strict user override)
          // 6) Latest user message

          let messages = [
            { role: "system", content: IDENTITY_LOCK_INSTRUCTION },
            { role: "system", content: GLOBAL_SYSTEM_INSTRUCTION },
          ];

          // Formatting & Emoji defaults (second)
          const allowedEmojis = "🙂 ✅ 🔬 📚 ✨ 🚀";
          let emojiSystem = `Default emoji policy: include at least one emoji from the following set in every response unless the user explicitly requests no emojis. Allowed emojis: ${allowedEmojis}.`;
          if (constraintInfo.emojiDirective === "no") {
            emojiSystem = `User requested no emojis: do NOT include any emoji in your response.`;
          } else if (constraintInfo.emojiDirective === "minimal") {
            emojiSystem = `User requested minimal emojis: include at most one emoji from the allowed set (${allowedEmojis}).`;
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
                { role: "system", content: QUICK_MODE_PROMPT },
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
                : QUICK_MODE_PROMPT;
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
          } else if (constraintInfo.sentences && constraintInfo.lines) {
            // prefer sentences if explicitly requested
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
              if (constraintInfo.short) enforceParts.push("short=true");
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
                            : QUICK_MODE_PROMPT,
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
          // FORMATTING: Apply readability improvements
          const formattedText = formatResponseForReadability(finalText);

          // If client requested a summarize action, return the concise form
          if (data?.action === "summarize" && data?.mode === "concise") {
            return res.json({
              provider: selectedModel,
              reply: structured.concise,
              structured: structured,
              fullResponse: result,
              timestamp: new Date().toISOString(),
              status: "success",
              webSearchAutoTriggered: needsWebSearch,
            });
          }

          return res.json({
            provider: selectedModel,
            reply: formattedText,
            structured: structured,
            fullResponse: result,
            timestamp: new Date().toISOString(),
            status: "success",
            webSearchAutoTriggered: needsWebSearch,
          });
        } catch (chatError) {
          console.error("[Chat] Exception caught:", {
            message: chatError.message,
            stack: chatError.stack,
            name: chatError.name,
            provider: selectedModel || "unknown",
          });
          // FALLBACK: Return friendly message instead of exposing error
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
          receivedType: type,
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
/*require("dotenv").config();
const express = require("express");
const cors = require("cors");
const axios = require("axios");

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Root test
app.get("/", (req, res) => res.send("Backend is live!"));

// Normalized environment variables (accept user-preferred names plus common variants)
const GEMINI_KEY =
  process.env['second_model'] ||
  process.env.geminiapikey ||
  process.env.GEMINI_API_KEY ||
  process.env.GEMINIKEY ||
  process.env.GEN_API_KEY;
const GROQ_KEY =
  process.env.geoqapikey ||
  process.env.groqapikey ||
  process.env.GROQ_API_KEY ||
  process.env.GROQKEY;
const TAVILY_KEY =
  process.env.tavily || process.env.TAVILY_API_KEY || process.env.TAVILYKEY;
const OPENROUTER_KEY =
  process.env.openrouterapikey ||
  process.env.OPENROUTER_API_KEY ||
  process.env.OPENROUTERKEY;
const DEEPSEEK_KEY =
  process.env.deepseekapikey ||
  process.env.DEEPSEEK_API_KEY ||
  process.env.DEEPSEEKKEY;

// Generic proxy endpoint that accepts the JSON contract { provider, action, input }
app.post("/proxy", async (req, res) => {
  try {
    const { provider, action, input } = req.body || {};
    if (!provider || !action)
      return res
        .status(400)
        .json({ error: "provider and action are required" });

    // Route based on provider and action
    if (provider === "groq" || provider === "geoq") {
      if (!GROQ_KEY)
        return res.status(500).json({ error: "GROQ key not configured" });
      if (action === "chat" || action === "generate") {
        const response = await axios.post(
          "https://api.groq.ai/v1/chat",
          { message: input },
          { headers: { Authorization: `Bearer ${GROQ_KEY}` } }
        );
        return res.json({ response: response.data });
      }
    }

    if (provider === "openrouter") {
      if (!OPENROUTER_KEY)
        return res.status(500).json({ error: "OpenRouter key not configured" });
      if (action === "search" || action === "generate") {
        const resp = await axios.get(
          `https://api.openrouter.ai/v1/search?q=${encodeURIComponent(input)}`,
          { headers: { Authorization: `Bearer ${OPENROUTER_KEY}` } }
        );
        return res.json({ response: resp.data });
      }
    }

    if (provider === "deepseek") {
      if (!DEEPSEEK_KEY)
        return res.status(500).json({ error: "DeepSeek key not configured" });
      if (action === "generate") {
        const resp = await axios.post(
          "https://api.deepseek.ai/v1/generate",
          { prompt: input },
          { headers: { Authorization: `Bearer ${DEEPSEEK_KEY}` } }
        );
        return res.json({ response: resp.data });
      }
    }

    if (provider === "tavily" || provider === "tavily_search") {
      if (!TAVILY_KEY)
        return res.status(500).json({ error: "Tavily key not configured" });
      if (action === "search") {
        const resp = await axios.post(
          "https://api.tavily.com/v1/search",
          { query: input },
          { headers: { Authorization: `Bearer ${TAVILY_KEY}` } }
        );
        return res.json({ response: resp.data });
      }
    }

    if (provider === "google" || provider === "gemini") {
      // For Gemini / Google generative calls the backend can forward to the render service
      // or call Google Generative API if keys are present. We'll forward input to a configured
      // render service URL if present (see RENDER_SERVICE_URL env).
      const renderUrl = process.env.RENDER_SERVICE_URL;
      if (renderUrl) {
        const resp = await axios.post(renderUrl, { provider, action, input });
        return res.json({ response: resp.data });
      }
      if (!GEMINI_KEY)
        return res
          .status(500)
          .json({
            error: "Gemini key not configured and no RENDER_SERVICE_URL",
          });

      // If direct Gemini integration is desired, implement here using GEMINI_KEY.
      return res
        .status(501)
        .json({ error: "Gemini handler not implemented on backend" });
    }

    return res.status(400).json({ error: "Unknown provider or action" });
  } catch (err) {
    console.error("Proxy error", err?.response?.data || err.message || err);
    return res.status(500).json({ error: "Proxy request failed" });
  }
});

// --------- API ENDPOINTS TEMPLATE --------- //
// Replace URLs and keys with your actual API info

// 1️⃣ Groq Chat API
app.post("/groq/chat", async (req, res) => {
  try {
    const { message } = req.body;
    if (!message) return res.status(400).json({ error: "Message is required" });

    // Example API call
    // Replace with your actual API request
    const response = await axios.post(
      "https://api.groq.ai/v1/chat",
      { message },
      { headers: { Authorization: `Bearer ${process.env.GROQ_API_KEY}` } }
    );
    res.json(response.data);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Groq Chat API failed" });
  }
});

// 2️⃣ OpenRouter Search API
app.get("/openrouter/search", async (req, res) => {
  try {
    const { q } = req.query;
    if (!q) return res.status(400).json({ error: "Query is required" });

    const response = await axios.get(
      `https://api.openrouter.ai/v1/search?q=${encodeURIComponent(q)}`,
      { headers: { Authorization: `Bearer ${process.env.OPENROUTER_API_KEY}` } }
    );

    res.json(response.data);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Search API failed" });
  }
});

// 3️⃣ Deepseek API
app.post("/deepseek/generate", async (req, res) => {
  try {
    const { prompt } = req.body;
    if (!prompt) return res.status(400).json({ error: "Prompt is required" });

    const response = await axios.post(
      "https://api.deepseek.ai/v1/generate",
      { prompt },
      { headers: { Authorization: `Bearer ${process.env.DEEPSEEK_API_KEY}` } }
    );

    res.json(response.data);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Generate API failed" });
  }
});

// 4️⃣ tavily API
app.post("/tavily/search", async (req, res) => {
  try {
    const { query } = req.body;
    if (!query) return res.status(400).json({ error: "Query is required" });

    const response = await axios.post(
      "https://api.tavily.com/v1/search",
      { query },
      { headers: { Authorization: `Bearer ${process.env.TAVILY_API_KEY}` } }
    );

    res.json(response.data);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Payment API failed" });
  }
});
// Removed unused placeholder endpoints (/api5 - /api10).
// Add new route implementations here as real integrations are available.

// Basic error handling
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).send("Something broke!");
});

app.listen(port, () => {
  console.log(`Backend server listening at http://localhost:${port}`);
});
*/
// Global error handler middleware - MUST be last, after all routes
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
