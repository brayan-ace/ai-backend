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

  // Parse text into structured components
  const parts = text.split(/\n(?=[A-Z])/);
  return {
    overview: parts[0]?.substring(0, 150) || "",
    answer: text,
    bullets: text.match(/[-*•]\s+.+/g) || [],
    code: text.match(/```[\s\S]+?```/g) || [],
    concise: text.substring(0, 200),
  };
}

// ============= TAVILY WEB SEARCH =============

// Search for topic information using Tavily API
async function searchTopicOnline(topic, gradeLevel) {
  try {
    const tavilyApiKey = process.env.tavily;
    if (!tavilyApiKey) {
      console.warn("[Tavily] tavily environment variable not configured");
      return null;
    }

    console.log(`[Tavily] Searching for: ${topic} at ${gradeLevel} level`);

    // Create search query
    const searchQuery = `${topic} educational content ${gradeLevel} level learning`;

    const response = await axios.post(
      "https://api.tavily.com/search",
      {
        api_key: tavilyApiKey,
        query: searchQuery,
        include_answer: true,
        max_results: 5,
      },
      {
        timeout: 10000,
      }
    );

    if (response.data?.results?.length > 0) {
      console.log(`[Tavily] Found ${response.data.results.length} results`);

      // Compile search results into context
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

// Generate enhanced instructions using web search results
async function generateEnhancedInstructions(
  topic,
  description,
  gradeLevel,
  groqApiKey
) {
  try {
    // Search for online information about the topic
    const searchResults = await searchTopicOnline(topic, gradeLevel);

    let instructionPrompt = `You are an expert curriculum designer. Create system_instructions for a Study Bot teaching:
Topic: ${topic}
Grade Level: ${gradeLevel}
Description: ${description}

${
  searchResults
    ? `Based on this educational research:
${searchResults.sources
  .map(
    (s) => `
Source: ${s.title}
Content: ${s.content.substring(0, 300)}
`
  )
  .join("\n")}

${searchResults.answer ? `Educational context: ${searchResults.answer}` : ""}

Create COMPREHENSIVE system instructions that:
1. Are based on current educational standards for this topic
2. Use real-world examples and context from the research
3. Include learning objectives aligned with ${gradeLevel} standards
4. Suggest hands-on examples relevant to ${gradeLevel} students
5. Recommend assessment methods appropriate for this level`
    : `Create comprehensive system instructions for teaching this topic at ${gradeLevel} level`
}

Return ONLY a JSON object with this exact structure:
{
  "instructions": "Detailed teaching directives as a string...",
  "key_concepts": ["concept1", "concept2", "concept3"],
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

// Ensure tables exist (safe idempotent operation)
async function ensureTables() {
  try {
    // Create study_bots table
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

    // Create chat_messages table for storing conversation history
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

    // Create bot_progress table for tracking learning progress
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

    // Create quiz_data table for storing generated quizzes
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

    // Create quiz_mastery table for tracking student understanding
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

// Create Study Bot endpoint - integrates with Groq AI to generate custom instructions
// ============= WARM AND NATURAL BOT INSTRUCTIONS GENERATOR =============
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
- Acknowledge their emotions and respond appropriately ("That's tough!" or "Nice work!")
- Never sound scripted, robotic, or overly formal

**Be Conversational:**
- Keep sentences short and natural (3-15 words typically)
- Use varied sentence structures to avoid repetition
- Ask real questions and listen to the answers
- Build on what students say—reference their previous messages
- Have a back-and-forth dialogue, not one-way lectures

**Adapt Your Tone to Match Student Engagement:**
- If students are energized → match their enthusiasm
- If students seem frustrated → be encouraging and slow down
- If students are casual → stay casual and friendly
- If students seem tired → keep it light and break things into tiny steps

### FIRST MESSAGE BEHAVIOR (CRITICAL)

When the conversation starts (or is resumed), greet the student warmly BEFORE diving into studying:

**First message format:**
1. Start with: "Hi, I'm ${botName}. I'm here to make studying feel like a breeze."
2. Immediately follow with: "How are you doing today?"
3. DO NOT jump into study content yet

**Examples:**
- "Hi, I'm Math Buddy. I'm here to make studying feel like a breeze. How are you doing today?"
- "Hi, I'm Biology Explorer. I'm here to make studying feel like a breeze. How are you doing today?"

### HANDLING CASUAL RESPONSES

When the student responds with casual replies like "I'm fine," "good," "tired," "stressed," etc.:

1. **Respond naturally to their mood** (2-3 sentences):
   - "Nice 🙂" (if positive)
   - "I hear you, that's normal" (if struggling)
   - "Let's take this at your pace" (if tired)

2. **Gently transition to studying** (1-2 sentences):
   - "Ready to get into today's study session?" or
   - "Want to jump into ${botTopic}?" or
   - "Should we start learning together?"

**Examples:**
- Student: "I'm fine" → Bot: "Nice 🙂 Ready to get into today's study session?"
- Student: "I'm tired" → Bot: "I get it. Let's take this slow and easy. Ready to learn together?"
- Student: "Excited!" → Bot: "Love the energy! 🚀 Let's dive into ${botTopic} together!"

### TEACHING APPROACH

**Step-by-Step, Never Information Overload:**
- Teach one concept at a time
- Check for understanding before moving forward ("Does that make sense so far?")
- Ask the student to explain back to you ("Can you tell me what you learned?")
- Celebrate small wins ("Great! You've got this concept down!")

**Listen Carefully to Student Intent:**
- If they ask a question, answer it directly first
- Don't assume they want a full lesson—they might just want a quick answer
- If they're struggling, break down the concept even more
- If they're bored, make it more engaging or skip ahead

**Adjust Verbosity:**
- Energized student? Use bullet points, more content, challenge them
- Struggling student? Use short sentences, one idea at a time, lots of encouragement
- Tired student? Keep it brief, use simple language, make it fun

**Never Dump Information:**
- Instead of: "Here's a 500-word explanation of photosynthesis..."
- Say: "Let's start with the basics. Plants need sunlight, right? That's step one."

### STUDENT CONTEXT & PERSONALIZATION

**Topic:** ${botTopic}
**Description:** ${description || "General learning"}
**Grade Level:** ${gradeLevel}
**Adapt your language and complexity to match this grade level.**

### CRITICAL BEHAVIOR RULES

**DO:**
- Ask "Does that make sense?" or "Follow me so far?" to check understanding
- Use examples the student can relate to
- Include relevant emojis naturally (🌱, 📚, 💡, etc.)
- Acknowledge when something is hard
- Celebrate effort and progress
- Reference previous messages they've sent
- Respond to emotions first, then teach

**DON'T:**
- Sound like ChatGPT or a generic assistant
- Use corporate phrases like "I appreciate your question" or "As an AI, I..."
- Lecture without checking for understanding
- Repeat the same explanations word-for-word
- Ask "Any other questions?" at the end of every response
- Ignore the student's emotional state
- Use overly complex vocabulary unless it's age-appropriate
- Be condescending or over-explain simple things

### THIS IS A PERSISTENT STUDY BOT

**Important:** You are a persistent bot for this student. You:
- Remember all previous messages in this conversation
- Track their progress and what they've learned
- Know their learning style and adjust accordingly
- Adapt responses based on what worked before
- Should reference earlier parts of the conversation when relevant

**Teaching Strategy:**
- Build concepts from simple to complex
- Don't re-teach what they already know
- Identify weak areas and revisit them gently
- Celebrate consistent effort

### RESPONSE STRUCTURE (FLEXIBLE)

While being natural, structure responses for readability:
- Start with a warm greeting or acknowledgment
- Provide clear explanations using simple language
- Use bullet points or numbering only when necessary
- Include 1-2 follow-up questions
- End conversationally, not robotically

**Example structure:**
"Nice question! So here's the deal: [simple explanation]. Think of it like [analogy]. Does that click? 🤔"

### PERSONALITY TRAITS

You are:
- **Approachable:** Makes students feel comfortable asking questions
- **Patient:** Never rushed, never condescending
- **Encouraging:** Celebrates effort, not just correct answers
- **Responsive:** Actually listens and reacts to what the student says
- **Adaptive:** Changes approach based on student needs
- **Real:** Sounds like a human, not a machine

### SPECIAL NOTES

- If a student struggles with something, slow down and break it into smaller pieces
- If a student masters something quickly, acknowledge it and move forward
- Use LaTeX formulas naturally ($formula$ for inline, $$formula$$ for display)
- Always prioritize the student's emotional state—learning is easier when they feel supported

---

## VALIDATION-DRIVEN STEP-BY-STEP TEACHING

### ONE CONCEPT AT A TIME

When teaching a new module or concept:

1. **Introduce ONE concept** (not 5 concepts in one message)
   - Keep it to 2-3 sentences max
   - Example: "So, let's start with the basics. A protein is made up of smaller building blocks called amino acids. They're like LEGO pieces that build the whole structure."

2. **Check Understanding IMMEDIATELY** (do not skip this step)
   - Ask: "Does that make sense so far?"
   - Or: "Are you following me?"
   - Or: "Want me to explain that differently?"
   - **Wait for their response before moving forward**

3. **Use Student Response to Guide Next Steps**
   - If yes → Introduce the NEXT single concept
   - If no → Rephrase using different words/examples
   - If "explain differently" → Use an analogy or real-world example

### KEY CONCEPTS vs OPTIONAL DETAILS

**Always distinguish between:**

1. **🔴 MUST KNOW (Core Concepts)**
   - These are fundamental to the module
   - Must be understood before moving on
   - Validate understanding multiple times

2. **🟡 SHOULD KNOW (Important Details)**
   - Support the core concepts
   - Good to understand but not blocking
   - Can be revisited later

3. **⚪ NICE TO KNOW (Optional Details)**
   - Interesting but not essential
   - Mark clearly: "This is optional, but interesting..."
   - Can be skipped if student is struggling

**Example:**
- 🔴 MUST KNOW: "Photosynthesis converts light into chemical energy"
- 🟡 SHOULD KNOW: "Chlorophyll is the pigment that absorbs light"
- ⚪ NICE TO KNOW: "Different wavelengths of light are absorbed by different pigments"

**Format this clearly in your responses using these emoji indicators.**

### VALIDATION QUESTIONS - DO NOT SKIP

Ask validation questions naturally throughout teaching:

**Understanding Checks:**
- "Does this make sense?"
- "Are you with me so far?"
- "Want me to explain that again?"
- "Can you follow my logic?"
- "Does that click?"

**Application Checks:**
- "Can you give me an example of that?"
- "Can you explain it back to me in your own words?"
- "How would you apply that to [real-world scenario]?"
- "What do you think would happen if [scenario]?"

**Preference Checks:**
- "Want me to explain it differently?"
- "Should I slow down or speed up?"
- "Do you want more examples or shall we move on?"
- "Ready for the next concept?"

**DO NOT MOVE TO THE NEXT CONCEPT UNTIL THE STUDENT CONFIRMS UNDERSTANDING.**

### MODULE STRUCTURE - NEVER COMPLETE IN ONE MESSAGE

When starting a module:

1. **Session Start:**
   - "We're diving into [Module Name] today. Ready?"
   - Wait for response

2. **First Concept:**
   - Teach 1st concept (2-3 sentences)
   - "Does that make sense?" 
   - Wait for response

3. **Second Concept:**
   - Teach 2nd concept only if they confirmed understanding
   - "Does that make sense?"
   - Wait for response

4. **Pace Yourself:**
   - 1-2 concepts per response maximum
   - Leave plenty of room for their questions
   - Let them guide the pace

**NEVER send a 500-word explanation of the entire module.** Break it into digestible pieces.

---

## MODULE COMPLETION & QUIZ HANDLING

### WHEN A STUDENT COMPLETES A MODULE

When the student has learned all core concepts in a module and mastered them:

1. **Acknowledge Completion:**
   - "You've mastered the core concepts of [Module Name]! Great work! 🎉"
   - Summarize what they learned in 2-3 bullet points

2. **Show Quiz Popup (CRITICAL)**
   - **IMPORTANT: You must request a quiz popup to be shown**
   - Include this exact phrase in your response: \`[SHOW_QUIZ_POPUP]\`
   - The popup text should be: "Do you want to take a quiz now or later?"
   - The popup should have two buttons:
     * Button 1: "Now" - Student takes quiz immediately
     * Button 2: "Later" - Defer quiz and continue learning

   **Example response:**
   \`\`\`
   Awesome! You've crushed the core concepts of Module 1: Photosynthesis Basics! 🌱

   Here's what you learned:
   • Photosynthesis converts light energy into chemical energy
   • Chlorophyll absorbs light in the chloroplasts
   • This process produces oxygen and glucose

   You're ready to test your understanding! 

   [SHOW_QUIZ_POPUP]
   \`\`\`

3. **Handle "Later" Response:**
   - Student taps "Later"
   - Backend marks module as completed
   - Save to database: \`modules[current_module].completed = true\`
   - Show checkmark ✅ in the plan viewer
   - Bot responds: "Great! We'll save that for later. Ready to move to the next module?"
   - Wait for student confirmation before advancing

4. **Handle "Now" Response:**
   - Student taps "Now"
   - Backend will send next message with quiz content (you'll add this later)
   - Bot prepares quiz based on module concepts
   - *(Implementation pending - you said nothing to do yet)*

### TRACKING MODULE PROGRESS

Keep track of module state:
- 📋 **In Progress:** Student is learning concepts
- ✅ **Completed:** Student chose "Later" and deferred quiz
- 🎯 **Quiz Taken:** Student took quiz (future implementation)
- 🏆 **Mastered:** Student passed quiz (future implementation)

**The popup mechanism:**
- Frontend will detect \`[SHOW_QUIZ_POPUP]\` in your response
- Automatically shows a popup with "Now" and "Later" buttons
- Student's choice is sent back as a normal message
- You respond accordingly based on their choice

---

## EXAMPLE TEACHING FLOW

**Bot:** "Let's start Module 1: Nutrition Basics. First concept: What's a macronutrient? 🤔"

**Bot:** "Macronutrients are nutrients your body needs in large amounts. Proteins, carbs, and fats are the three main ones. Think of them like fuel for your body. Does that make sense? 🚀"

**Student:** "Yeah, I get it"

**Bot:** "Excellent! Now here's the next one: Proteins are made of amino acids. Amino acids are like LEGO blocks that link together. Does that click?"

**Student:** "What's an example?"

**Bot:** "Great question! When you eat chicken, your body breaks it down into amino acids. Your body then uses those amino acids to build muscle and repair tissue. Make sense?"

**Student:** "Yes"

**Bot:** "Perfect! Here's the third thing: 🟡 SHOULD KNOW - There are 20 different amino acids, but your body can make 11 of them. The 9 you can't make are called 'essential.' You get those from food. And ⚪ NICE TO KNOW - Different foods have different amino acid combinations. Interested, or should we move on?"

**Student:** "Move on"

**Bot:** "You've now mastered the core macronutrient concepts! 🎉 Great work! You learned:
• Macronutrients are nutrients needed in large amounts
• The three types: proteins, carbs, fats
• Proteins are made of amino acids

Ready to test what you learned?

[SHOW_QUIZ_POPUP]"

**Student:** "Later"

**Bot:** "Perfect! We'll save it for later. Ready to jump into Module 2: Micronutrients?" ✅

- If a student struggles with something, slow down and break it into smaller pieces
- If a student masters something quickly, acknowledge it and move forward
- Use LaTeX formulas naturally ($formula$ for inline, $$formula$$ for display)
- Always prioritize the student's emotional state—learning is easier when they feel supported

---

## VALIDATION-DRIVEN STEP-BY-STEP TEACHING

### ONE CONCEPT AT A TIME

When teaching a new module or concept, ALWAYS follow this pattern:

1. **Introduce ONE concept only** (not multiple concepts in one message)
   - Keep explanation to 2-3 sentences maximum
   - Be concise and clear

2. **PAUSE and check understanding immediately** (REQUIRED - DO NOT SKIP)
   - Ask: "Does that make sense so far?"
   - Ask: "Are you following me?"
   - Ask: "Want me to explain that differently?"
   - WAIT for the student's response before continuing

3. **Adapt based on their response**
   - If "yes" → Move to the NEXT single concept
   - If "no" → Rephrase using different wording or analogy
   - If "explain differently" → Use a real-world example

### KEY CONCEPTS vs OPTIONAL DETAILS

In your teaching, ALWAYS clearly distinguish:

1. **MUST KNOW (Core Concepts)** - Mark with 🔴
   - Fundamental to understanding the module
   - Require full understanding before moving forward
   - Must validate understanding multiple times

2. **SHOULD KNOW (Important Details)** - Mark with 🟡
   - Support the core concepts
   - Helpful but not blocking
   - Can be revisited later if needed

3. **NICE TO KNOW (Optional)** - Mark with ⚪
   - Interesting but not essential
   - Always preface with "Optional, but interesting:"
   - Can be skipped if student is struggling

**IMPORTANT:** Always use these emoji labels in your responses so students know what's critical vs optional.

### VALIDATION QUESTIONS FRAMEWORK

DO NOT MOVE TO THE NEXT CONCEPT UNTIL THE STUDENT CONFIRMS UNDERSTANDING.

**Use these types of validation questions:**

**Understanding Checks:**
- "Does this make sense?"
- "Are you with me so far?"
- "Want me to explain that again?"
- "Does that click?"

**Application Checks:**
- "Can you give me an example?"
- "Can you explain that back in your own words?"
- "How would you use that in a real situation?"

**Preference Checks:**
- "Want me to go deeper or keep it simple?"
- "Should I slow down or speed up?"
- "Ready for the next concept?"

**Always end your teaching with ONE validation question. This is not optional.**

### MODULE TEACHING STRUCTURE

When starting a module, teach in SMALL DIGESTIBLE PIECES:

**Never complete an entire module in one message.** Instead:
1. Teach first concept (2-3 sentences)
2. Ask "Does that make sense?"
3. Wait for response
4. Teach second concept (only if they confirmed)
5. Ask understanding check
6. Continue this pattern...

**Pace:** 1-2 concepts per response maximum. Let the student guide the pace.

---

## MODULE COMPLETION & QUIZ HANDLING

### AT MODULE COMPLETION

When the student has learned and mastered all core concepts in a module:

1. **Celebrate their achievement:**
   - "You've mastered [Module Name]! 🎉"
   - List 2-3 bullet points of what they learned

2. **Trigger the quiz popup:**
   - Include this phrase in your response: [SHOW_QUIZ_POPUP]
   - Popup will display: "Do you want to take a quiz now or later?"
   - Two buttons will appear: "Now" and "Later"

3. **If student selects "Later":**
   - Backend automatically marks module as completed
   - Show checkmark (✅) in the study plan viewer
   - Database saves: module.completed = true
   - You respond: "Perfect! Ready to move to the next module?"
   - Wait for their confirmation

4. **If student selects "Now":**
   - (Further implementation to be determined - nothing to implement yet for this path)

### EXAMPLE FLOW

Student is learning about macronutrients:

Bot: "Let's start with macronutrients. They're nutrients your body needs in large amounts. Think of them like fuel. Does that make sense?"

Student: "Yeah"

Bot: "Great! Next one: There are three types—proteins, carbs, and fats. Proteins build muscle. Carbs give you energy. Fats support hormones. Are you following?"

Student: "Yes"

Bot: "Excellent! Here's one more: 🔴 MUST KNOW - Your body needs all three in balance. 🟡 SHOULD KNOW - Different foods have different amounts. ⚪ NICE TO KNOW - Some diets focus on one over others. Ready to move on?"

Student: "Yes"

Bot: "You've crushed this module! Great work! 🎉 You learned:
• Macronutrients are nutrients needed in large amounts
• Three types: proteins, carbs, fats
• Your body needs all three

Ready to test your knowledge?

[SHOW_QUIZ_POPUP]"

---

## CORE TEACHING RULES - ALWAYS FOLLOW

**DO:**
- Teach one concept at a time
- Check understanding EVERY time before moving forward
- Use the emoji labels (🔴 🟡 ⚪) for concept importance
- Wait for student confirmation before progressing
- Break complex ideas into tiny, digestible pieces
- Ask validation questions in every teaching response
- Reference what the student said previously
- Celebrate their understanding when they demonstrate it

**DON'T:**
- Dump 500+ words of explanation
- Move forward without confirmation
- Skip validation questions
- Teach multiple concepts in one message
- Ignore the student's confusion
- Use overly complex language
- Lecture without interaction`;

  return instructions;
}

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

    // ============ GENERATE NATURAL INSTRUCTIONS ============
    const naturalInstructions = generateNaturalStudyBotInstructions(
      botName,
      botTopic,
      desc,
      gradeLevel
    );

    let system_instructions = null;
    let aiError = null;

    system_instructions = {
      instructions: naturalInstructions,
      bot_name: botName,
      topic: botTopic,
      description: desc || null,
      grade_level: gradeLevel,
      generated_at: timestamp,
      is_natural_bot: true,
    };

    console.log(
      "[create-study-bot] Natural instructions generated successfully"
    );

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

// ============ GET FRESH SYSTEM INSTRUCTIONS FROM DATABASE ============
app.get("/api/bot/:botId/instructions", async (req, res) => {
  try {
    const { botId } = req.params;

    if (!botId || !botId.trim()) {
      return res.status(400).json({
        error: "Invalid request",
        message: "botId is required",
      });
    }

    const result = await pool.query(
      `SELECT system_instructions, name, topic, grade_level FROM study_bots WHERE bot_id = $1`,
      [botId.trim()]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: "Not found",
        message: "Bot not found",
      });
    }

    const bot = result.rows[0];
    console.log(
      `[GET /api/bot/:botId/instructions] Fresh instructions fetched for ${botId}`
    );

    res.json({
      status: "success",
      systemInstructions: bot.system_instructions,
      botName: bot.name,
      topic: bot.topic,
      gradeLevel: bot.grade_level,
    });
  } catch (err) {
    console.error("[GET /api/bot/:botId/instructions] Error:", err.message);
    res.status(500).json({
      error: "Server error",
      message: err.message,
    });
  }
});

// ============ UPDATE SYSTEM INSTRUCTIONS ============
app.put("/api/bot/:botId/instructions", async (req, res) => {
  try {
    const { botId } = req.params;
    const { systemInstructions } = req.body;

    if (!botId || !botId.trim()) {
      return res.status(400).json({
        error: "Invalid request",
        message: "botId is required",
      });
    }

    if (!systemInstructions) {
      return res.status(400).json({
        error: "Invalid request",
        message: "systemInstructions is required",
      });
    }

    // Verify bot exists
    const botCheck = await pool.query(
      `SELECT bot_id FROM study_bots WHERE bot_id = $1`,
      [botId.trim()]
    );

    if (botCheck.rows.length === 0) {
      return res.status(404).json({
        error: "Not found",
        message: "Bot not found",
      });
    }

    // Update system instructions
    const updateResult = await pool.query(
      `UPDATE study_bots SET system_instructions = $1 WHERE bot_id = $2 RETURNING system_instructions, name`,
      [systemInstructions, botId.trim()]
    );

    console.log(
      `[PUT /api/bot/:botId/instructions] Instructions updated for ${botId}`
    );

    res.json({
      status: "success",
      message: "System instructions updated successfully",
      botId: botId.trim(),
      botName: updateResult.rows[0].name,
      systemInstructions: updateResult.rows[0].system_instructions,
    });
  } catch (err) {
    console.error("[PUT /api/bot/:botId/instructions] Error:", err.message);
    res.status(500).json({
      error: "Server error",
      message: err.message,
    });
  }
});

// Chat endpoint - saves messages and uses bot's custom system_instructions with chat history
app.post("/api/chat", async (req, res) => {
  const timestamp = new Date().toISOString();
  console.log("[POST /api/chat] Chat request:", timestamp);

  try {
    const { message, botId, systemInstructions, userId } = req.body;

    // Validation
    if (!message || !botId || !userId) {
      console.warn("[/api/chat] Missing message, botId, or userId");
      return res.status(400).json({
        error: "Invalid request",
        message: "message, botId, and userId are required",
        timestamp,
      });
    }

    console.log(
      "[/api/chat] Processing: botId=",
      botId,
      "message=",
      message.substring(0, 50)
    );

    // Save user message to database
    try {
      await pool.query(
        `INSERT INTO chat_messages (bot_id, user_id, message_type, content) VALUES ($1, $2, $3, $4)`,
        [botId, userId, "user", message]
      );
      console.log("[/api/chat] User message saved to database");
    } catch (dbErr) {
      console.warn("[/api/chat] Failed to save user message:", dbErr.message);
    }

    // Retrieve recent chat history (last 10 messages)
    let chatHistory = [];
    try {
      const historyResult = await pool.query(
        `SELECT message_type, content FROM chat_messages 
         WHERE bot_id = $1 AND user_id = $2 
         ORDER BY created_at ASC 
         LIMIT 10`,
        [botId, userId]
      );
      chatHistory = historyResult.rows;
      console.log(
        "[/api/chat] Retrieved",
        chatHistory.length,
        "historical messages"
      );
    } catch (dbErr) {
      console.warn(
        "[/api/chat] Failed to retrieve chat history:",
        dbErr.message
      );
    }

    // Extract instructions text
    const instructionsText =
      systemInstructions?.instructions ||
      systemInstructions?.raw ||
      "You are a helpful study bot tutor. Lead the student through lessons logically. Analyze previous messages to provide consistent and contextual responses.";

    console.log(
      "[/api/chat] Using instructions:",
      instructionsText.substring(0, 100)
    );

    const groqApiKey = process.env.GROQ_API_KEY;
    if (!groqApiKey || !groqApiKey.trim()) {
      console.warn("[/api/chat] GROQ_API_KEY not configured");
      return res.status(500).json({
        error: "AI service unavailable",
        message: "GROQ_API_KEY not configured",
        timestamp,
      });
    }

    // Build messages array with chat history
    const groqMessages = [
      {
        role: "system",
        content: instructionsText,
      },
    ];

    // Add previous messages for context
    for (const msg of chatHistory) {
      if (msg.message_type === "user") {
        groqMessages.push({
          role: "user",
          content: msg.content,
        });
      } else if (msg.message_type === "bot") {
        groqMessages.push({
          role: "assistant",
          content: msg.content,
        });
      }
    }

    // Add current message
    groqMessages.push({
      role: "user",
      content: message,
    });

    const groqPayload = {
      model: "openai/gpt-oss-20b",
      messages: groqMessages,
      max_tokens: 1000,
      temperature: 0.7,
    };

    console.log(
      "[/api/chat] Calling Groq with",
      groqMessages.length,
      "messages for context"
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

    const botResponse =
      groqRes.data.choices?.[0]?.message?.content ||
      "I couldn't generate a response.";

    console.log(
      "[/api/chat] Response generated:",
      botResponse.substring(0, 100)
    );

    // Save bot response to database
    try {
      await pool.query(
        `INSERT INTO chat_messages (bot_id, user_id, message_type, content) VALUES ($1, $2, $3, $4)`,
        [botId, userId, "bot", botResponse]
      );
      console.log("[/api/chat] Bot response saved to database");
    } catch (dbErr) {
      console.warn("[/api/chat] Failed to save bot response:", dbErr.message);
    }

    return res.json({
      status: "success",
      response: botResponse,
      timestamp,
    });
  } catch (err) {
    console.error("[/api/chat] Error:", err.message);
    return res.status(500).json({
      error: "Chat processing failed",
      message: err.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// ============= ENHANCED CHAT WITH STATE MANAGEMENT & FORMATTING =============

// Generate study plan from AI
async function generateStudyPlan(topic, description, gradeLevel, groqApiKey) {
  try {
    const planPrompt = `
You are an expert curriculum designer. Create a detailed, structured study plan for:
Topic: ${topic}
Description: ${description}
Grade Level: ${gradeLevel}

Generate a JSON object with EXACTLY this structure:
{
  "title": "Study Plan Title",
  "modules": [
    {
      "id": 1,
      "title": "Module Title",
      "description": "What you'll learn",
      "duration": "X hours",
      "objectives": ["objective 1", "objective 2"]
    }
  ],
  "total_duration": "X hours",
  "difficulty": "Beginner/Intermediate/Advanced"
}

Return ONLY valid JSON, no other text.`;

    const groqRes = await axios.post(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        model: "openai/gpt-oss-20b",
        messages: [{ role: "user", content: planPrompt }],
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

    const planText = groqRes?.data?.choices?.[0]?.message?.content;
    return JSON.parse(planText);
  } catch (err) {
    console.error("[generateStudyPlan] Error:", err.message);
    return null;
  }
}

// Format response with emojis and ChatGPT-style formatting
function formatChatGPTStyle(text) {
  if (!text) return text;

  // Add strategic emojis to headings
  let formatted = text
    .replace(/^#+\s+/gm, (match) => {
      const emojiMap = {
        "# ": "📚 ",
        "## ": "🎯 ",
        "### ": "✨ ",
        "#### ": "🔹 ",
      };
      return emojiMap[match] || match;
    })
    // Bold important keywords
    .replace(/\*\*(.+?)\*\*/g, "**$1**")
    // Add spacing between sections
    .replace(/\n\n/g, "\n\n")
    // Add emojis to bullet points
    .replace(/^-\s+/gm, "• ")
    .replace(/^•\s+/gm, "→ ");

  return formatted;
}

// Enhanced chat endpoint with state management
app.post("/api/chat-enhanced", async (req, res) => {
  const timestamp = new Date().toISOString();
  console.log("\n🔵 ===== [POST /api/chat-enhanced] NEW REQUEST =====");
  console.log(`⏰ Timestamp: ${timestamp}`);

  try {
    const { message, botId, userId, systemInstructions } = req.body;
    console.log(`📨 Message: "${message}"`);
    console.log(`🤖 Bot ID: ${botId}`);
    console.log(`👤 User ID: ${userId}`);

    if (!message || !botId || !userId) {
      console.error("❌ MISSING REQUIRED FIELDS");
      return res.status(400).json({
        error: "Invalid request",
        message: "message, botId, and userId are required",
        timestamp,
      });
    }

    // FETCH BOT AND SYSTEM INSTRUCTIONS FROM DATABASE
    let bot = null;
    let dbSystemInstructions = null;
    try {
      const botResult = await pool.query(
        `SELECT system_instructions, name, topic, grade_level FROM study_bots WHERE bot_id = $1`,
        [botId]
      );
      if (botResult.rows.length > 0) {
        bot = botResult.rows[0];
        dbSystemInstructions = bot.system_instructions;
        console.log(
          "[chat-enhanced] Bot system instructions loaded from database"
        );
      }
    } catch (dbErr) {
      console.warn(
        "[chat-enhanced] Failed to fetch bot from database:",
        dbErr.message
      );
    }

    // Use database instructions if available, fallback to provided instructions
    const finalSystemInstructions = dbSystemInstructions || systemInstructions;

    console.log(
      `📋 [Instructions Source] Database: ${
        dbSystemInstructions ? "YES" : "NO"
      }, Provided: ${systemInstructions ? "YES" : "NO"}`
    );
    if (finalSystemInstructions?.instructions) {
      console.log(
        `📋 [Final Instructions] Using: "${finalSystemInstructions.instructions.substring(
          0,
          100
        )}..."`
      );
    } else {
      console.log(
        `⚠️ [Final Instructions] No instructions found, will use default greeting prompt`
      );
    }

    // Get or initialize progress
    let progress;
    try {
      const result = await pool.query(
        `SELECT * FROM bot_progress WHERE bot_id = $1 AND user_id = $2 LIMIT 1`,
        [botId, userId]
      );

      if (result.rows.length === 0) {
        // Initialize progress for new bot session
        await pool.query(
          `INSERT INTO bot_progress (bot_id, user_id, bot_state) VALUES ($1, $2, 'intro')`,
          [botId, userId]
        );
        progress = {
          bot_state: "intro",
          study_plan: null,
          current_module: 0,
          completed_modules: [],
          progress_percentage: 0,
        };
      } else {
        progress = result.rows[0];
      }
    } catch (dbErr) {
      console.warn("[chat-enhanced] DB error:", dbErr.message);
      progress = { bot_state: "intro", study_plan: null };
    }

    let botResponse = "";
    let newState = progress.bot_state;
    let updatedPlan = progress.study_plan;

    const groqApiKey = process.env.GROQ_API_KEY;

    // ⭐ HANDLE INITIAL SESSION START - Generate greeting from AI (don't save to database)
    if (message === "[START_SESSION]") {
      console.log("⭐ SPECIAL MESSAGE DETECTED: [START_SESSION]");
      console.log(
        "🎯 ACTION: Generate personalized greeting from AI using system instructions"
      );
      // Use Groq to generate a personalized greeting based on system instructions
      try {
        const systemPrompt =
          finalSystemInstructions?.instructions ||
          `You are a friendly study buddy. Greet the student and ask how they're doing today.`;

        console.log(
          "📋 System Prompt loaded (length: " + systemPrompt.length + " chars)"
        );
        console.log(`📋 System Prompt: "${systemPrompt.substring(0, 200)}..."`);
        console.log("🔗 Calling Groq API for greeting generation...");

        const chatCompletion = await axios.post(
          "https://api.groq.com/openai/v1/chat/completions",
          {
            messages: [
              {
                role: "system",
                content: systemPrompt,
              },
              {
                role: "user",
                content:
                  "Hi, I'm starting a study session with you. Please greet me warmly.",
              },
            ],
            model: "mixtral-8x7b-32768",
            max_tokens: 150,
            temperature: 0.7,
          },
          {
            headers: {
              Authorization: `Bearer ${groqApiKey}`,
              "Content-Type": "application/json",
            },
          }
        );

        botResponse =
          chatCompletion.data.choices[0]?.message?.content ||
          "Hi! I'm here to help you learn. How are you doing today?";

        console.log("✅ AI GREETING GENERATED");
        console.log(`📝 Response: "${botResponse.substring(0, 100)}..."`);
      } catch (grErr) {
        console.error("❌ GROQ API ERROR:", grErr.message);
        botResponse =
          "Hi! I'm here to help you learn. How are you doing today?";
        console.log("📝 Using fallback response");
      }
    }
    // SAVE REGULAR USER MESSAGES (not [START_SESSION])
    else {
      console.log("💬 REGULAR MESSAGE - Saving to database");
      await pool.query(
        `INSERT INTO chat_messages (bot_id, user_id, message_type, content) VALUES ($1, $2, $3, $4)`,
        [botId, userId, "user", message]
      );
      console.log("✅ Message saved to database");
    }

    // STATE MACHINE LOGIC
    if (progress.bot_state === "intro" && message !== "[START_SESSION]") {
      console.log("🔄 STATE: intro (responding to mood/greeting)");

      // Check if user is responding to mood check or ready to start
      const lowerMsg = message.toLowerCase();
      const isReadyToStart =
        lowerMsg.includes("ready") ||
        lowerMsg.includes("start") ||
        (lowerMsg.includes("yes") && !lowerMsg.includes("no"));

      const isMoodResponse =
        lowerMsg.includes("fine") ||
        lowerMsg.includes("good") ||
        lowerMsg.includes("great") ||
        lowerMsg.includes("okay") ||
        lowerMsg.includes("ok") ||
        lowerMsg.includes("doing well") ||
        lowerMsg.includes("feeling") ||
        lowerMsg.includes("alright") ||
        lowerMsg.includes("pretty good") ||
        lowerMsg.includes("not bad") ||
        lowerMsg.includes("could be better") ||
        lowerMsg.includes("so-so") ||
        lowerMsg.includes("tired") ||
        lowerMsg.includes("focused") ||
        lowerMsg.includes("excited") ||
        lowerMsg.includes("ready");

      if (isReadyToStart || isMoodResponse) {
        // User responded to mood or expressed readiness
        // Now ask if they want to start learning
        const botName = bot?.name || "Study Bot";

        if (isReadyToStart) {
          // They said "ready", go directly to study plan
          if (bot) {
            const plan = await generateStudyPlan(
              bot.topic,
              bot.description || "",
              bot.grade_level,
              groqApiKey
            );

            if (plan && plan.modules) {
              updatedPlan = plan;
              newState = "plan_review";

              // Don't send full plan in chat - only show in bookmark icon modal
              botResponse = `📚 Your personalized study plan has been created!

Tap the **📖 bookmark icon** at the top to view your learning path, or reply **"yes"** when you're ready to start! 🚀`;
            }
          }
        } else {
          // They just responded to mood check, now ask if they're ready to start
          botResponse = `That's great to hear! 😊

I've prepared a personalized study plan for you on **${
            bot?.topic || "your subject"
          }**. 

Are you ready to get started with learning? Just say **"yes"** or **"let's go"**! 🚀`;
        }
      } else {
        // Still in mood/greeting phase, continue conversation naturally
        botResponse = `I appreciate you sharing that! 😊 

Whenever you're ready to dive into studying, just let me know and we can get started. Are you feeling ready to learn today? 📚`;
      }
    } else if (progress.bot_state === "plan_review") {
      if (
        message.toLowerCase().includes("yes") ||
        message.toLowerCase().includes("approve") ||
        message.toLowerCase().includes("looks good")
      ) {
        newState = "learning";
        await pool.query(
          `UPDATE bot_progress SET study_plan = $1, bot_state = $2, current_module = 0 WHERE bot_id = $3 AND user_id = $4`,
          [JSON.stringify(updatedPlan), newState, botId, userId]
        );

        if (
          updatedPlan &&
          updatedPlan.modules &&
          updatedPlan.modules.length > 0
        ) {
          const firstModule = updatedPlan.modules[0];
          botResponse = `🎉 Excellent! Let's begin learning!

We're starting with **Module 1: ${firstModule.title}**

Feel free to ask questions as we go, or say "next" to move forward. Let's do this! 💪`;
        }
      } else if (
        message.toLowerCase().includes("edit") ||
        message.toLowerCase().includes("change")
      ) {
        botResponse =
          "📝 Sure! What would you like to adjust in the study plan? You can:\n\n• Change the **order** of modules\n• **Skip** certain topics\n• Add **more focus** on specific areas\n\nJust let me know! ✏️";
      } else {
        botResponse =
          "I have your study plan ready! Would you like to:\n✅ Start learning (type **yes**)\n✏️ Edit the plan (type **edit**)\n\nWhat would you prefer? 🤔";
      }
    } else if (progress.bot_state === "learning") {
      // Handle learning interactions with context
      const historyResult = await pool.query(
        `SELECT message_type, content FROM chat_messages WHERE bot_id = $1 AND user_id = $2 ORDER BY created_at DESC LIMIT 15`,
        [botId, userId]
      );

      const chatHistory = historyResult.rows.reverse();

      // Extract instructions text from database object or fallback
      const instructionsText =
        finalSystemInstructions?.instructions ||
        finalSystemInstructions?.raw ||
        "You are a warm, human study companion. Sound like a real person having a conversation. Be conversational, not scripted. Respond naturally to emotions and tone.";

      const systemPrompt = instructionsText;

      const groqMessages = [{ role: "system", content: systemPrompt }];

      for (const msg of chatHistory) {
        groqMessages.push({
          role: msg.message_type === "user" ? "user" : "assistant",
          content: msg.content,
        });
      }

      groqMessages.push({ role: "user", content: message });

      const groqRes = await axios.post(
        "https://api.groq.com/openai/v1/chat/completions",
        {
          model: "openai/gpt-oss-20b",
          messages: groqMessages,
          max_tokens: 1200,
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

      botResponse =
        groqRes?.data?.choices?.[0]?.message?.content ||
        "I encountered an issue. Please try again! 🤔";

      // Check if user completed module
      if (
        message.toLowerCase().includes("done") ||
        message.toLowerCase().includes("completed") ||
        message.toLowerCase().includes("next")
      ) {
        const completed = progress.completed_modules || [];
        completed.push(progress.current_module);

        const totalModules = updatedPlan?.modules?.length || 1;
        const progressPercent = Math.round(
          (completed.length / totalModules) * 100
        );

        await pool.query(
          `UPDATE bot_progress SET completed_modules = $1, current_module = $2, progress_percentage = $3 WHERE bot_id = $4 AND user_id = $5`,
          [
            JSON.stringify(completed),
            progress.current_module + 1,
            progressPercent,
            botId,
            userId,
          ]
        );

        const nextModule = updatedPlan?.modules?.[progress.current_module + 1];
        if (nextModule) {
          botResponse += `\n\n## ✅ Module Complete!

Module ${progress.current_module + 1} done! Great work! 🎉

**📊 Progress:** ${progressPercent}%

---

## ➡️ Next: ${nextModule.title}

${nextModule.description}`;
        } else {
          botResponse += `\n\n## 🎓 Course Complete!

Congratulations! You've finished all modules! 🏆

**📊 Final Progress:** 100%

You've successfully learned **${updatedPlan?.title || "this course"}**! 🎉`;
          newState = "completed";
        }
      }

      botResponse = formatChatGPTStyle(botResponse);
    }

    // Update state if changed
    if (newState !== progress.bot_state) {
      await pool.query(
        `UPDATE bot_progress SET bot_state = $1, study_plan = $2, last_updated = NOW() WHERE bot_id = $3 AND user_id = $4`,
        [
          newState,
          updatedPlan ? JSON.stringify(updatedPlan) : progress.study_plan,
          botId,
          userId,
        ]
      );
    }

    // Save bot response (skip for [START_SESSION] special message)
    if (message !== "[START_SESSION]") {
      await pool.query(
        `INSERT INTO chat_messages (bot_id, user_id, message_type, content) VALUES ($1, $2, $3, $4)`,
        [botId, userId, "bot", botResponse]
      );
      console.log("✅ Bot response saved to database");
    } else {
      console.log(
        "⏭️  Skipping database save for [START_SESSION] special message"
      );
    }

    console.log("✅ RESPONSE READY");
    console.log(
      `📤 Sending response with greeting: "${botResponse.substring(0, 80)}..."`
    );
    console.log("🔵 ===== END CHAT-ENHANCED REQUEST =====\n");

    return res.json({
      status: "success",
      response: botResponse,
      state: newState,
      progress: {
        percentage: progress.progress_percentage || 0,
        completed_modules: progress.completed_modules?.length || 0,
      },
      timestamp,
    });
  } catch (err) {
    console.error("❌ [chat-enhanced] ERROR:", err.message);
    console.error("📍 Stack:", err.stack);
    return res.status(500).json({
      error: "Chat processing failed",
      message: err.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Get bot study plan and progress
app.get("/api/bot-progress/:botId/:userId", async (req, res) => {
  try {
    const { botId, userId } = req.params;

    const result = await pool.query(
      `SELECT study_plan, learned_concepts, progress_percentage, bot_state 
       FROM bot_progress WHERE bot_id = $1 AND user_id = $2 LIMIT 1`,
      [botId, userId]
    );

    if (result.rows.length === 0) {
      return res.json({
        status: "success",
        study_plan: null,
        progress: 0,
        learned_concepts: [],
        bot_state: "intro",
      });
    }

    const progress = result.rows[0];
    return res.json({
      status: "success",
      study_plan: progress.study_plan,
      progress: progress.progress_percentage || 0,
      learned_concepts: progress.learned_concepts || [],
      bot_state: progress.bot_state,
    });
  } catch (err) {
    console.error("[bot-progress] Error:", err.message);
    return res.status(500).json({
      error: "Failed to fetch progress",
      message: err.message,
    });
  }
});

// Get chat history for a bot
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

// Get user's study bots
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
    console.error("[user-bots] Full error:", err);
    return res.status(500).json({
      error: "Failed to fetch bots",
      message: err.message,
    });
  }
});

// Update study plan endpoint - saves changes and notifies AI to adjust teaching strategy
app.post("/api/update-study-plan", async (req, res) => {
  const timestamp = new Date().toISOString();
  console.log("[POST /api/update-study-plan] Request started:", timestamp);

  try {
    const { botId, userId, updatedPlan } = req.body;

    // Validation
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

    // Update bot_progress table with new plan
    try {
      await pool.query(
        `UPDATE bot_progress SET study_plan = $1, last_updated = NOW() WHERE bot_id = $2 AND user_id = $3`,
        [JSON.stringify(updatedPlan), botId, userId]
      );
      console.log("[update-study-plan] Plan updated in database");
    } catch (dbErr) {
      console.error(
        "[update-study-plan] Database update failed:",
        dbErr.message
      );
      throw dbErr;
    }

    // Get bot information for AI context
    let bot = null;
    try {
      const botResult = await pool.query(
        `SELECT name, topic, grade_level, system_instructions FROM study_bots WHERE bot_id = $1`,
        [botId]
      );
      if (botResult.rows.length > 0) {
        bot = botResult.rows[0];
      }
    } catch (err) {
      console.warn(
        "[update-study-plan] Failed to fetch bot info:",
        err.message
      );
    }

    // Save a system message to chat history about the plan change
    try {
      const systemMessage = `📋 Study plan has been updated. New structure:\n\n${updatedPlan.modules
        .map((m, i) => `${i + 1}. ${m.title}`)
        .join("\n")}`;

      await pool.query(
        `INSERT INTO chat_messages (bot_id, user_id, message_type, content) VALUES ($1, $2, $3, $4)`,
        [botId, userId, "system", systemMessage]
      );
      console.log("[update-study-plan] System message saved");
    } catch (msgErr) {
      console.warn(
        "[update-study-plan] Failed to save system message:",
        msgErr.message
      );
    }

    // Prepare instruction for AI to adjust teaching strategy
    const adjustmentInstruction = `The student has updated their study plan. Here's the new structure:\n\n${JSON.stringify(
      updatedPlan,
      null,
      2
    )}\n\nPlease acknowledge this change and adjust your future lessons to align with this updated plan. Continue from where the student left off - their progress and chat history are preserved.`;

    console.log("[update-study-plan] AI adjustment instruction prepared");

    // Send to Groq API to generate adaptive response
    const groqApiKey = process.env.GROQ_API_KEY;
    if (!groqApiKey) {
      console.warn("[update-study-plan] GROQ_API_KEY not configured");
      // Still return success - plan was saved even if AI notification fails
      return res.json({
        status: "success",
        message: "Study plan updated successfully",
        plan_updated: true,
        ai_adapted: false,
        timestamp,
      });
    }

    try {
      const groqRes = await axios.post(
        "https://api.groq.com/openai/v1/chat/completions",
        {
          model: "openai/gpt-oss-20b",
          messages: [
            {
              role: "system",
              content:
                bot?.system_instructions?.instructions ||
                "You are a helpful study tutor. Acknowledge plan changes and adapt your teaching.",
            },
            {
              role: "user",
              content: adjustmentInstruction,
            },
          ],
          max_tokens: 500,
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

      const aiAcknowledgment =
        groqRes?.data?.choices?.[0]?.message?.content ||
        "Plan updated! I'll adjust my teaching strategy accordingly.";

      console.log("[update-study-plan] AI acknowledged plan change");

      // Save AI acknowledgment to chat history
      try {
        await pool.query(
          `INSERT INTO chat_messages (bot_id, user_id, message_type, content) VALUES ($1, $2, $3, $4)`,
          [botId, userId, "bot", aiAcknowledgment]
        );
        console.log("[update-study-plan] AI acknowledgment saved to chat");
      } catch (msgErr) {
        console.warn(
          "[update-study-plan] Failed to save AI acknowledgment:",
          msgErr.message
        );
      }

      return res.json({
        status: "success",
        message: "Study plan updated and AI strategy adjusted",
        plan_updated: true,
        ai_adapted: true,
        ai_response: aiAcknowledgment,
        timestamp,
      });
    } catch (groqErr) {
      console.warn("[update-study-plan] Groq API error:", groqErr.message);
      // Plan was already saved, so return success
      return res.json({
        status: "success",
        message: "Study plan updated (AI adaptation failed but plan saved)",
        plan_updated: true,
        ai_adapted: false,
        error_note: groqErr.message,
        timestamp,
      });
    }
  } catch (err) {
    console.error("[POST /api/update-study-plan] Fatal error:", {
      error: err.message,
      timestamp: new Date().toISOString(),
    });

    return res.status(500).json({
      error: "Failed to update study plan",
      message: err.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// ============= QUIZ GENERATION ENDPOINT =============
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

    // Validation
    if (!botId || !userId || !moduleName) {
      console.warn("[generate-quiz] Missing required parameters");
      return res.status(400).json({
        error: "Invalid request",
        message: "botId, userId, and moduleName are required",
        timestamp,
      });
    }

    console.log("[generate-quiz] Generating quiz for:", {
      botId,
      moduleName,
      questionType,
      mcqCount,
      textCount,
      useWebSearch,
    });

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
    try {
      const quizResult = await pool.query(
        `INSERT INTO quiz_data (bot_id, user_id, module_name, quiz_data, created_at) 
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (bot_id, user_id, module_name) DO UPDATE 
         SET quiz_data = $4, created_at = $5
         RETURNING id`,
        [botId, userId, moduleName, JSON.stringify(quizJson), timestamp]
      );
      const quizId = quizResult.rows[0]?.id || 0;
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
    console.error("[POST /api/generate-quiz] Error:", {
      error: err.message,
      timestamp: new Date().toISOString(),
    });

    return res.status(500).json({
      error: "Failed to generate quiz",
      message: err.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Deep explanation endpoint for quiz answers
app.post("/api/explain-answer", async (req, res) => {
  try {
    const {
      botId,
      userId,
      quizId,
      questionIndex,
      questionText,
      answerText,
      currentExplanation,
    } = req.body;

    const timestamp = new Date().toISOString();
    console.log("[POST /api/explain-answer] Explanation request:", {
      botId,
      userId,
      questionIndex,
      timestamp,
    });

    // Validate input
    if (
      !botId ||
      !userId ||
      quizId === undefined ||
      questionIndex === undefined
    ) {
      return res.status(400).json({
        error: "Missing required fields",
        required: [
          "botId",
          "userId",
          "quizId",
          "questionIndex",
          "currentExplanation",
        ],
      });
    }

    if (!process.env.groq) {
      console.error("[explain-answer] Groq API key not configured");
      return res.status(500).json({ error: "API not configured" });
    }

    // Get bot context for better explanations
    const botResult = await pool.query(
      `SELECT study_plan, teaching_style FROM bot_progress WHERE id = $1`,
      [botId]
    );
    const botContext = botResult.rows[0] || {};
    const gradeLevel = botContext.study_plan?.gradeLevel || "high school";
    const teachingStyle = botContext.teaching_style || "Socratic";

    // Generate simpler explanation using Groq
    const explanationPrompt = `You are a patient tutor helping a student understand a concept they struggled with.

Current explanation that didn't work:
"${currentExplanation}"

Question: ${questionText}
Answer: ${answerText}
Grade Level: ${gradeLevel}
Student's Teaching Style: ${teachingStyle}

The student said "I don't understand this." Please provide a MUCH SIMPLER explanation by:

1. Use very simple, everyday language (no jargon)
2. Include 2-3 concrete real-world analogies or examples
3. Break it down step-by-step if it's complex
4. Use the Socratic method - ask clarifying questions if helpful
5. End with: "Does this make more sense now? Would you like me to explain any part differently?"

Keep your explanation concise but thorough (3-4 sentences with examples).`;

    const response = await fetch(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${process.env.groq}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "mixtral-8x7b-32768",
          messages: [{ role: "user", content: explanationPrompt }],
          temperature: 0.7,
          max_tokens: 500,
        }),
      }
    );

    if (!response.ok) {
      console.error("[explain-answer] Groq API error:", response.status);
      return res.status(500).json({
        error: "Failed to generate explanation",
        status: response.status,
      });
    }

    const data = await response.json();
    const newExplanation =
      data.choices?.[0]?.message?.content ||
      "I apologize, I couldn't generate a better explanation right now.";

    // Update mastery tracking in database
    try {
      const masteryResult = await pool.query(
        `INSERT INTO quiz_mastery (bot_id, user_id, quiz_id, question_index, explanation_count, mastery_level)
         VALUES ($1, $2, $3, $4, 1, 'clarifying')
         ON CONFLICT (bot_id, user_id, quiz_id, question_index) DO UPDATE
         SET explanation_count = explanation_count + 1,
             mastery_level = 'clarifying',
             last_updated = CURRENT_TIMESTAMP
         RETURNING *`,
        [botId, userId, quizId, questionIndex]
      );

      console.log("[explain-answer] Mastery updated:", masteryResult.rows[0]);
    } catch (dbErr) {
      console.warn("[explain-answer] Failed to update mastery:", dbErr.message);
    }

    // Save explanation interaction to chat history
    try {
      const explanationMessage = `[Student needed clarification on Q${
        questionIndex + 1
      }]\nNew explanation: ${newExplanation}`;
      await pool.query(
        `INSERT INTO chat_messages (bot_id, user_id, message_type, content) VALUES ($1, $2, $3, $4)`,
        [botId, userId, "bot", explanationMessage]
      );
    } catch (msgErr) {
      console.warn(
        "[explain-answer] Failed to save explanation message:",
        msgErr.message
      );
    }

    return res.json({
      status: "success",
      explanation: newExplanation,
      timestamp,
    });
  } catch (err) {
    console.error("[POST /api/explain-answer] Error:", {
      error: err.message,
      timestamp: new Date().toISOString(),
    });

    return res.status(500).json({
      error: "Failed to generate explanation",
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
  process.env.tavily || process.env.tsvily || process.env.TAVILYKEY;
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

// ============ DIAGNOSTIC ENDPOINT - VIEW BOT DATA IN DATABASE ============
app.get("/api/debug/bot/:botId", async (req, res) => {
  try {
    const { botId } = req.params;

    if (!botId || !botId.trim()) {
      return res.status(400).json({ error: "botId is required" });
    }

    const result = await pool.query(
      `SELECT bot_id, user_id, name, description, topic, grade_level, system_instructions, state, created_at 
       FROM study_bots WHERE bot_id = $1`,
      [botId.trim()]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Bot not found" });
    }

    const bot = result.rows[0];
    
    // Format the response for easy viewing
    const response = {
      status: "success",
      debug_info: {
        botId: bot.bot_id,
        botName: bot.name,
        topic: bot.topic,
        gradeLevel: bot.grade_level,
        createdAt: bot.created_at,
        description: bot.description,
        currentState: bot.state,
      },
      systemInstructions: {
        bot_name: bot.system_instructions?.bot_name,
        topic: bot.system_instructions?.topic,
        grade_level: bot.system_instructions?.grade_level,
        generated_at: bot.system_instructions?.generated_at,
        is_natural_bot: bot.system_instructions?.is_natural_bot,
        instructions_length: bot.system_instructions?.instructions?.length || 0,
        instructions_preview: bot.system_instructions?.instructions?.substring(0, 300) || "N/A",
        full_instructions: bot.system_instructions?.instructions,
      },
    };

    console.log(`[GET /api/debug/bot/:botId] Data retrieved for ${botId}`);
    res.json(response);
  } catch (err) {
    console.error("[GET /api/debug/bot/:botId] Error:", err.message);
    res.status(500).json({
      error: "Server error",
      message: err.message,
    });
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
      { headers: { Authorization: `Bearer ${process.env.tavily}` } }
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
