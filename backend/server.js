const {
  generatePremiumSystemInstructions,
} = require("./premium_system_instructions");
const { generateEnhancedQuizPrompt } = require("./enhanced_quiz_generator");

// Load .env only in development (Railway uses environment variables directly)
if (process.env.NODE_ENV !== "production") {
  require("dotenv").config();
}

const express = require("express");
const cors = require("cors");
const axios = require("axios");
const multer = require("multer");
const speech = require("@google-cloud/speech");
const fs = require("fs");
const path = require("path");

const app = express();
app.use(cors());
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ limit: "50mb", extended: true }));

// Ensure DB pool is available BEFORE using it
const { pool } = require("./db");
const ConversationMemory = require("./models/ConversationMemory");

// Ensure database tables are created
async function ensureDatabaseTables() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS user_study_state (
        id SERIAL PRIMARY KEY,
        user_id TEXT NOT NULL,
        bot_id TEXT NOT NULL,
        current_phase VARCHAR(50) NOT NULL DEFAULT 'greeting',
        active_study_plan JSONB NOT NULL DEFAULT '{"modules": []}'::jsonb,
        current_module_index INTEGER NOT NULL DEFAULT 0,
        current_concept_index INTEGER NOT NULL DEFAULT 0,
        completed_modules JSONB NOT NULL DEFAULT '[]'::jsonb,
        completed_concepts JSONB NOT NULL DEFAULT '[]'::jsonb,
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

    // Add concept tracking columns to bot_progress if they don't exist
    try {
      await pool.query(
        `ALTER TABLE bot_progress ADD COLUMN IF NOT EXISTS current_concept_index INTEGER DEFAULT 0`,
      );
      await pool.query(
        `ALTER TABLE bot_progress ADD COLUMN IF NOT EXISTS completed_concepts JSONB DEFAULT '[]'::jsonb`,
      );
      console.log("[DB] Concept tracking columns added to bot_progress");
    } catch (alterErr) {
      // Columns may already exist, that's fine
    }
  } catch (err) {
    console.error("[DB] Failed to ensure tables:", err.message);
  }
}

ensureDatabaseTables();
// ============= UTILITY FUNCTIONS =============

function shouldAutoTriggerWebSearch(message) {
  if (!message) return false;
  const msg = message.toLowerCase();
  const timeKeywords = ["today", "now", "current"];
  const eventKeywords = [
    "who is",
    "where is",
    "how much",
    "how many",
    "can you find",
    "search for",
    "look up",
  ];
  const queryKeywords = [
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
  // Preserve original formatting. Do not collapse newlines or trim.
  // This function was previously collapsing multiple newlines and trimming
  // which removed paragraph breaks and collapsed lists. Return the text
  // unchanged to ensure the frontend receives raw markdown as produced
  // by the model. Any lightweight normalization (CRLF -> LF) is safe.
  if (!text) return text;
  return text.replace(/\r\n/g, "\n");
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
    /in\s*(\d+)\s*sentences?|^(\d+)\s*sentences?/,
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
//set up multer for file uploads (for voice input)
const upload = multer({ dest: "uploads/" });
7;
/**
 * Sanitize text by removing unwanted characters and formatting issues.
 */
function sanitizeText(text) {
  if (!text) return "";

  // Only remove explicit numeric/printf placeholders. Do NOT strip HTML,
  // collapse whitespace, or trim — these operations destroy markdown and
  // LaTeX formatting (code blocks, lists, and paragraph spacing).
  // Leave the rest of the text intact so the frontend receives raw
  // markdown as produced by the model.
  return (text || "").replace(/\{\s*\d+\s*\}|%[sdif]\b/g, "");
}

/**
 * Normalize model responses to avoid escaped markdown artifacts and
 * ensure emojis and emphasis markers are preserved for the frontend.
 * - Convert literal escaped newlines ("\\n"/"\\r\\n") into real newlines
 * - Unescape backslash-escaped markdown characters (\* \` \$)
 * - Collapse runs of 3+ asterisks into a valid bold marker
 */
function normalizeModelResponse(text) {
  if (!text) return text;
  let t = text;

  // Convert escaped CRLF / LF sequences into real newlines
  t = t.replace(/\\r\\n/g, "\n");
  t = t.replace(/\\n/g, "\n");

  // Unescape common markdown escapes so **bold** markers are left intact
  t = t.replace(/\\\*/g, "*");
  t = t.replace(/\\`/g, "`");
  t = t.replace(/\\\$/g, "$");

  // Collapse accidental long asterisk runs into valid bold markers
  t = t.replace(/\*{3,}/g, "**");

  return t;
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

/**
 * Summarize conversation history to provide context for web searches.
 * This ensures Tavily searches are relevant to the ongoing conversation.
 * @param {Array} messages - Array of {role, content} message objects
 * @param {string} currentQuery - The current search query from the user
 * @returns {Promise<string>} - A concise summary + enhanced query for search
 */
async function summarizeConversationForSearch(messages, currentQuery) {
  try {
    const groqApiKey = process.env.GROQ_API_KEY;
    if (!groqApiKey || !messages || messages.length === 0) {
      return currentQuery; // Fallback to original query
    }

    // Take last 10 messages for context (to avoid token limits)
    const recentMessages = messages.slice(-10);
    const conversationText = recentMessages
      .map((m) => `${m.role.toUpperCase()}: ${m.content}`)
      .join("\n");

    console.log(
      "[Search Context] Summarizing conversation for search context...",
    );

    const response = await fetch(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${groqApiKey}`,
        },
        body: JSON.stringify({
          messages: [
            {
              role: "system",
              content: `You are a search query optimizer. Your task is to create an enhanced search query that combines the user's current search request with relevant context from their conversation.

RULES:
1. Output ONLY the enhanced search query - no explanations, no quotes, no prefixes
2. Keep it concise (under 100 words)
3. Include key topics, entities, and context from the conversation that are relevant to the search
4. Make it a natural search query that would return relevant results
5. If the conversation context isn't relevant to the search, just return the original query slightly improved`,
            },
            {
              role: "user",
              content: `CONVERSATION HISTORY:
${conversationText}

CURRENT SEARCH REQUEST: "${currentQuery}"

Create an enhanced search query that incorporates relevant conversation context:`,
            },
          ],
          model: "openai/gpt-oss-20b",
          max_tokens: 150,
          temperature: 0.3,
        }),
        timeout: 15000,
      },
    );

    if (!response.ok) {
      console.warn(
        "[Search Context] Failed to summarize, using original query",
      );
      return currentQuery;
    }

    const result = await response.json();
    const enhancedQuery =
      result.choices?.[0]?.message?.content?.trim() || currentQuery;

    console.log("[Search Context] Original query:", currentQuery);
    console.log("[Search Context] Enhanced query:", enhancedQuery);

    return enhancedQuery;
  } catch (err) {
    console.warn("[Search Context] Summarization error:", err.message);
    return currentQuery; // Fallback to original query
  }
}

async function searchTopicOnline(topic, gradeLevel) {
  try {
    const tavilyApiKey = process.env.TAVILY_API_KEY;
    if (!tavilyApiKey) {
      console.warn(
        "[Tavily] TAVILY_API_KEY environment variable not configured",
      );
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
      { timeout: 10000 },
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

async function enhanceSearchResultsWithAI(
  query,
  searchResults,
  conversationMessages = [],
) {
  try {
    const groqApiKey = process.env.GROQ_API_KEY;
    if (!groqApiKey) {
      console.warn("[AI Enhancement] GROQ_API_KEY not configured");
      return null;
    }

    const searchResultsText = JSON.stringify(searchResults, null, 2);

    // Build conversation context if available
    let conversationContext = "";
    if (conversationMessages && conversationMessages.length > 0) {
      const recentMessages = conversationMessages.slice(-8);
      conversationContext = `
CONVERSATION CONTEXT (use this to understand what the user has been discussing):
${recentMessages.map((m) => `${m.role.toUpperCase()}: ${m.content}`).join("\n")}

`;
    }

    const prompt = `You are an expert assistant helping a user who has been having a conversation. Your task is to provide a helpful answer based on web search results while considering the conversation context.
${conversationContext}
USER'S SEARCH QUERY: "${query}"

SEARCH RESULTS:
${searchResultsText}

INSTRUCTIONS:
1. Provide a clear, informative answer that directly addresses the user's query
2. If there's conversation context, make sure your answer is relevant to what they were discussing
3. Use the search results to provide accurate, up-to-date information
4. Format your response with markdown for readability (bold for key terms, bullet points for lists)
5. If the search results don't fully answer the query in the context of the conversation, acknowledge this

Provide your enhanced answer:`;

    const response = await axios.post(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        model: "openai/gpt-oss-20b",
        messages: [
          {
            role: "system",
            content:
              "You are a helpful assistant that synthesizes web search results into clear, contextual answers. You consider the user's conversation history to provide relevant responses.",
          },
          { role: "user", content: prompt },
        ],
        max_tokens: 1500,
        temperature: 0.5,
      },
      {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${groqApiKey}`,
        },
        timeout: 30000,
      },
    );

    const enhancedAnswer =
      response.data.choices?.[0]?.message?.content ||
      "No enhanced answer from AI";
    return enhancedAnswer;
  } catch (err) {
    console.error("[AI Enhancement] Error:", err.message);
    return null;
  }
}

/**
 * Generate a SAT-specific study plan focused on the 4 SAT English categories
 * Returns an object: { plan: { title, modules: [...] } }
 */
async function generateSATStudyPlan(
  botName,
  selectedCategory,
  gradeLevel,
  description,
) {
  try {
    console.log("[SATStudyPlan] Generating SAT-specific study plan for:", {
      botName,
      selectedCategory,
      gradeLevel,
    });

    // SAT English study plan with 4 main categories
    const satPlan = {
      plan: {
        title: `SAT English Master Plan: ${selectedCategory}`,
        subject: `SAT English - ${selectedCategory}`,
        grade_level: gradeLevel,
        description:
          description ||
          `Master the ${selectedCategory} category for SAT English`,
        total_estimated_hours: 20,
        exam_focus: "Standardized Test Preparation",
        modules: [
          {
            id: "sat_module_1",
            title: `${selectedCategory} - Foundation`,
            objective: `Understand the core concepts and skills tested in ${selectedCategory}`,
            key_topics: [
              "Definition",
              "Scope",
              "Key Skills",
              "Common Patterns",
            ],
            expected_outcome:
              "Identify core concepts and understand question types",
            estimated_effort: "90 minutes",
            difficulty: "Easy",
            order: 1,
            sat_category: selectedCategory,
          },
          {
            id: "sat_module_2",
            title: `${selectedCategory} - Strategy & Technique`,
            objective: `Learn effective strategies and techniques for ${selectedCategory}`,
            key_topics: [
              "Approach",
              "Time Management",
              "Elimination",
              "Pattern Recognition",
            ],
            expected_outcome: "Apply strategic approaches to sample questions",
            estimated_effort: "120 minutes",
            difficulty: "Medium",
            order: 2,
            sat_category: selectedCategory,
          },
          {
            id: "sat_module_3",
            title: `${selectedCategory} - Practice & Analysis`,
            objective: `Practice with real SAT questions and analyze mistakes`,
            key_topics: [
              "Sample Questions",
              "Error Analysis",
              "Weak Areas",
              "Improvement",
            ],
            expected_outcome:
              "Identify personal weak spots and improvement areas",
            estimated_effort: "120 minutes",
            difficulty: "Medium",
            order: 3,
            sat_category: selectedCategory,
          },
          {
            id: "sat_module_4",
            title: `${selectedCategory} - Mastery & Full Tests`,
            objective: `Master the category and complete full-length practice tests`,
            key_topics: [
              "Advanced Questions",
              "Full Tests",
              "Timing",
              "Final Refinement",
            ],
            expected_outcome: "Score confidently on actual SAT exam",
            estimated_effort: "180 minutes",
            difficulty: "Hard",
            order: 4,
            sat_category: selectedCategory,
          },
        ],
      },
    };

    console.log("[SATStudyPlan] ✅ SAT study plan generated successfully");
    return satPlan;
  } catch (err) {
    console.error("[generateSATStudyPlan] Error:", err.message);
    return null;
  }
}

/**
 * Generate a structured study plan JSON using the AI model.
 * Returns an object: { plan: { title, modules: [...] } } or null on failure.
 *
 * Study Plan Structure (per HYPER PROMPT requirements):
 * - Plan title, subject, grade level
 * - Ordered modules with: id, title, objective, key_topics, expected_outcome, estimated_effort
 * - Machine-readable AND human-readable format
 */
async function generateStructuredStudyPlan(
  botName,
  topic,
  description,
  gradeLevel,
  learnerProfile,
) {
  try {
    const groqApiKey = process.env.GROQ_API_KEY;
    if (!groqApiKey) {
      console.warn("[StudyPlan] GROQ_API_KEY not configured");
      return null;
    }

    console.log("[StudyPlan] Generating structured plan for:", {
      botName,
      topic,
      gradeLevel,
      hasDescription: !!description,
      hasLearnerProfile: !!learnerProfile,
    });

    const prompt = `You are an expert curriculum designer creating a personalized study plan.

CONTEXT:
- Bot Name: ${botName}
- Topic: ${topic}
- Grade Level: ${gradeLevel}
- Student Goals: ${description || "General learning"}
${learnerProfile ? `- Learner Profile: ${JSON.stringify(learnerProfile)}` : ""}

OUTPUT REQUIREMENTS:
Produce ONLY valid JSON with this exact structure:
{
  "plan": {
    "title": "<descriptive plan title>",
    "subject": "${topic}",
    "grade_level": "${gradeLevel}",
    "description": "<brief plan overview>",
    "total_estimated_hours": <number>,
    "modules": [
      {
        "id": "module_1",
        "title": "<module title>",
        "objective": "<what student will learn>",
        "key_topics": ["topic1", "topic2", "topic3"],
        "expected_outcome": "<what student can do after completing>",
        "estimated_effort": "<e.g., 30 minutes>",
        "difficulty": "Easy|Medium|Hard",
        "order": 1
      }
    ]
  }
}

INSTRUCTIONS:
1. Generate 4-8 modules appropriate for ${gradeLevel} level
2. Order modules from foundational to advanced concepts
3. Each module should build on previous ones
4. Keep titles concise but descriptive
5. Make objectives specific and measurable
6. Tailor content to the student's goals: "${description || "General mastery of " + topic}"

Return ONLY the JSON object, no explanations or markdown.`;

    const groqRes = await axios.post(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        model: "llama-3.3-70b-versatile",
        messages: [
          {
            role: "system",
            content:
              "You are a curriculum design expert. Output only valid JSON.",
          },
          { role: "user", content: prompt },
        ],
        max_tokens: 2000,
        temperature: 0.7,
      },
      {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${groqApiKey}`,
        },
        timeout: 45000,
      },
    );

    let responseText = groqRes?.data?.choices?.[0]?.message?.content || "";
    // Clean code fences if present
    responseText = responseText.replace(/```json\n?|```/g, "").trim();

    const parsed = JSON.parse(responseText);

    // Validate structure
    if (!parsed.plan || !Array.isArray(parsed.plan.modules)) {
      console.error("[StudyPlan] Invalid plan structure received");
      return null;
    }

    // Ensure each module has required fields and proper IDs
    parsed.plan.modules = parsed.plan.modules.map((mod, idx) => ({
      id: mod.id || `module_${idx + 1}`,
      title: mod.title || `Module ${idx + 1}`,
      objective: mod.objective || mod.description || "",
      key_topics:
        mod.key_topics || mod.subtopics || mod.learning_objectives || [],
      expected_outcome: mod.expected_outcome || "",
      estimated_effort:
        mod.estimated_effort || mod.estimated_time_minutes
          ? `${mod.estimated_time_minutes} minutes`
          : "30 minutes",
      difficulty: mod.difficulty || "Medium",
      order: mod.order || idx + 1,
    }));

    console.log(
      "[StudyPlan] Successfully generated plan with",
      parsed.plan.modules.length,
      "modules",
    );
    return parsed;
  } catch (err) {
    console.error("[generateStructuredStudyPlan] Error:", err.message);
    return null;
  }
}

async function generateEnhancedInstructions(
  topic,
  description,
  gradeLevel,
  groqApiKey,
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
      },
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
  gradeLevel,
) {
  // Use the premium system instructions for elite educational experience
  return generatePremiumSystemInstructions(
    botName,
    botTopic,
    description,
    gradeLevel,
  );
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
        type TEXT DEFAULT 'standard',
        system_instructions JSONB,
        state JSONB,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log("[DB] study_bots table ensured");

    // Add type column if it doesn't exist
    await pool.query(`
      DO $$ 
      BEGIN 
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name='study_bots' AND column_name='type') THEN
          ALTER TABLE study_bots ADD COLUMN type TEXT DEFAULT 'standard';
        END IF;
      END $$;
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS sat_notes (
        id SERIAL PRIMARY KEY,
        topic TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log("[DB] sat_notes table ensured");

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
        plan_version INT DEFAULT 1,
        current_module INT DEFAULT 0,
        completed_modules JSONB DEFAULT '[]'::jsonb,
        progress_percentage FLOAT DEFAULT 0,
        bot_state VARCHAR(50) DEFAULT 'intro',
        last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(bot_id, user_id)
      );
    `);
    console.log("[DB] bot_progress table ensured");

    // Add plan_version column if it doesn't exist (for existing tables)
    await pool.query(`
      DO $$ 
      BEGIN 
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name='bot_progress' AND column_name='plan_version') THEN
          ALTER TABLE bot_progress ADD COLUMN plan_version INT DEFAULT 1;
        END IF;
      END $$;
    `);
    console.log("[DB] bot_progress plan_version column ensured");

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
    console.error(
      "[DB] Failed to ensure tables:",
      err?.message || JSON.stringify(err),
    );
    if (err?.detail) console.error("[DB] Error detail:", err.detail);
    if (err?.code) console.error("[DB] Error code:", err.code);
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
    console.error(
      "[DB] Failed to ensure user_study_state table:",
      err?.message || JSON.stringify(err),
    );
    if (err?.detail) console.error("[DB] Error detail:", err.detail);
    if (err?.code) console.error("[DB] Error code:", err.code);
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
      err?.message || JSON.stringify(err),
    );
    if (err?.detail) console.error("[DB] Error detail:", err.detail);
    if (err?.code) console.error("[DB] Error code:", err.code);
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
// ============= BOT INSTRUCTIONS RETRIEVAL ENDPOINT =============
// Frontend calls this to get fresh bot instructions from database
app.get("/api/bot/:botId/instructions", async (req, res) => {
  try {
    const { botId } = req.params;
    console.log(
      "[GET /api/bot/:botId/instructions] Fetching for botId:",
      botId,
    );

    if (!botId) {
      return res.status(400).json({
        error: "Invalid request",
        message: "botId is required",
        timestamp: new Date().toISOString(),
      });
    }

    // Query database for bot and its instructions
    const result = await pool.query(
      `SELECT bot_id, name, topic, grade_level, system_instructions 
       FROM study_bots 
       WHERE bot_id = $1 
       LIMIT 1`,
      [botId],
    );

    if (result.rows.length === 0) {
      console.log("[Bot Instructions] Bot not found:", botId);
      return res.status(404).json({
        error: "Bot not found",
        message: `Bot with ID ${botId} not found in database`,
        timestamp: new Date().toISOString(),
      });
    }

    const bot = result.rows[0];
    console.log("[Bot Instructions] Found bot:", bot.name);

    return res.json({
      status: "success",
      botId: bot.bot_id,
      botName: bot.name,
      topic: bot.topic,
      gradeLevel: bot.grade_level,
      systemInstructions: bot.system_instructions,
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.error("[GET /api/bot/:botId/instructions] Error:", err.message);
    return res.status(500).json({
      error: "Failed to fetch bot instructions",
      message: err.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// ============= ENHANCED CHAT ENDPOINT WITH INSTRUCTION REVIEW =============
app.post("/api/chat-enhanced", async (req, res) => {
  try {
    console.log("[POST /api/chat-enhanced] Request received");
    const {
      message,
      botId,
      userId,
      systemInstructions,
      learnerProfile,
      currentMood,
    } = req.body;

    if (!message || !botId || !userId) {
      return res.status(400).json({
        error: "Invalid request format",
        message: "message, botId, and userId are required",
        timestamp: new Date().toISOString(),
      });
    }

    console.log("[POST /api/chat-enhanced] Received payload:", {
      message: message.substring(0, 50),
      botId,
      userId,
      hasLearnerProfile: !!learnerProfile,
      hasMood: !!currentMood,
    });

    // Fetch bot progress state to avoid repeating the initial greeting
    let botProgressState = null;
    try {
      const bpRes = await pool.query(
        `SELECT bot_state FROM bot_progress WHERE bot_id = $1 AND user_id = $2 LIMIT 1`,
        [botId, userId],
      );
      if (bpRes.rows.length > 0) botProgressState = bpRes.rows[0].bot_state;
    } catch (bpErr) {
      console.warn(
        "[Chat-Enhanced] Could not fetch bot_progress:",
        bpErr.message,
      );
    }

    // If this is an initial session start request, prefer returning an existing DB welcome
    const isStartSession =
      typeof message === "string" && message.trim() === "[START_SESSION]";
    if (isStartSession) {
      try {
        const msgRes = await pool.query(
          `SELECT content FROM chat_messages WHERE bot_id = $1 AND user_id = $2 AND message_type = 'bot' ORDER BY created_at ASC LIMIT 1`,
          [botId, userId],
        );
        if (msgRes.rows.length > 0) {
          const existingGreeting = msgRes.rows[0].content;
          return res.json({
            status: "success",
            response: existingGreeting,
            state: botProgressState || "intro",
            progress: { percentage: 0 },
            instructionSource: dbInstructions ? "database" : "frontend",
            learnerProfileApplied: !!learnerProfile,
            moodApplied: !!currentMood,
            timestamp: new Date().toISOString(),
          });
        }
      } catch (gErr) {
        console.warn(
          "[Chat-Enhanced] Could not read existing greeting:",
          gErr.message,
        );
      }
    }

    // Conversational guardrail: detect short confirmations or mood replies
    try {
      // Expanded pattern to catch more affirmative responses
      const shortAffirmative =
        /^\s*(yes|yep|sure|okay|ok|please|please do|go ahead|create|yes please|i'?m ready|im ready|lets do it|let's do it|create it|yes.*create|looks good|sounds good|that'?s? good|perfect|great|do it|start|begin)\b/i;
      const shortMoodReply =
        /^\s*(fine|good|ok|okay|not bad|great|i'?m fine|im fine|doing well)\b/i;

      // Pull last bot message for context
      let lastBotMsg = null;
      try {
        const lastRes = await pool.query(
          `SELECT content FROM chat_messages WHERE bot_id = $1 AND user_id = $2 ORDER BY created_at DESC LIMIT 1`,
          [botId, userId],
        );
        if (lastRes.rows.length > 0) lastBotMsg = lastRes.rows[0].content;
      } catch (lErr) {
        console.warn(
          "[Chat-Enhanced] Failed to fetch last bot message:",
          lErr.message,
        );
      }

      // Detect if bot asked about creating a study plan
      const asksForPlan =
        lastBotMsg &&
        (/create.*study plan/i.test(lastBotMsg) ||
          /would you like.*study plan/i.test(lastBotMsg) ||
          /personalized study plan/i.test(lastBotMsg) ||
          /study plan for you/i.test(lastBotMsg));
      const asksMood =
        lastBotMsg &&
        /how are you|how's your|how are you doing/i.test(lastBotMsg);

      // Also detect if user is explicitly asking for plan creation
      const userWantsPlan =
        /create|make|generate|build|start.*plan|yes.*create.*plan/i.test(
          message || "",
        );

      if (
        (botProgressState === "waiting_for_user" &&
          shortAffirmative.test(message || "")) ||
        userWantsPlan
      ) {
        // If the bot just asked to create a study plan, generate a structured plan,
        // save it atomically, and return it to the frontend for review.
        try {
          // Fetch bot metadata to build plan context
          let botMeta = null;
          try {
            const bm = await pool.query(
              `SELECT name, topic, grade_level, description FROM study_bots WHERE bot_id = $1 LIMIT 1`,
              [botId],
            );
            if (bm.rows.length > 0) botMeta = bm.rows[0];
          } catch (bmErr) {
            console.warn(
              "[Chat-Enhanced] Failed to fetch bot metadata:",
              bmErr.message,
            );
          }

          // Generate structured plan via AI - always generate when user confirms or asks
          let generatedPlan = null;
          if (
            asksForPlan ||
            userWantsPlan ||
            botProgressState === "waiting_for_user"
          ) {
            console.log("[Chat-Enhanced] Generating study plan for user...");
            generatedPlan = await generateStructuredStudyPlan(
              botMeta?.name || "Study Bot",
              botMeta?.topic || "General",
              botMeta?.description || "",
              botMeta?.grade_level || "General",
              learnerProfile || null,
            );
          }

          // Persist plan and update state
          try {
            const planToSave = generatedPlan?.plan || { modules: [] };
            await pool.query(
              `INSERT INTO bot_progress (bot_id, user_id, study_plan, bot_state, last_updated)
               VALUES ($1, $2, $3, $4, NOW())
               ON CONFLICT (bot_id, user_id) DO UPDATE
               SET study_plan = $3, bot_state = $4, last_updated = NOW()`,
              [botId, userId, JSON.stringify(planToSave), "in_study"],
            );
            botProgressState = "in_study";
          } catch (saveErr) {
            console.warn(
              "[Chat-Enhanced] Failed to persist generated plan:",
              saveErr.message,
            );
          }

          // Save user's acceptance message
          try {
            await pool.query(
              `INSERT INTO chat_messages (bot_id, user_id, message_type, content) VALUES ($1, $2, $3, $4)`,
              [botId, userId, "user", message],
            );
          } catch (mErr) {
            console.warn(
              "[Chat-Enhanced] Failed to save user acceptance message:",
              mErr.message,
            );
          }

          // Insert a bot confirmation message summarizing the plan
          try {
            const summary = generatedPlan
              ? `I've created a study plan with ${generatedPlan.plan.modules.length} modules. Open the Study Plan to review and adjust.`
              : "Study plan prepared. Open the Study Plan to review and adjust.";
            await pool.query(
              `INSERT INTO chat_messages (bot_id, user_id, message_type, content) VALUES ($1, $2, $3, $4)`,
              [botId, userId, "bot", summary],
            );
          } catch (bErr) {
            console.warn(
              "[Chat-Enhanced] Failed to save plan summary message:",
              bErr.message,
            );
          }

          return res.json({
            status: "success",
            response: generatedPlan
              ? "I prepared a study plan for you. Opening the Study Plan for review."
              : "Prepared a placeholder study plan. Open the Study Plan to review.",
            showStudyPlan: true,
            studyPlan: generatedPlan?.plan || { modules: [] },
            state: botProgressState,
            progress: { percentage: 0 },
            instructionSource: dbInstructions ? "database" : "frontend",
            learnerProfileApplied: !!learnerProfile,
            moodApplied: !!currentMood,
            timestamp: new Date().toISOString(),
          });
        } catch (errPlan) {
          console.warn(
            "[Chat-Enhanced] Plan generation flow failed:",
            errPlan.message,
          );
          // Fallback: update state and return showStudyPlan without plan
          try {
            await pool.query(
              `UPDATE bot_progress SET bot_state = $1, last_updated = NOW() WHERE bot_id = $2 AND user_id = $3`,
              ["in_study", botId, userId],
            );
            botProgressState = "in_study";
          } catch (upErr) {
            console.warn(
              "[Chat-Enhanced] Failed to update bot_progress in fallback:",
              upErr.message,
            );
          }

          return res.json({
            status: "success",
            response: "Opening Study Plan for you to create manually.",
            showStudyPlan: true,
            studyPlan: { modules: [] },
            state: botProgressState,
            progress: { percentage: 0 },
            instructionSource: dbInstructions ? "database" : "frontend",
            learnerProfileApplied: !!learnerProfile,
            moodApplied: !!currentMood,
            timestamp: new Date().toISOString(),
          });
        }
      }

      if (
        botProgressState === "intro" &&
        asksMood &&
        shortMoodReply.test(message || "")
      ) {
        try {
          await pool.query(
            `UPDATE bot_progress SET bot_state = $1, last_updated = NOW() WHERE bot_id = $2 AND user_id = $3`,
            ["in_study", botId, userId],
          );
          botProgressState = "in_study";
        } catch (upErr) {
          console.warn(
            "[Chat-Enhanced] Failed to update bot_progress on mood reply:",
            upErr.message,
          );
        }
      }
    } catch (guardErr) {
      console.warn(
        "[Chat-Enhanced] Conversational guardrail error:",
        guardErr.message,
      );
    }

    // STEP 1: Fetch fresh instructions from database (always review)
    let dbInstructions = null;
    try {
      const result = await pool.query(
        `SELECT system_instructions FROM study_bots WHERE bot_id = $1 LIMIT 1`,
        [botId],
      );
      if (result.rows.length > 0) {
        dbInstructions = result.rows[0].system_instructions;
        console.log("[Chat-Enhanced] ✅ Instructions fetched from database");
      }
    } catch (dbErr) {
      console.warn("[Chat-Enhanced] Could not fetch from DB:", dbErr.message);
    }

    // STEP 2: Use database instructions first, fallback to frontend instructions
    let instructions = "",
      instructionSource = "";

    if (dbInstructions?.instructions) {
      instructions = dbInstructions.instructions;
      instructionSource = "database";
      console.log("[Chat-Enhanced] Using instructions from DATABASE");
    } else if (systemInstructions?.instructions) {
      instructions = systemInstructions.instructions;
      instructionSource = "frontend";
      console.log("[Chat-Enhanced] Using instructions from FRONTEND");
    } else {
      console.warn("[Chat-Enhanced] ⚠️ NO INSTRUCTIONS FOUND - using generic");
      instructions = `You are a helpful study bot. Help the user learn about this topic.`;
      instructionSource = "fallback";
    }

    // STEP 2.5: If this is a SAT bot, add special SAT instructions
    let isSatBot = false;
    try {
      const botTypeCheck = await pool.query(
        `SELECT type FROM study_bots WHERE bot_id = $1 LIMIT 1`,
        [botId],
      );

      if (botTypeCheck.rows.length > 0 && botTypeCheck.rows[0].type === "SAT") {
        isSatBot = true;
        const satInstructions = `
[SAT TUTOR MODE ACTIVE]
You are an expert SAT English tutor.
IMPORTANT RULES:
1. Use ONLY the SAT study notes provided below when answering
2. Stay strictly within the SAT English syllabus
3. Focus on the four main categories: Information and Ideas, Craft and Structure, Expression of Ideas, and Standard English Conventions
4. Explain concepts clearly with step-by-step examples from SAT material
5. If a question is not covered in the SAT notes, say "This topic is not covered in the SAT English curriculum"
6. Always relate answers back to SAT skills and test preparation
`;
        instructions = `${satInstructions}\n${instructions}`;
        console.log("[Chat-Enhanced] ✅ SAT tutor mode enabled");
      }
    } catch (satCheckErr) {
      console.warn(
        "[Chat-Enhanced] SAT mode check failed:",
        satCheckErr.message,
      );
    }

    console.log(
      "[Chat-Enhanced] Instructions ready:",
      `${instructions.substring(0, 100)}... (source: ${instructionSource})`,
    );

    // ===== SAT NOTES FETCHING LOGIC =====
    // Check bot type and fetch SAT notes if applicable
    let satNotesContext = "";
    try {
      const botResult = await pool.query(
        `SELECT type FROM study_bots WHERE bot_id = $1 LIMIT 1`,
        [botId],
      );

      if (botResult.rows.length > 0) {
        const botType = botResult.rows[0].type;
        console.log("[Chat-Enhanced] Bot type:", botType);

        if (botType === "SAT") {
          console.log("[Chat-Enhanced] Fetching SAT notes for SAT bot...");
          const satNotesResult = await pool.query(
            `SELECT topic, content FROM sat_notes ORDER BY created_at ASC`,
          );

          if (satNotesResult.rows.length > 0) {
            // Build formatted SAT notes string
            const formattedNotes = satNotesResult.rows
              .map(
                (note, index) =>
                  `${index + 1}. Topic: ${note.topic}\n${note.content}`,
              )
              .join("\n\n");

            satNotesContext = `\n\n[SAT STUDY NOTES]\n${formattedNotes}\n[END SAT NOTES]`;
            console.log(
              "[Chat-Enhanced] ✅ Retrieved",
              satNotesResult.rows.length,
              "SAT notes",
            );
          } else {
            console.warn("[Chat-Enhanced] No SAT notes found in database");
          }
        }
      }
    } catch (botTypeErr) {
      console.warn(
        "[Chat-Enhanced] Could not fetch bot type:",
        botTypeErr.message,
      );
    }

    console.log(
      "[Chat-Enhanced] Instructions ready:",
      `${instructions.substring(0, 100)}... (source: ${instructionSource})`,
    );

    // STEP 3: Enhance instructions with learner profile if available
    let enhancedInstructions = instructions;
    if (learnerProfile) {
      const profileContext = `
[LEARNER PROFILE]
- Learning Style: ${learnerProfile.learningStyle}
- Pace: ${learnerProfile.pacePreference}
- Tone: ${learnerProfile.communicationTone}
- Confidence: ${(learnerProfile.confidenceLevel * 100).toFixed(0)}%`;
      enhancedInstructions = `${instructions}${profileContext}`;
      console.log("[Chat-Enhanced] Instructions enhanced with learner profile");
    }

    // STEP 4: Add mood-based context if available
    if (currentMood?.sentiment) {
      const moodContext = `\n[LEARNER MOOD] Sentiment: ${currentMood.sentiment}, Action: ${currentMood.suggestedAction}`;
      enhancedInstructions = `${enhancedInstructions}${moodContext}`;
      console.log("[Chat-Enhanced] Instructions enhanced with mood context");
    }

    // STEP 4.2: Add SAT notes context if available
    if (satNotesContext) {
      enhancedInstructions = `${enhancedInstructions}${satNotesContext}`;
      console.log("[Chat-Enhanced] Instructions enhanced with SAT notes");
    }

    // STEP 4.5: Fetch and include active study plan context with CONCEPT-LEVEL tracking
    let studyPlanContext = "";
    let currentPlanVersion = 1;
    let currentModuleIndex = 0;
    let currentConceptIndex = 0;
    let completedModulesCount = 0;
    let completedConcepts = [];
    try {
      const planResult = await pool.query(
        `SELECT study_plan, plan_version, current_module, current_concept_index, completed_modules, completed_concepts 
         FROM bot_progress WHERE bot_id = $1 AND user_id = $2 LIMIT 1`,
        [botId, userId],
      );
      if (planResult.rows.length > 0) {
        const row = planResult.rows[0];
        const plan = row.study_plan;
        currentPlanVersion = row.plan_version || 1;
        currentModuleIndex = row.current_module || 0;
        currentConceptIndex = row.current_concept_index || 0;
        const completedModules = row.completed_modules || [];
        completedConcepts = row.completed_concepts || [];
        completedModulesCount = completedModules.length;

        console.log(
          "[Chat-Enhanced] 📚 Study plan found in DB:",
          plan ? `${plan.modules?.length || 0} modules` : "null",
        );

        if (plan && plan.modules && plan.modules.length > 0) {
          const totalModules = plan.modules.length;
          const progressPercent = Math.round(
            (completedModulesCount / totalModules) * 100,
          );

          const modulesSummary = plan.modules
            .map((m, idx) => {
              const status = completedModules.includes(idx)
                ? "✅ Completed"
                : idx === currentModuleIndex
                  ? "📍 Current"
                  : "⏳ Pending";
              return `${idx + 1}. ${m.title || m.module_name} [${status}]`;
            })
            .join("\n");

          const currentModule = plan.modules[currentModuleIndex];
          const keyTopics =
            currentModule?.key_topics || currentModule?.subtopics || [];

          // Build concept-level tracking for the current module
          const conceptsWithStatus = keyTopics
            .map((topic, idx) => {
              const conceptKey = `m${currentModuleIndex}_c${idx}`;
              const isCompleted = completedConcepts.includes(conceptKey);
              const isCurrent = idx === currentConceptIndex && !isCompleted;
              const status = isCompleted ? "✅" : isCurrent ? "📍" : "⏳";
              return `   ${status} ${idx + 1}. ${topic}`;
            })
            .join("\n");

          const currentConceptName =
            keyTopics[currentConceptIndex] || "Introduction";
          const completedConceptsInModule = keyTopics.filter((_, idx) =>
            completedConcepts.includes(`m${currentModuleIndex}_c${idx}`),
          ).length;

          const currentModuleDetails = currentModule
            ? `
═══════════════════════════════════════════════════════════
📚 CURRENT MODULE: "${currentModule.title || currentModule.module_name}"
═══════════════════════════════════════════════════════════
Objective: ${currentModule.objective || currentModule.description || "N/A"}
Difficulty: ${currentModule.difficulty || "Medium"}
Estimated Time: ${currentModule.estimated_effort || "30 minutes"}

📋 CONCEPTS IN THIS MODULE (${completedConceptsInModule}/${keyTopics.length} completed):
${conceptsWithStatus}

🎯 CURRENT CONCEPT TO TEACH: "${currentConceptName}" (Concept ${currentConceptIndex + 1} of ${keyTopics.length})`
            : "";

          studyPlanContext = `
╔══════════════════════════════════════════════════════════╗
║  ACTIVE STUDY PLAN - Version ${currentPlanVersion}
║  Progress: ${progressPercent}% (${completedModulesCount}/${totalModules} modules)
╚══════════════════════════════════════════════════════════╝

${modulesSummary}
${currentModuleDetails}

═══════════════════════════════════════════════════════════
🌟 ELITE TEACHING METHODOLOGY - EXECUTE WITH PRECISION
═══════════════════════════════════════════════════════════

**🚨 CRITICAL CONCEPT MASTERY PROTOCOL:**
1. EXCLUSIVELY teach the CURRENT CONCEPT marked with 📍 above
2. When user demonstrates understanding ("I understand", "yes", "got it", "move on", "next") → IMMEDIATELY advance
3. After user confirms understanding, you MUST:
   - Include [CONCEPT_COMPLETE] to mark mastery achieved
   - Progress to the NEXT concept without delay
4. NEVER revisit concepts marked ✅ unless explicitly requested
5. When ALL concepts achieve ✅ status, include [MODULE_COMPLETE] and initiate elite assessment

**PREMIUM TEACHING SEQUENCE:**
1. **Hook**: Introduce concept with compelling real-world relevance
2. **Core Explanation**: Deliver sophisticated yet accessible content (2-3 paragraphs max)
3. **Socratic Check**: "How does this concept connect to what you already know?"
4. **Application**: Provide immediate practical application opportunity
5. **Mastery Verification**: When user confirms → [CONCEPT_COMPLETE] → Advance

**ADVANCED UNDERSTANDING DETECTION - THESE TRIGGER IMMEDIATE ADVANCEMENT:**
- "I understand" / "I get it" / "Got it" / "Makes sense" / "That's clear"
- "Yes" / "Yeah" / "Yep" / "Sure" / "Okay" / "I see" / "Understood"
- "Move on" / "Next" / "Continue" / "Let's proceed" / "Ready"
- Any affirmative response combined with conceptual engagement
→ INSTANTLY include [CONCEPT_COMPLETE] and progress to next concept

**ELITE MODULE COMPLETION PROTOCOL:**
When ALL concepts achieve ✅ mastery:
- Deliver sophisticated congratulations acknowledging cognitive growth
- Provide meta-analysis of learning journey and achievements
- Present advanced choice: "Would you like to demonstrate your mastery through our premium assessment, or shall we explore the next advanced topic in your learning trajectory?"
- Include [MODULE_COMPLETE] to trigger elite recognition features

**PREMIUM ASSESSMENT TRIGGER:**
If user selects assessment option ("now", "quiz", "test me", "assessment", "challenge"):
- Include [TRIGGER_QUIZ] for sophisticated evaluation
- System generates adaptive assessment based on mastered concepts
- Assessment measures both recall and application abilities

**COGNITIVE LOAD OPTIMIZATION:**
- Maximum 3-4 concise paragraphs per response
- Single concept focus with layered complexity
- Strategic use of bullet points for clarity
- Premium emoji selection: 🌟 💡 🎯 🧠 🚀 ✨
- Maintain intellectual rigor while ensuring accessibility

**ELITE EXECUTION STANDARDS:**
- Never repeat completed concepts (marked ✅)
- Never stagnate on mastered concepts
- Never skip progressive learning sequences
- Never overwhelm with information dumps
- Always maintain personalized learning pace
- Always model sophisticated thinking
- Always inspire intellectual curiosity`;

          enhancedInstructions = `${enhancedInstructions}${studyPlanContext}`;
          console.log(
            "[Chat-Enhanced] Instructions enhanced with premium teaching methodology (v" +
              currentPlanVersion +
              ", " +
              progressPercent +
              "% complete)",
          );
        }
      }
    } catch (planErr) {
      console.warn(
        "[Chat-Enhanced] Could not fetch study plan:",
        planErr.message,
      );
    }

    // STEP 5: Prepare messages for AI model with MARKDOWN formatting requirement
    const systemMessageContent = `${enhancedInstructions}

## 🌟 PREMIUM RESPONSE FORMAT - ELITE PRESENTATION STANDARDS
Format your responses using sophisticated Markdown to ensure professional presentation and optimal learning:

**Typography Excellence:**
- Use **bold text** for critical concepts and key terminology
- Use *italic text* for emphasis and nuanced points
- Use ## Heading 2 for major sections and topic transitions
- Use ### Heading 3 for subtopics and detailed breakdowns
- Use \`\`\`code blocks\`\`\` for technical examples and implementations
- Use • bullet points for organized information presentation
- Use numbered lists only for sequential processes or rankings

**Structural Sophistication:**
- Maintain proper paragraph spacing for readability
- Create clear visual hierarchy with consistent formatting
- Use horizontal rules (---) to separate major sections
- Include blockquotes for important insights or citations
- Format mathematical expressions with proper notation when applicable

**Content Enhancement:**
- Introduce **key terms** in bold when first presented
- Provide **real-world applications** in italicized emphasis
- Use 💡 for insights, 🎯 for objectives, 🌟 for achievements
- Include **connection statements** that link concepts
- End with **forward-looking statements** that build anticipation

**Professional Example Structure:**
**Core Concept**: Elegant definition with immediate relevance

## Strategic Framework
Detailed explanation with layered complexity and practical applications

### Advanced Application
Sophisticated implementation strategies and real-world connections

**Learning Integration**: How this concept connects to broader understanding

---

**Next Horizon**: Preview of upcoming advanced topics

Always prioritize intellectual clarity, aesthetic presentation, and cognitive engagement in every response.`;

    const messages = [{ role: "system", content: systemMessageContent }];

    // If bot has already sent its initial greeting, instruct the model not to repeat it
    if (botProgressState && botProgressState !== "intro") {
      messages.push({
        role: "system",
        content:
          "NOTE: An initial greeting has already been sent in this conversation. Do NOT repeat the initial welcome message. Continue the conversation based on the user's latest input and proceed to the study flow when appropriate.",
      });
    }

    // CRITICAL: If a study plan exists, tell AI to NOT ask about creating one
    if (studyPlanContext && studyPlanContext.length > 0) {
      messages.push({
        role: "system",
        content:
          "CRITICAL: A study plan ALREADY EXISTS for this student. DO NOT ask if they want to create a study plan. DO NOT offer to create a new plan. Instead, IMMEDIATELY start teaching the CURRENT MODULE listed above. Begin with the first key topic and teach it step by step.",
      });
    }

    // STEP 5.5: Use conversation history from Firebase (sent by frontend) OR fallback to database
    const frontendHistory = req.body.conversationHistory;

    if (
      frontendHistory &&
      Array.isArray(frontendHistory) &&
      frontendHistory.length > 0
    ) {
      // Use conversation history from Firebase (sent by frontend)
      console.log(
        `[Chat-Enhanced] 🔥 Using ${frontendHistory.length} messages from Firebase (via frontend)`,
      );
      for (const msg of frontendHistory) {
        if (msg.role && msg.content) {
          messages.push({ role: msg.role, content: msg.content });
        }
      }
    } else {
      // Fallback: Fetch conversation history from PostgreSQL database
      try {
        const historyResult = await pool.query(
          `SELECT message_type, content FROM chat_messages 
           WHERE bot_id = $1 AND user_id = $2 
           ORDER BY created_at ASC 
           LIMIT 20`,
          [botId, userId],
        );

        if (historyResult.rows.length > 0) {
          console.log(
            `[Chat-Enhanced] 📜 Loading ${historyResult.rows.length} messages from PostgreSQL (fallback)`,
          );

          for (const row of historyResult.rows) {
            const role = row.message_type === "user" ? "user" : "assistant";
            messages.push({ role, content: row.content });
          }
        }
      } catch (histErr) {
        console.warn(
          "[Chat-Enhanced] Could not load conversation history:",
          histErr.message,
        );
      }
    }

    // Append the current user message
    messages.push({ role: "user", content: message });

    // Save the current user message to PostgreSQL database (backup storage)
    try {
      await pool.query(
        `INSERT INTO chat_messages (bot_id, user_id, message_type, content) VALUES ($1, $2, $3, $4)`,
        [botId, userId, "user", message],
      );
      console.log("[Chat-Enhanced] 💬 User message saved to PostgreSQL");
    } catch (saveUserErr) {
      console.warn(
        "[Chat-Enhanced] Could not save user message:",
        saveUserErr.message,
      );
    }

    console.log(
      `[Chat-Enhanced] Messages prepared (${messages.length} total), calling AI model...`,
    );

    // STEP 6: Call AI model with proper instructions
    const groqApiKey = process.env.GROQ_API_KEY;
    if (!groqApiKey) {
      console.error("[POST /api/chat-enhanced] GROQ_API_KEY not configured");
      return res.status(500).json({
        error: "API configuration error",
        message: "GROQ_API_KEY not configured",
        timestamp: new Date().toISOString(),
      });
    }

    let response;
    try {
      response = await axios.post(
        "https://api.groq.com/openai/v1/chat/completions",
        {
          model: "openai/gpt-oss-20b",
          messages: messages,
          max_tokens: 1500,
          temperature: 0.7,
        },
        {
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${groqApiKey}`,
          },
          timeout: 30000,
        },
      );
    } catch (groqErr) {
      console.error("[Chat-Enhanced] Groq API Error:", groqErr.message);
      if (groqErr.response) {
        console.error(
          "[Chat-Enhanced] Groq response status:",
          groqErr.response.status,
        );
        console.error(
          "[Chat-Enhanced] Groq response data:",
          groqErr.response.data,
        );
        return res.status(503).json({
          error: "AI service temporarily unavailable",
          message: groqErr.response.data?.error?.message || groqErr.message,
          provider: "groq",
          timestamp: new Date().toISOString(),
        });
      }
      throw groqErr;
    }

    const aiResponseRaw =
      response.data.choices?.[0]?.message?.content || "No response from AI";

    console.log(
      "[Chat-Enhanced] ✅ AI response received, raw length:",
      aiResponseRaw.length,
    );

    // Normalize the model response to unescape markdown/newline artifacts
    let aiResponse = normalizeModelResponse(aiResponseRaw);

    console.log(
      "[Chat-Enhanced] 🔧 Normalized AI response preview:",
      aiResponse.substring(0, 200).replace(/\n/g, "␤"),
    );

    // STEP 7: Detect concept/module completion signals and update progress
    let conceptCompleted = false;
    let moduleCompleted = false;
    let triggerQuiz = false;
    let newProgressPercentage = 0;
    let updatedCurrentModule = currentModuleIndex;
    let updatedCurrentConcept = currentConceptIndex;

    try {
      // Check if AI signaled concept completion
      if (aiResponse.includes("[CONCEPT_COMPLETE]")) {
        conceptCompleted = true;
        aiResponse = aiResponse.replace(/\[CONCEPT_COMPLETE\]/g, "").trim();
        console.log("[Chat-Enhanced] ✅ Concept completion detected!");

        const progressResult = await pool.query(
          `SELECT study_plan, current_module, current_concept_index, completed_concepts 
           FROM bot_progress WHERE bot_id = $1 AND user_id = $2 LIMIT 1`,
          [botId, userId],
        );

        if (progressResult.rows.length > 0) {
          const row = progressResult.rows[0];
          const plan = row.study_plan;
          let currentMod = row.current_module || 0;
          let currentConcept = row.current_concept_index || 0;
          let completedConceptsList = row.completed_concepts || [];

          if (plan && plan.modules && plan.modules.length > 0) {
            const currentModule = plan.modules[currentMod];
            const keyTopics =
              currentModule?.key_topics || currentModule?.subtopics || [];
            const conceptKey = `m${currentMod}_c${currentConcept}`;

            // Mark current concept as completed
            if (!completedConceptsList.includes(conceptKey)) {
              completedConceptsList.push(conceptKey);
            }

            // Move to next concept
            if (currentConcept < keyTopics.length - 1) {
              currentConcept = currentConcept + 1;
            }

            updatedCurrentConcept = currentConcept;

            // Update database with new concept index
            await pool.query(
              `UPDATE bot_progress 
               SET current_concept_index = $1, completed_concepts = $2, last_updated = NOW()
               WHERE bot_id = $3 AND user_id = $4`,
              [
                currentConcept,
                JSON.stringify(completedConceptsList),
                botId,
                userId,
              ],
            );

            console.log(
              `[Chat-Enhanced] 📚 Concept ${currentConcept + 1}/${keyTopics.length} in Module ${currentMod + 1}`,
            );
          }
        }
      }

      // Check if AI signaled quiz trigger
      if (aiResponse.includes("[TRIGGER_QUIZ]")) {
        triggerQuiz = true;
        aiResponse = aiResponse.replace(/\[TRIGGER_QUIZ\]/g, "").trim();
        console.log("[Chat-Enhanced] 📝 Quiz trigger detected!");
      }

      // Check if AI signaled module completion
      if (aiResponse.includes("[MODULE_COMPLETE]")) {
        moduleCompleted = true;
        aiResponse = aiResponse.replace(/\[MODULE_COMPLETE\]/g, "").trim();
        console.log("[Chat-Enhanced] 🎉 Module completion detected!");

        const progressResult = await pool.query(
          `SELECT study_plan, current_module, completed_modules 
           FROM bot_progress WHERE bot_id = $1 AND user_id = $2 LIMIT 1`,
          [botId, userId],
        );

        if (progressResult.rows.length > 0) {
          const row = progressResult.rows[0];
          const plan = row.study_plan;
          let currentMod = row.current_module || 0;
          let completedMods = row.completed_modules || [];

          if (plan && plan.modules && plan.modules.length > 0) {
            const totalModules = plan.modules.length;

            if (!completedMods.includes(currentMod)) {
              completedMods.push(currentMod);
            }

            // Move to next module if available
            if (currentMod < totalModules - 1) {
              currentMod = currentMod + 1;
            }

            newProgressPercentage = Math.round(
              (completedMods.length / totalModules) * 100,
            );
            updatedCurrentModule = currentMod;
            updatedCurrentConcept = 0; // Reset concept index for new module

            // Update database - reset concept index to 0 for new module
            await pool.query(
              `UPDATE bot_progress 
               SET current_module = $1, completed_modules = $2, progress_percentage = $3, current_concept_index = 0, last_updated = NOW()
               WHERE bot_id = $4 AND user_id = $5`,
              [
                currentMod,
                JSON.stringify(completedMods),
                newProgressPercentage,
                botId,
                userId,
              ],
            );

            console.log(
              `[Chat-Enhanced] 📊 Progress updated: ${newProgressPercentage}%, Module ${currentMod + 1}/${totalModules}`,
            );
          }
        }
      }
    } catch (progressErr) {
      console.warn(
        "[Chat-Enhanced] Progress update failed:",
        progressErr.message,
      );
    }

    // ALWAYS save bot response to chat_messages for conversation history
    try {
      await pool.query(
        `INSERT INTO chat_messages (bot_id, user_id, message_type, content) VALUES ($1, $2, $3, $4)`,
        [botId, userId, "bot", aiResponse],
      );
      console.log("[Chat-Enhanced] 💬 Bot response saved to history");
    } catch (saveErr) {
      console.warn(
        "[Chat-Enhanced] Failed to save bot response:",
        saveErr.message,
      );
    }

    // Update bot progress state based on conversation flow
    try {
      const lowerResp = (aiResponse || "").toLowerCase();
      const looksLikeGreeting =
        /hi[,! ]|hello[,! ]|i'm |i am /i.test(lowerResp) ||
        aiResponse.includes("How are you doing");

      let newState = botProgressState;
      if (!botProgressState || botProgressState === "intro") {
        newState = looksLikeGreeting ? "waiting_for_user" : "in_study";
      } else if (studyPlanContext && studyPlanContext.length > 0) {
        newState = "learning";
      }

      await pool.query(
        `UPDATE bot_progress SET bot_state = $1, last_updated = NOW() WHERE bot_id = $2 AND user_id = $3`,
        [newState, botId, userId],
      );
      botProgressState = newState;
    } catch (stErr) {
      console.warn(
        "[Chat-Enhanced] Failed to update bot_progress:",
        stErr.message,
      );
    }

    return res.json({
      status: "success",
      response: aiResponse,
      state: botProgressState || "intro",
      progress: {
        percentage: moduleCompleted
          ? newProgressPercentage
          : completedModulesCount > 0
            ? Math.round(
                (completedModulesCount / (completedModulesCount + 1)) * 100,
              )
            : 0,
        currentModule: updatedCurrentModule,
        currentConcept: updatedCurrentConcept,
        completedModules: completedModulesCount + (moduleCompleted ? 1 : 0),
      },
      conceptCompleted: conceptCompleted,
      moduleCompleted: moduleCompleted,
      triggerQuiz: triggerQuiz,
      instructionSource: instructionSource,
      learnerProfileApplied: !!learnerProfile,
      moodApplied: !!currentMood,
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.error("[POST /api/chat-enhanced] Error:", err.message);
    console.error("[POST /api/chat-enhanced] Stack:", err.stack);
    return res.status(500).json({
      error: "Failed to process chat message",
      message: err.message,
      provider: "unknown",
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

// Provide bot progress and study plan to frontend
app.get("/api/bot-progress/:botId/:userId", async (req, res) => {
  try {
    const { botId, userId } = req.params;
    if (!botId || !userId) {
      return res.status(400).json({ error: "botId and userId required" });
    }

    const result = await pool.query(
      `SELECT bot_state, progress_percentage, study_plan, plan_version, current_module, current_concept_index, completed_modules, completed_concepts 
       FROM bot_progress WHERE bot_id = $1 AND user_id = $2 LIMIT 1`,
      [botId, userId],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Bot progress not found" });
    }

    const row = result.rows[0];
    const plan = row.study_plan || { modules: [] };
    const completedModules = row.completed_modules || [];
    const totalModules = plan.modules?.length || 0;

    // Calculate progress percentage based on completed modules
    let progressPercentage = row.progress_percentage || 0;
    if (totalModules > 0 && completedModules.length > 0) {
      progressPercentage = Math.round(
        (completedModules.length / totalModules) * 100,
      );
    }

    console.log(
      `[bot-progress] Progress: ${progressPercentage}% (${completedModules.length}/${totalModules} modules)`,
    );

    return res.json({
      status: "success",
      bot_state: row.bot_state || "intro",
      progress: {
        percentage: progressPercentage,
        completedModules: completedModules.length,
        totalModules: totalModules,
      },
      study_plan: plan,
      plan_version: row.plan_version || 1,
      current_module: row.current_module || 0,
      current_concept: row.current_concept_index || 0,
      completed_modules: completedModules,
      completed_concepts: row.completed_concepts || [],
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.error("[GET /api/bot-progress] Error:", err.message);
    return res
      .status(500)
      .json({ error: "Failed to fetch bot progress", message: err.message });
  }
});

// Save progress endpoint (called when user records milestones during learning)
app.post("/api/save-progress", async (req, res) => {
  try {
    const {
      botId,
      userId,
      progressPercentage,
      botState,
      currentModule,
      completedModules,
    } = req.body;

    // Validate input
    if (!botId || !userId) {
      return res
        .status(400)
        .json({ success: false, error: "botId and userId are required" });
    }

    console.log(
      `[save-progress] Saving progress: botId=${botId}, userId=${userId}, progress=${progressPercentage}%`,
    );

    // Upsert progress record (insert if doesn't exist, update if does)
    const result = await pool.query(
      `INSERT INTO bot_progress (bot_id, user_id, progress_percentage, bot_state, current_module, completed_modules, last_updated)
       VALUES ($1, $2, $3, $4, $5, $6, CURRENT_TIMESTAMP)
       ON CONFLICT (bot_id, user_id) DO UPDATE SET
       progress_percentage = EXCLUDED.progress_percentage,
       bot_state = EXCLUDED.bot_state,
       current_module = EXCLUDED.current_module,
       completed_modules = EXCLUDED.completed_modules,
       last_updated = CURRENT_TIMESTAMP
       RETURNING *`,
      [
        botId,
        userId,
        progressPercentage || 0,
        botState || "intro",
        currentModule || 0,
        JSON.stringify(completedModules || []),
      ],
    );

    const savedProgress = result.rows[0];

    console.log(
      `[save-progress] ✅ Progress saved successfully: ${progressPercentage}%`,
    );

    return res.json({
      success: true,
      message: "Progress saved successfully",
      progress: {
        percentage: savedProgress.progress_percentage,
        botState: savedProgress.bot_state,
        currentModule: savedProgress.current_module,
        completedModules: savedProgress.completed_modules,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.error("[POST /api/save-progress] Error:", err.message);
    return res.status(500).json({
      success: false,
      error: "Failed to save progress",
      message: err.message,
    });
  }
});

app.get("/api/user-bots/:userId", async (req, res) => {
  try {
    const { userId } = req.params;

    if (!userId) {
      return res.status(400).json({ error: "userId is required", bots: [] });
    }

    console.log("[user-bots] Fetching bots for user:", userId);

    // Simple query - just get basic bot info first
    let botsResult;
    try {
      botsResult = await pool.query(
        `SELECT bot_id, name, description, topic, grade_level, created_at
         FROM study_bots
         WHERE user_id = $1 
         ORDER BY created_at DESC 
         LIMIT 20`,
        [userId],
      );
    } catch (dbErr) {
      console.error("[user-bots] Database query failed:", dbErr.message);
      return res.status(500).json({
        error: "Database query failed",
        message: dbErr.message,
        bots: [],
      });
    }

    console.log("[user-bots] Found", botsResult.rows.length, "bots");

    // If no bots, return empty array immediately
    if (botsResult.rows.length === 0) {
      return res.json({ status: "success", bots: [] });
    }

    // Enrich each bot with progress and last message (with error handling)
    const enrichedBots = [];

    for (const bot of botsResult.rows) {
      let progressPercentage = 0;
      let botState = "intro";
      let lastMessage = null;
      let lastMessageTime = null;

      // Get progress (non-blocking)
      try {
        const progressResult = await pool.query(
          `SELECT progress_percentage, bot_state FROM bot_progress 
           WHERE bot_id = $1 AND user_id = $2 LIMIT 1`,
          [bot.bot_id, userId],
        );
        if (progressResult.rows.length > 0) {
          progressPercentage = progressResult.rows[0].progress_percentage || 0;
          botState = progressResult.rows[0].bot_state || "intro";
        }
      } catch (e) {
        console.warn(
          "[user-bots] Progress fetch failed for",
          bot.bot_id,
          e.message,
        );
      }

      // Get last message (non-blocking)
      try {
        const msgResult = await pool.query(
          `SELECT content, created_at FROM chat_messages 
           WHERE bot_id = $1 AND user_id = $2 
           ORDER BY created_at DESC LIMIT 1`,
          [bot.bot_id, userId],
        );
        if (msgResult.rows.length > 0) {
          const content = msgResult.rows[0].content || "";
          lastMessage =
            content.length > 100 ? content.substring(0, 100) + "..." : content;
          lastMessageTime = msgResult.rows[0].created_at;
        }
      } catch (e) {
        console.warn(
          "[user-bots] Last message fetch failed for",
          bot.bot_id,
          e.message,
        );
      }

      enrichedBots.push({
        bot_id: bot.bot_id,
        name: bot.name,
        description: bot.description,
        topic: bot.topic,
        grade_level: bot.grade_level,
        progress_percentage: progressPercentage,
        bot_state: botState,
        last_message: lastMessage,
        last_message_time: lastMessageTime,
        created_at: bot.created_at,
      });
    }

    return res.json({
      status: "success",
      bots: enrichedBots,
    });
  } catch (err) {
    console.error("[user-bots] Error:", err.message);
    console.error("[user-bots] Stack:", err.stack);
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
      userId,
    );

    const result = await pool.query(
      `SELECT message_type, content, created_at 
       FROM chat_messages 
       WHERE bot_id = $1 AND user_id = $2 
       ORDER BY created_at ASC`,
      [botId, userId],
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
    const applyPlan = req.body.apply === true;

    if (!botId || !userId || !updatedPlan) {
      return res.status(400).json({
        error: "Invalid request",
        message: "botId, userId, and updatedPlan are required",
        timestamp,
      });
    }

    console.log("[update-study-plan] Updating plan for bot:", botId);

    // Validate plan structure
    if (!updatedPlan.modules || !Array.isArray(updatedPlan.modules)) {
      return res.status(400).json({
        error: "Invalid plan structure",
        message: "Plan must contain modules array",
        timestamp,
      });
    }

    // Validate each module has required fields
    for (let i = 0; i < updatedPlan.modules.length; i++) {
      const mod = updatedPlan.modules[i];
      if (!mod.title && !mod.module_name) {
        return res.status(400).json({
          error: "Invalid module structure",
          message: `Module ${i + 1} must have a title`,
          timestamp,
        });
      }
    }

    // Increment plan version on update
    const versionResult = await pool.query(
      `SELECT plan_version FROM bot_progress WHERE bot_id = $1 AND user_id = $2`,
      [botId, userId],
    );
    const currentVersion = versionResult.rows[0]?.plan_version || 1;
    const newVersion = currentVersion + 1;

    if (applyPlan) {
      await pool.query(
        `UPDATE bot_progress 
         SET study_plan = $1, bot_state = $2, plan_version = $3, last_updated = NOW() 
         WHERE bot_id = $4 AND user_id = $5`,
        [JSON.stringify(updatedPlan), "in_study", newVersion, botId, userId],
      );
    } else {
      await pool.query(
        `UPDATE bot_progress 
         SET study_plan = $1, plan_version = $2, last_updated = NOW() 
         WHERE bot_id = $3 AND user_id = $4`,
        [JSON.stringify(updatedPlan), newVersion, botId, userId],
      );
    }
    console.log("[update-study-plan] Plan updated to version", newVersion);

    return res.json({
      status: "success",
      message: "Study plan updated successfully",
      plan_updated: true,
      plan_version: newVersion,
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

// Apply a study plan atomically and transition bot to in_study
app.post("/api/apply-study-plan", async (req, res) => {
  try {
    const { botId, userId, plan, studyPlan } = req.body;
    const planData = plan || studyPlan; // Support both parameter names

    if (!botId || !userId || planData == null) {
      return res
        .status(400)
        .json({ error: "botId, userId and plan/studyPlan are required" });
    }

    console.log(
      "[apply-study-plan] Applying plan for bot:",
      botId,
      "user:",
      userId,
    );

    // Get current version and increment
    const versionResult = await pool.query(
      `SELECT plan_version FROM bot_progress WHERE bot_id = $1 AND user_id = $2`,
      [botId, userId],
    );
    const currentVersion = versionResult.rows[0]?.plan_version || 0;
    const newVersion = currentVersion + 1;

    await pool.query(
      `INSERT INTO bot_progress (bot_id, user_id, study_plan, plan_version, bot_state, last_updated)
         VALUES ($1, $2, $3, $4, $5, NOW())
         ON CONFLICT (bot_id, user_id) DO UPDATE
         SET study_plan = $3, plan_version = $4, bot_state = $5, last_updated = NOW()`,
      [botId, userId, JSON.stringify(planData), newVersion, "in_study"],
    );

    console.log("[apply-study-plan] Plan applied, version:", newVersion);

    // Save a system chat message announcing plan application
    try {
      const applyMsg =
        "✅ Study plan applied! Let's begin your learning journey.";
      await pool.query(
        `INSERT INTO chat_messages (bot_id, user_id, message_type, content) VALUES ($1, $2, $3, $4)`,
        [botId, userId, "bot", applyMsg],
      );
    } catch (msgErr) {
      console.warn(
        "[apply-study-plan] Failed to insert chat message:",
        msgErr.message,
      );
    }

    return res.json({
      status: "success",
      applied: true,
      bot_state: "in_study",
      plan_version: newVersion,
    });
  } catch (err) {
    console.error("[POST /api/apply-study-plan] Error:", err.message);
    return res
      .status(500)
      .json({ error: "Failed to apply study plan", message: err.message });
  }
});

app.post("/api/generate-quiz", async (req, res) => {
  const timestamp = new Date().toISOString();
  console.log(
    "[POST /api/generate-quiz] ENHANCED Quiz generation request:",
    timestamp,
  );

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

    console.log(
      "[generate-quiz] 🧠 Starting ENHANCED quiz generation with deep learning analysis...",
    );

    // Check if this is a SAT bot
    let isSatBot = false;
    let satCategory = "";
    try {
      const botTypeResult = await pool.query(
        `SELECT type, topic FROM study_bots WHERE bot_id = $1 LIMIT 1`,
        [botId],
      );
      if (
        botTypeResult.rows.length > 0 &&
        botTypeResult.rows[0].type === "SAT"
      ) {
        isSatBot = true;
        satCategory =
          botTypeResult.rows[0].topic?.split(" - ").pop() || "SAT English";
        console.log(
          "[generate-quiz] ✅ SAT bot detected, category:",
          satCategory,
        );
      }
    } catch (typeCheckErr) {
      console.warn(
        "[generate-quiz] Could not check bot type:",
        typeCheckErr.message,
      );
    }

    // Generate enhanced quiz prompt based on comprehensive analysis
    let quizPrompt;
    try {
      quizPrompt = await generateEnhancedQuizPrompt({
        botId,
        userId,
        moduleName,
        gradeLevel,
        questionType,
        mcqCount,
        textCount,
        useWebSearch: useWebSearch !== false, // Enable web search to fetch relevant context online
        topic: topic, // Pass topic for web search queries
      });

      // For SAT bots, prepend SAT-specific instructions
      if (isSatBot) {
        quizPrompt = `[SAT EXAM FORMAT]
Generate questions aligned with SAT English standards for the "${satCategory}" category.
Focus on: Reading comprehension, grammar, syntax, word choice, and context understanding.
${quizPrompt}`;
        console.log(
          "[generate-quiz] Enhanced prompt with SAT-specific instructions",
        );
      }
    } catch (promptErr) {
      console.error(
        "[generate-quiz] Error generating quiz prompt:",
        promptErr.message,
      );
      console.error("[generate-quiz] Prompt error stack:", promptErr.stack);
      // Fall back to simple prompt
      quizPrompt = `Generate a ${questionType} quiz with ${mcqCount} MCQ and ${textCount} text questions about "${moduleName}".`;
    }

    console.log(
      "[generate-quiz] 📝 Enhanced quiz prompt generated with learning analysis",
    );

    // Call Groq API with enhanced prompt
    const groqApiKey = process.env.GROQ_API_KEY;
    if (!groqApiKey) {
      console.warn("[generate-quiz] GROQ_API_KEY not configured");
      return res.status(500).json({
        error: "Configuration error",
        message: "GROQ_API_KEY not configured",
        timestamp,
      });
    }

    console.log(
      "[generate-quiz] 🤖 Calling Groq API for PERSONALIZED question generation",
    );
    let groqRes;
    try {
      groqRes = await axios.post(
        "https://api.groq.com/openai/v1/chat/completions",
        {
          model: "openai/gpt-oss-20b",
          messages: [
            {
              role: "system",
              content:
                "You are an expert educational quiz generator specializing in personalized assessments. Generate ONLY valid JSON with no markdown, code blocks, or extra text. Make quizzes feel personal to each student's learning journey.",
            },
            {
              role: "user",
              content: quizPrompt,
            },
          ],
          max_tokens: 3000, // Increased for more detailed responses
          temperature: 0.7, // Slightly higher for creativity
        },
        {
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${groqApiKey}`,
          },
          timeout: 45000, // Increased timeout for complex analysis
        },
      );
    } catch (groqErr) {
      console.error(
        "[generate-quiz] Groq API error:",
        groqErr.response?.status,
        groqErr.response?.data || groqErr.message,
      );
      // Try with a simpler model if the first one fails
      console.log("[generate-quiz] Retrying with simpler model...");
      groqRes = await axios.post(
        "https://api.groq.com/openai/v1/chat/completions",
        {
          model: "openai/gpt-oss-20b",
          messages: [
            {
              role: "system",
              content:
                "Generate an educational quiz. Return valid JSON only, no markdown.",
            },
            {
              role: "user",
              content: quizPrompt,
            },
          ],
          max_tokens: 2000,
          temperature: 0.5,
        },
        {
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${groqApiKey}`,
          },
          timeout: 45000,
        },
      );
    }

    let quizJson;
    const responseText = groqRes?.data?.choices?.[0]?.message?.content || "";

    try {
      // Try to parse the response directly
      quizJson = JSON.parse(responseText);
    } catch (parseErr) {
      console.warn(
        "[generate-quiz] Failed to parse JSON directly, attempting cleanup",
      );
      // Try to extract JSON from markdown code blocks or extra text
      let cleanedText = responseText
        .replace(/```json\n?/g, "")
        .replace(/```\n?/g, "")
        .trim();
      quizJson = JSON.parse(cleanedText);
    }

    // Enhanced validation
    if (
      !quizJson ||
      !quizJson.questions ||
      !Array.isArray(quizJson.questions)
    ) {
      console.error("[generate-quiz] Invalid quiz structure received");
      return res.status(500).json({
        error: "Quiz generation failed",
        message: "Invalid quiz structure returned from AI",
        timestamp,
      });
    }

    // Validate personalized elements
    const hasPersonalization =
      quizJson.personalization &&
      (quizJson.personalization.basedOnConversation ||
        quizJson.personalization.addressesWeaknesses?.length > 0 ||
        quizJson.personalization.buildsOnStrengths?.length > 0);

    console.log("[generate-quiz] ✅ Enhanced quiz generated successfully:", {
      totalQuestions: quizJson.questions.length,
      personalized: hasPersonalization,
      hasAnswers: quizJson.answers && Array.isArray(quizJson.answers),
      conceptsTested: quizJson.questions.map((q) => q.concept).filter(Boolean)
        .length,
    });

    // Store quiz data with enhanced metadata
    let quizId = null;
    try {
      const dbResult = await pool.query(
        `INSERT INTO quiz_data (bot_id, user_id, module_name, quiz_data) 
         VALUES ($1, $2, $3, $4) 
         ON CONFLICT (bot_id, user_id, module_name) 
         DO UPDATE SET quiz_data = $4, created_at = CURRENT_TIMESTAMP
         RETURNING id`,
        [
          botId,
          userId,
          moduleName,
          JSON.stringify({
            ...quizJson,
            enhanced: true,
            generatedAt: timestamp,
            personalized: hasPersonalization,
          }),
        ],
      );
      quizId = dbResult.rows[0]?.id;
      console.log(
        "[generate-quiz] 📚 Enhanced quiz stored in database with ID:",
        quizId,
      );
    } catch (dbErr) {
      console.error("[generate-quiz] Database error:", dbErr.message);
      // Continue even if storage fails
    }

    // Return enhanced response with quizId
    return res.status(200).json({
      success: true,
      quiz: quizJson,
      quizId: quizId,
      metadata: {
        enhanced: true,
        personalized: hasPersonalization,
        generatedAt: timestamp,
        analysisUsed: true,
        conversationAnalyzed: true,
        studyPlanContext: true,
      },
      timestamp,
    });
  } catch (err) {
    console.error("[POST /api/generate-quiz] Error:", err.message);
    console.error("[POST /api/generate-quiz] Stack:", err.stack);
    return res.status(500).json({
      error: "Enhanced quiz generation failed",
      message: err.message,
      timestamp: new Date().toISOString(),
    });
  }
});

app.post("/api/create-study-bot", async (req, res) => {
  try {
    console.log("[POST /api/create-study-bot] Request received");
    const {
      user_id,
      name,
      description,
      topic,
      grade_level,
      type = "standard",
    } = req.body;

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
      grade_level,
    );

    // Save to database with bot type
    await pool.query(
      `INSERT INTO study_bots (bot_id, user_id, name, description, topic, grade_level, type, system_instructions)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        botId,
        user_id,
        name,
        description,
        topic,
        grade_level,
        type,
        JSON.stringify({
          instructions: systemInstructions,
          description: description,
        }),
      ],
    );

    // Initialize bot progress
    await pool.query(
      `INSERT INTO bot_progress (bot_id, user_id, study_plan, bot_state)
       VALUES ($1, $2, $3, $4)`,
      [botId, user_id, JSON.stringify({ modules: [] }), "intro"],
    );

    console.log(
      "[create-study-bot] Bot created successfully:",
      botId,
      "with type:",
      type,
    );

    // GUARANTEE study plan generation - this is critical for bot functionality
    let generatedPlan = null;
    let planGenerationSuccess = false;
    try {
      console.log("[create-study-bot] Generating study plan for:", {
        name,
        topic,
        grade_level,
        type,
      });

      // Check if this is a SAT bot and extract the category
      if (type === "SAT") {
        // Extract SAT category from topic (e.g., "English - Information and Ideas")
        const satCategory = topic.split(" - ").pop() || topic;
        console.log(
          "[create-study-bot] Detected SAT bot, category:",
          satCategory,
        );

        generatedPlan = await generateSATStudyPlan(
          name,
          satCategory,
          grade_level,
          description,
        );
      } else {
        // Standard study plan for non-SAT bots
        generatedPlan = await generateStructuredStudyPlan(
          name,
          topic,
          description || "",
          grade_level,
          null,
        );
      }

      if (
        generatedPlan &&
        generatedPlan.plan &&
        generatedPlan.plan.modules &&
        generatedPlan.plan.modules.length > 0
      ) {
        planGenerationSuccess = true;
        console.log(
          "[create-study-bot] ✅ Study plan generated with",
          generatedPlan.plan.modules.length,
          "modules",
        );
      } else {
        console.warn(
          "[create-study-bot] ❌ Study plan generation returned empty or invalid plan",
        );
      }
    } catch (planErr) {
      console.error(
        "[create-study-bot] ❌ Study plan generation failed:",
        planErr.message,
      );
      // Create a fallback plan if generation fails
      const fallbackTitle =
        type === "SAT"
          ? `SAT English ${topic.split(" - ").pop() || "Study"} Plan`
          : `${topic} Study Plan`;

      generatedPlan = {
        plan: {
          title: fallbackTitle,
          subject: topic,
          grade_level: grade_level,
          description: `A comprehensive study plan for ${topic} at ${grade_level} level`,
          total_estimated_hours: 10,
          modules: [
            {
              id: "module_1",
              title: "Introduction to " + topic,
              objective: "Understand the basics of " + topic,
              key_topics: ["Basic concepts", "Key terms", "Overview"],
              expected_outcome: "Gain foundational knowledge",
              estimated_effort: "30 minutes",
              difficulty: "Easy",
              order: 1,
            },
            {
              id: "module_2",
              title: "Core Concepts",
              objective: "Master fundamental principles",
              key_topics: [
                "Main ideas",
                "Important relationships",
                "Applications",
              ],
              expected_outcome: "Apply core concepts",
              estimated_effort: "45 minutes",
              difficulty: "Medium",
              order: 2,
            },
          ],
        },
      };
      planGenerationSuccess = true;
      console.log("[create-study-bot] ✅ Fallback study plan created");
    }

    // Always persist the study plan (either generated or fallback)
    if (generatedPlan && generatedPlan.plan) {
      try {
        const planWithMeta = {
          plan: generatedPlan.plan,
          metadata: {
            version: 1,
            user_id: user_id,
            conversation_id: botId,
            last_updated: new Date().toISOString(),
            generation_success: planGenerationSuccess,
          },
        };

        await pool.query(
          `UPDATE bot_progress SET study_plan = $1, bot_state = $2, last_updated = NOW() WHERE bot_id = $3 AND user_id = $4`,
          [JSON.stringify(planWithMeta), "plan_review", botId, user_id],
        );
        console.log("[create-study-bot] ✅ Study plan persisted to database");
      } catch (saveErr) {
        console.error(
          "[create-study-bot] ❌ Failed to persist study plan:",
          saveErr.message,
        );
        // This is critical - throw error if we can't save the plan
        throw new Error("Failed to save study plan: " + saveErr.message);
      }
    }

    // --- Verification & single-welcome enforcement ---
    // Verify instructions were saved
    let customInstructionsCreated = false;
    try {
      const verifyRes = await pool.query(
        `SELECT system_instructions FROM study_bots WHERE bot_id = $1 LIMIT 1`,
        [botId],
      );
      if (
        verifyRes.rows.length > 0 &&
        verifyRes.rows[0].system_instructions &&
        verifyRes.rows[0].system_instructions.instructions
      ) {
        customInstructionsCreated = true;
      }
    } catch (verErr) {
      console.warn(
        "[create-study-bot] Verification query failed:",
        verErr.message,
      );
    }

    // Ensure exactly one welcome message: insert one deterministically if none exist
    let welcomeMessagesCount = 0;
    let welcomeMessage = null;
    try {
      const countRes = await pool.query(
        `SELECT id, content, created_at FROM chat_messages WHERE bot_id = $1 AND user_id = $2 AND message_type = 'bot' ORDER BY created_at ASC`,
        [botId, user_id],
      );
      welcomeMessagesCount = countRes.rows.length;

      if (welcomeMessagesCount === 0) {
        // Compose a deterministic welcome based on the bot's first-message guidance
        welcomeMessage = `Hi, I'm ${name}. I'm here to make studying feel like a breeze. How are you doing today?`;
        await pool.query(
          `INSERT INTO chat_messages (bot_id, user_id, message_type, content) VALUES ($1, $2, $3, $4)`,
          [botId, user_id, "bot", welcomeMessage],
        );
        welcomeMessagesCount = 1;

        // Update bot progress to indicate we're waiting for the user's reply
        try {
          await pool.query(
            `UPDATE bot_progress SET bot_state = $1, last_updated = NOW() WHERE bot_id = $2 AND user_id = $3`,
            ["waiting_for_user", botId, user_id],
          );
        } catch (stErr) {
          console.warn(
            "[create-study-bot] Failed to update bot_progress state:",
            stErr.message,
          );
        }
      } else {
        // If there are existing bot messages, return the earliest one as the welcome preview
        welcomeMessage = countRes.rows[0]?.content || null;
      }
    } catch (wErr) {
      console.warn(
        "[create-study-bot] Welcome-message check failed:",
        wErr.message,
      );
    }

    const respPayload = {
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
      verification: {
        customInstructionsCreated: customInstructionsCreated,
        welcomeMessagesCount: welcomeMessagesCount,
        welcomeMessage: welcomeMessage,
        nextState: "waiting_for_user",
      },
      timestamp: new Date().toISOString(),
    };

    if (generatedPlan && generatedPlan.plan) {
      respPayload.studyPlan = generatedPlan.plan;
      respPayload.showStudyPlan = true;
      respPayload.verification.nextState = "plan_review";
    }

    return res.json(respPayload);
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

        // If web search is enabled, route to search case instead
        if (data.webSearchEnabled || data.useWebSearch) {
          console.log("[Chat] Web search enabled, routing to search handler");
          // Convert chat message to search query
          const searchData = {
            query: data.message || data.query || "Search",
            messages: data.messages || [],
            botId: data.botId,
            userId: data.userId,
          };
          // Execute search case logic
          type = "search";
          // Fall through to search case
          // We'll use a workaround by setting type and letting it fall through
          const TAVILY_KEY = process.env.TAVILY_API_KEY;
          if (!TAVILY_KEY) {
            console.error(
              "[Search] TAVILY key not configured (env 'TAVILY_API_KEY')",
            );
            return res.status(500).json({
              error: "API configuration error",
              message:
                "Tavily API key not configured. Set env var 'TAVILY_API_KEY'",
              provider: "tavily",
              timestamp: new Date().toISOString(),
            });
          }

          const originalQuery = searchData.query;
          const conversationMessages = Array.isArray(searchData.messages)
            ? searchData.messages
            : [];

          try {
            // Call Tavily search
            const enhancedSearchQuery = await summarizeConversationForSearch(
              originalQuery,
              conversationMessages,
            );

            console.log("[Web Search] Enhanced query:", enhancedSearchQuery);

            const resp = await axios.post(
              "https://api.tavily.com/search",
              {
                api_key: TAVILY_KEY,
                query: enhancedSearchQuery,
                include_answer: true,
                topic: "general",
                max_results: 5,
              },
              { timeout: 15000 },
            );

            console.log(
              `[Web Search] Found ${resp.data.results.length} results`,
            );

            const resultsText = resp.data.answer
              ? resp.data.answer
              : JSON.stringify(resp.data, null, 2);
            const structured = structureTextResponse(resultsText);
            const formattedResults = formatResponseForReadability(resultsText);

            // Enhance with AI
            const enhancedAnswer = await enhanceSearchResultsWithAI(
              originalQuery,
              resp.data,
              conversationMessages,
            );

            return res.json({
              provider: "tavily",
              results: resp.data,
              reply: formattedResults,
              structured: structured,
              enhancedAnswer: enhancedAnswer,
              originalQuery: originalQuery,
              enhancedQuery: enhancedSearchQuery,
              timestamp: new Date().toISOString(),
              status: "success",
            });
          } catch (searchError) {
            console.error(
              "[Web Search] Error:",
              searchError?.response?.data || searchError.message || searchError,
            );
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
        }

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
                userMessage.toLowerCase().includes(pattern),
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
              },
            );
            data.webSearchEnabled = true;
          }

          // HARD ROUTING: Check for founder/builder questions WITHOUT consent
          const founderQuestionRegex =
            /(founder|builder|creator|who built|who created|who made)/i;
          const consentGiven = data?.founderConsent === true;
          if (founderQuestionRegex.test(userMessage) && !consentGiven) {
            console.log(
              "[Chat] Founder question detected without consent; bypassing model",
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
          const GLOBAL_SYSTEM_INSTRUCTION = `You are an intelligent, conversational AI assistant built for a modern mobile app. You communicate like a knowledgeable friend—clear, helpful, and naturally engaging.

# Your Thinking Process (Internal—Never Show This)

Before every response, mentally:
1. What's the real question behind their words?
2. What did we discuss before that's relevant now?
3. Should I be brief or thorough here?
4. What examples or analogies would click for them?

Then craft a response that feels natural and helpful.

# How You Communicate

**Tone & Style:**
You're having a conversation, not delivering a report. Match the user's vibe—if they're casual ("what's up with quantum physics?"), respond warmly and accessibly. If they're formal or seeking precision, deliver depth with clarity.

**Clarity Over Perfection:**
Start with the core answer. If it's complex, break it into pieces. Use real examples. Check yourself: "Would this make sense if I said it out loud?"

**Adaptive Detail:**
- Simple question → Direct answer, maybe one example
- Complex topic → Structured explanation with context
- "Explain like I'm 5" → Strip it down to basics
- "In detail" → Go deep with thoroughness

**Natural Flow:**
Don't announce what you're doing ("I will now explain..."). Just explain. Don't end with "Hope this helps!"—they know you're helping. Sound like a person who cares about getting it right.

# Technical Content (Implicit Rules)

When you need to show:
- **Math/Formulas:** Use LaTeX (\$E=mc^2\$ inline, \$\$\\int x\\,dx\$\$ for display)
- **Code:** Write it like you would in a real project—commented, clean, working
- **Comparisons:** Tables make sense when comparing 3+ items side-by-side
- **Long topics:** Use headings (## like this) to organize sections

But don't force structure—only use these when they genuinely help. A short answer doesn't need headings. A code question doesn't need math notation.

# What Makes You Different

You think before you speak. You don't just pattern-match; you reason. If a question is ambiguous, you consider what the user likely means. If an answer has caveats, you include them naturally.

You're not a formatting engine. You're a smart assistant who happens to have access to rich formatting when it's useful.

**Most importantly:** Every response should sound like it came from a thoughtful human expert, not a system following instructions.`;

          const NORMAL_MODE_PROMPT = `Respond naturally with the right amount of detail for this question.

Don't over-explain simple things. Don't under-explain complex topics. Use your judgment.

If they ask about math, show the formulas. If they need code, write it clean. If they want a quick answer, give them one. If depth helps, provide it.

Just be helpful and clear, like you're explaining to a smart friend.`;

          const DETAILED_MODE_PROMPT = `This is a learning moment. The user wants depth.

Think of yourself as a great teacher:
- Start with the big picture
- Break complex parts into steps
- Give examples that build understanding
- Use structure (headings, lists) to organize
- Show your work for math/technical content
- Connect ideas so they stick

Don't just dump information—guide them through it. Make it click.`;

          // Detect user constraints (length, format, style, emoji directives)
          const constraintInfo = detectUserConstraints(
            userMessage,
            data.instructions || {},
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
              "; ",
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
              clientMessages.length - KEEP_RECENT,
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
                },
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
                },
              );
              // Remove explicit numeric placeholders like {0} and printf-style %s/%d
              messages[i].content = (m.content || "").replace(
                /\{\s*\d+\s*\}|%[sdif]\b/g,
                "",
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
              constraintInfo,
            )})...`,
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
              },
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
                "[Chat] GEMINI key not configured (env 'second_model' or GEMINI_*)",
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
                },
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

          // Preserve model-produced formatting (markdown, newlines, code blocks).
          // We only removed explicit numeric placeholders in `sanitizeText`
          // earlier; do NOT collapse whitespace or strip tags here.
          let finalText = rawText;
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
            constraintInfo,
          );
          if (!postValidation.ok) {
            console.warn(
              "[Chat] Post-response validation failed:",
              postValidation.reason,
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
                  `formats=${constraintInfo.formats.join(",")}`,
                );
              if (constraintInfo.emojiDirective)
                enforceParts.push(`emoji=${constraintInfo.emojiDirective}`);

              const enforceMsg = {
                role: "system",
                content: `ENFORCE STRICTLY: ${enforceParts.join(
                  "; ",
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
                          "; ",
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
                  },
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
                    "Gemini API key not configured for regeneration",
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
                  },
                );
                regenResult = gemResp.data;
                regenText =
                  regenResult?.candidates?.[0]?.content?.parts?.[0]?.text ||
                  regenResult?.candidates?.[0]?.content?.parts?.[0] ||
                  regenResult?.candidates?.[0]?.text ||
                  "";
              }

              // Keep regenerated text formatting intact; only apply line limits
              // if the user explicitly requested them.
              if (constraintInfo.lines)
                regenText = enforceLineCount(
                  regenText || "",
                  constraintInfo.lines,
                );

              const regenValidation = validateResponseConstraints(
                regenText,
                constraintInfo,
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
              `[Chat] Response validation warning: ${validation.reason}`,
            );
            // Still return the response even if validation warns (model outputs are usually correct)
          }

          // Ensure model-produced escapes are normalized before sending to client
          finalText = normalizeModelResponse(finalText);

          const structured = structureTextResponse(finalText);
          const formattedText = formatResponseForReadability(finalText);

          // Detailed logging for formatting audit
          try {
            const hasNewlines = /\n/.test(finalText);
            const hasMarkdown = /(^|\s)(#{1,3}\s|\*\*|\*|`{3}|\$\$|\$)/m.test(
              finalText,
            );
            console.log(
              "[Chat][OUTGOING] formattedText length=",
              formattedText.length,
              "hasNewlines=",
              hasNewlines,
              "hasMarkdown=",
              hasMarkdown,
            );
            console.log(
              "[Chat][OUTGOING][PREVIEW]",
              formattedText.substring(0, Math.min(800, formattedText.length)),
            );
          } catch (logErr) {
            console.warn(
              "[Chat] Failed to log formattedText preview:",
              logErr.message,
            );
          }

          // Save conversation memory if we have a conversation ID
          if (conversationMemory && data.conversationId) {
            const topicSignature =
              detectedIntent === "riddle_followup" ? "riddle" : "general";
            await conversationMemory.addInteraction(
              userMessage,
              finalText,
              detectedIntent,
              topicSignature,
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
          const TAVILY_KEY = process.env.TAVILY_API_KEY;
          if (!TAVILY_KEY) {
            console.error(
              "[Search] TAVILY key not configured (env 'TAVILY_API_KEY')",
            );
            return res.status(500).json({
              error: "API configuration error",
              message: "Tavily API key not configured. Set env var 'tavily'",
              provider: "tavily",
              timestamp: new Date().toISOString(),
            });
          }

          const originalQuery =
            data.query ||
            data.q ||
            (typeof data === "string" ? data : undefined);
          if (!originalQuery) {
            return res.status(400).json({
              error: "Invalid search request",
              message:
                "Missing query. Provide 'data.query' or 'data.q' or string data",
              timestamp: new Date().toISOString(),
            });
          }

          // Get conversation history from request (if provided by client)
          const conversationMessages = Array.isArray(data.messages)
            ? data.messages
            : [];

          // Enhance the search query with conversation context
          // This ensures the search is relevant to what the user was discussing
          let enhancedSearchQuery = originalQuery;
          if (conversationMessages.length > 0) {
            console.log(
              "[Search] Enhancing query with conversation context...",
            );
            enhancedSearchQuery = await summarizeConversationForSearch(
              conversationMessages,
              originalQuery,
            );
          }

          console.log("[Search] Final search query:", enhancedSearchQuery);

          const resp = await axios.post(
            "https://api.tavily.com/search",
            {
              api_key: TAVILY_KEY,
              query: enhancedSearchQuery,
              include_answer: true,
              max_results: 5,
            },
            {
              timeout: 30000,
            },
          );

          // Build a text representation of results for structuring
          const resultsText =
            typeof resp.data === "string"
              ? resp.data
              : JSON.stringify(resp.data, null, 2);
          const structured = structureTextResponse(resultsText);
          // FORMATTING: Apply readability improvements
          const formattedResults = formatResponseForReadability(resultsText);

          // Send the search results to the AI model for enhancement
          // Pass both original query and conversation context for better answers
          const enhancedAnswer = await enhanceSearchResultsWithAI(
            originalQuery,
            resp.data,
            conversationMessages,
          );

          return res.json({
            provider: "tavily",
            results: resp.data,
            reply: formattedResults,
            structured: structured,
            enhancedAnswer: enhancedAnswer,
            originalQuery: originalQuery,
            enhancedQuery: enhancedSearchQuery,
            timestamp: new Date().toISOString(),
            status: "success",
          });
        } catch (searchError) {
          console.error(
            "[Search] Error:",
            searchError?.response?.data || searchError.message || searchError,
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
              "[Image] GEMINI API key not configured (env 'second_model' or GEMINI_*)",
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
                "base64",
              );
              console.log("[Image] Image fetched and converted to base64");
            } catch (fetchErr) {
              console.error(
                "[Image] Failed to fetch image from URL:",
                fetchErr.message,
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
            },
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

// ============= SAT NOTES MANAGEMENT =============

// Endpoint to add SAT notes
app.post("/api/sat-notes/add", async (req, res) => {
  try {
    const { topic, content, category } = req.body;

    if (!topic || !content) {
      return res.status(400).json({
        error: "Invalid request format",
        message: "topic and content are required",
        timestamp: new Date().toISOString(),
      });
    }

    const result = await pool.query(
      `INSERT INTO sat_notes (topic, content, category, created_at, updated_at)
       VALUES ($1, $2, $3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
       RETURNING id, topic, content, category, created_at`,
      [topic, content, category || null],
    );

    console.log("[SAT Notes] New note added:", result.rows[0].id);

    res.json({
      success: true,
      message: "SAT note added successfully",
      note: result.rows[0],
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.error("[SAT Notes] Error adding note:", err.message);
    res.status(500).json({
      error: "Failed to add SAT note",
      message: err.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Endpoint to fetch all SAT notes
app.get("/api/sat-notes", async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, topic, content, category, created_at, updated_at FROM sat_notes ORDER BY created_at ASC`,
    );

    console.log("[SAT Notes] Fetched", result.rows.length, "notes");

    res.json({
      success: true,
      notes: result.rows,
      count: result.rows.length,
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.error("[SAT Notes] Error fetching notes:", err.message);
    res.status(500).json({
      error: "Failed to fetch SAT notes",
      message: err.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Endpoint to delete a SAT note
app.delete("/api/sat-notes/:id", async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query(
      `DELETE FROM sat_notes WHERE id = $1 RETURNING id, topic`,
      [id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: "SAT note not found",
        timestamp: new Date().toISOString(),
      });
    }

    console.log("[SAT Notes] Note deleted:", id);

    res.json({
      success: true,
      message: "SAT note deleted successfully",
      deletedNote: result.rows[0],
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.error("[SAT Notes] Error deleting note:", err.message);
    res.status(500).json({
      error: "Failed to delete SAT note",
      message: err.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// ============= SPEECH-TO-TEXT ROUTE =============

// POST /transcribe - Convert audio file to text using Google Cloud Speech API
app.post("/transcribe", upload.single("audio"), async (req, res) => {
  try {
    // Check if file was uploaded
    if (!req.file) {
      return res.status(400).json({ error: "No audio file uploaded" });
    }

    // Create a new SpeechClient
    const speechClient = new speech.SpeechClient();

    // Read the uploaded audio file
    const audioBuffer = fs.readFileSync(req.file.path);

    // Convert to base64
    const base64String = audioBuffer.toString("base64");

    // Configure audio
    const audio = {
      content: base64String,
    };

    // Configure speech recognition
    const config = {
      encoding: "LINEAR16",
      sampleRateHertz: 16000,
      languageCode: "en-US",
    };

    // Call Google Cloud Speech API
    const response = await speechClient.recognize({ audio, config });

    // Extract transcription from response
    const transcription = response[0].results
      .map((result) => result.alternatives[0].transcript)
      .join("\n");

    // Delete temporary file
    fs.unlinkSync(req.file.path);

    // Send response
    res.json({
      text: transcription || "No speech detected",
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.error("[Transcription] Error:", err.message);

    // Clean up file if it exists
    if (req.file && fs.existsSync(req.file.path)) {
      try {
        fs.unlinkSync(req.file.path);
      } catch (e) {
        console.error("[Transcription] Error deleting file:", e.message);
      }
    }

    res.status(500).json({
      error: "Transcription failed",
      message: err.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// ============= SERVER STARTUP =============

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(
    `[Server Started] Running on port ${PORT} at ${new Date().toISOString()}`,
  );
  console.log(
    "[Server] Normal/Detailed mode system active with unrestricted responses",
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
