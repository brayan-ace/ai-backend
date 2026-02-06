/**
 * ENHANCED QUIZ GENERATOR - DEEP LEARNING ANALYSIS
 * Analyzes user's complete learning journey to generate personalized quizzes
 */

const axios = require("axios");
const { pool } = require("./db");

/**
 * Fetch user's complete conversation history with the study bot
 * This provides deep context about what the user has learned
 */
async function getUserConversationHistory(botId, userId) {
  try {
    const result = await pool.query(
      `SELECT message_type, content, created_at 
       FROM chat_messages 
       WHERE bot_id = $1 AND user_id = $2 
       ORDER BY created_at ASC`,
      [botId, userId],
    );

    return result.rows.map((msg) => ({
      type: msg.message_type,
      content: msg.content,
      timestamp: msg.created_at,
    }));
  } catch (error) {
    console.warn(
      "[EnhancedQuiz] Warning: Could not fetch conversation history from database:",
      error.code,
    );
    // Return empty array - quiz generation will proceed without learning context
    return [];
  }
}

/**
 * Analyze conversation to extract key learning concepts
 * Uses AI to identify what the user has discussed and learned
 */
async function analyzeLearningConcepts(conversationHistory, gradeLevel) {
  if (conversationHistory.length === 0) {
    return {
      conceptsDiscussed: [],
      userInterests: [],
      difficultyLevel: gradeLevel || "Medium",
      learningStyle: "unknown",
      strengths: [],
      weaknesses: [],
      keyQuestions: [],
      misconceptions: [],
    };
  }

  try {
    const groqApiKey = process.env.GROQ_API_KEY;
    if (!groqApiKey) {
      console.warn(
        "[EnhancedQuiz] GROQ_API_KEY not available for concept analysis",
      );
      return {
        conceptsDiscussed: [],
        userInterests: [],
        difficultyLevel: gradeLevel || "Medium",
        learningStyle: "unknown",
        strengths: [],
        weaknesses: [],
        keyQuestions: [],
        misconceptions: [],
      };
    }

    // Build conversation text for analysis
    const conversationText = conversationHistory
      .slice(-20) // Last 20 messages for context
      .map((msg) => `${msg.type.toUpperCase()}: ${msg.content}`)
      .join("\n");

    const analysisPrompt = `You are an educational analyst. Analyze this student's conversation with their AI tutor and extract key learning insights.

GRADE LEVEL: ${gradeLevel || "General"}

CONVERSATION HISTORY:
${conversationText}

Analyze and provide JSON response with:
{
  "conceptsDiscussed": ["concept1", "concept2", "concept3"],
  "userInterests": ["topic1", "topic2"], 
  "difficultyLevel": "Beginner|Intermediate|Advanced",
  "learningStyle": "visual|auditory|kinesthetic|reading|mixed",
  "strengths": ["strength1", "strength2"],
  "weaknesses": ["weakness1"],
  "keyQuestions": ["question1", "question2"],
  "misconceptions": ["misconception1", "misconception2"]
}

Focus on:
1. What specific topics/concepts were discussed
2. What the user seemed interested in or struggled with
3. The appropriate difficulty level based on their responses
4. Any patterns in their learning style
5. Questions they asked repeatedly
6. Misconceptions that need addressing

Return ONLY valid JSON, no explanations.`;

    const response = await axios.post(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        model: "openai/gpt-oss-20b",
        messages: [
          {
            role: "system",
            content:
              "You are an expert educational analyst. Analyze conversations to extract learning insights. Return only valid JSON.",
          },
          { role: "user", content: analysisPrompt },
        ],
        max_tokens: 1000,
        temperature: 0.3,
      },
      {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${groqApiKey}`,
        },
        timeout: 20000,
      },
    );

    const analysisText = response.data?.choices?.[0]?.message?.content || "{}";
    const analysis = JSON.parse(
      analysisText.replace(/```json\n?|```/g, "").trim(),
    );

    console.log("[EnhancedQuiz] Learning analysis completed:", {
      conceptsFound: analysis.conceptsDiscussed?.length || 0,
      difficultyLevel: analysis.difficultyLevel,
      learningStyle: analysis.learningStyle,
    });

    return analysis;
  } catch (error) {
    console.error(
      "[EnhancedQuiz] Error analyzing learning concepts:",
      error.message || error,
    );
    if (error.response?.data) {
      console.error(
        "[EnhancedQuiz] Groq API response error:",
        error.response.data,
      );
    }
    return {
      conceptsDiscussed: [],
      userInterests: [],
      difficultyLevel: gradeLevel || "Medium",
      learningStyle: "unknown",
      strengths: [],
      weaknesses: [],
      keyQuestions: [],
      misconceptions: [],
    };
  }
}

/**
 * Get user's study plan and progress
 * Provides context about what they're supposed to learn
 */
/**
 * Get user's study goals and learning objectives
 * Ensures quiz questions align with what the user wants to learn
 */
async function getUserStudyGoalsAndObjectives(botId, userId) {
  try {
    // First, try to get from bot_progress table (may have enhanced data)
    const progressResult = await pool.query(
      `SELECT 
        study_plan, 
        current_module, 
        completed_modules,
        b.description as study_goal_description
       FROM bot_progress bp
       LEFT JOIN bots b ON bp.bot_id = b.id
       WHERE bp.bot_id = $1 AND bp.user_id = $2`,
      [botId, userId],
    );

    if (progressResult.rows.length > 0) {
      const row = progressResult.rows[0];
      const studyPlan = row.study_plan || {};
      const modules = studyPlan.modules || [];

      // Extract objectives from completed modules
      const completedModuleIndices = row.completed_modules || [];
      const completedObjectives = modules
        .filter((m, idx) => completedModuleIndices.includes(idx))
        .flatMap((m) => m.objectives || [])
        .slice(0, 10); // Limit to 10 for clarity

      // Get current module objectives
      const currentModuleIdx = row.current_module || 0;
      const currentModule = modules[currentModuleIdx] || {};
      const currentObjectives = currentModule.objectives || [];

      return {
        overallGoal: row.study_goal_description || "General learning",
        modules: modules.length,
        completedCount: completedModuleIndices.length,
        completedModuleNames: modules
          .filter((m, idx) => completedModuleIndices.includes(idx))
          .map((m) => m.title)
          .slice(0, 5),
        currentModuleName: currentModule.title,
        currentModuleObjectives: currentObjectives.slice(0, 5),
        completedObjectives: completedObjectives,
        allModuleObjectives: modules
          .flatMap((m) => ({ module: m.title, objectives: m.objectives || [] }))
          .slice(0, 8),
      };
    }

    return {
      overallGoal: "General learning",
      modules: 0,
      completedCount: 0,
      completedModuleNames: [],
      currentModuleName: "Unknown",
      currentModuleObjectives: [],
      completedObjectives: [],
      allModuleObjectives: [],
    };
  } catch (error) {
    console.warn(
      "[EnhancedQuiz] Warning: Could not fetch study goals:",
      error.code,
    );
    return {
      overallGoal: "General learning",
      modules: 0,
      completedCount: 0,
      completedModuleNames: [],
      currentModuleName: "Unknown",
      currentModuleObjectives: [],
      completedObjectives: [],
      allModuleObjectives: [],
    };
  }
}

async function getUserStudyPlan(botId, userId) {
  try {
    const result = await pool.query(
      `SELECT study_plan, current_module, completed_modules, progress_percentage 
       FROM bot_progress 
       WHERE bot_id = $1 AND user_id = $2`,
      [botId, userId],
    );

    if (result.rows.length > 0) {
      const row = result.rows[0];
      return {
        studyPlan: row.study_plan,
        currentModule: row.current_module,
        completedModules: row.completed_modules || [],
        progressPercentage: row.progress_percentage || 0,
      };
    }
    return null;
  } catch (error) {
    console.warn(
      "[EnhancedQuiz] Warning: Could not fetch study plan from database:",
      error.code,
    );
    // Return null - quiz generation will proceed without study plan context
    return null;
  }
}

/**
 * Fetch relevant context from web search to enhance quiz generation
 * Ensures questions are based on current, meaningful information
 */
async function getWebSearchContext(topic, gradeLevel) {
  try {
    console.log(
      `[EnhancedQuiz] Searching web for: "${topic}" at ${gradeLevel} level`,
    );

    const searchQuery = `${topic} ${gradeLevel} education key concepts`;

    // Use Groq's web search capability through their API
    const groqApiKey = process.env.GROQ_API_KEY;
    if (!groqApiKey) {
      console.warn("[EnhancedQuiz] Cannot perform web search - no API key");
      return "";
    }

    // Build search context prompt
    const searchPrompt = `Search for and summarize key facts and concepts about "${topic}" at the ${gradeLevel} education level.
    
Focus on:
1. Core concepts and definitions
2. Real-world applications
3. Common misconceptions
4. Key facts that would make good quiz questions
5. Recent developments or examples

Provide a brief summary (2-3 sentences) of the most important information that would help create meaningful quiz questions.`;

    const response = await axios.post(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        model: "openai/gpt-oss-20b",
        messages: [
          {
            role: "system",
            content:
              "You are a research assistant. Provide factual, educational information suitable for quiz generation. Be concise but thorough.",
          },
          {
            role: "user",
            content: searchPrompt,
          },
        ],
        max_tokens: 500,
        temperature: 0.5,
      },
      {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${groqApiKey}`,
        },
        timeout: 15000,
      },
    );

    const searchContext = response.data?.choices?.[0]?.message?.content || "";
    console.log(
      "[EnhancedQuiz] Web search context retrieved:",
      !!searchContext,
    );

    return searchContext;
  } catch (error) {
    console.warn(
      "[EnhancedQuiz] Web search failed (non-critical):",
      error.message || error,
    );
    return ""; // Return empty string - quiz generation will proceed without web context
  }
}

/**
 * Generate enhanced quiz prompt based on deep learning analysis
 * NOW INCLUDES: Study goals alignment, what's been studied, module objectives
 */
async function generateEnhancedQuizPrompt({
  botId,
  userId,
  moduleName,
  gradeLevel,
  questionType,
  mcqCount,
  textCount,
  useWebSearch,
  topic,
}) {
  console.log("[EnhancedQuiz] Starting GOAL-ALIGNED quiz generation...");
  console.log("[EnhancedQuiz] Input params:", {
    botId,
    userId,
    moduleName,
    gradeLevel,
    questionType,
    mcqCount,
    textCount,
    useWebSearch,
    topic,
  });

  // 1. Get conversation history
  console.log("[EnhancedQuiz] Fetching conversation history...");
  const conversationHistory = await getUserConversationHistory(botId, userId);
  console.log(
    `[EnhancedQuiz] Found ${conversationHistory.length} conversation messages`,
  );

  // 2. Analyze learning concepts
  console.log("[EnhancedQuiz] Analyzing learning concepts...");
  const learningAnalysis = await analyzeLearningConcepts(
    conversationHistory,
    gradeLevel,
  );
  console.log("[EnhancedQuiz] Learning analysis completed:", {
    concepts: learningAnalysis.conceptsDiscussed?.length || 0,
    interests: learningAnalysis.userInterests?.length || 0,
  });

  // 3. Get study plan context
  console.log("[EnhancedQuiz] Fetching study plan...");
  const studyPlan = await getUserStudyPlan(botId, userId);
  console.log("[EnhancedQuiz] Study plan context retrieved:", !!studyPlan);

  // 4. 🎯 NEW: Get study goals and learning objectives
  console.log("[EnhancedQuiz] Fetching user's study GOALS and objectives...");
  const studyGoals = await getUserStudyGoalsAndObjectives(botId, userId);
  console.log("[EnhancedQuiz] Study goals retrieved:", {
    goal: studyGoals.overallGoal?.substring(0, 50),
    completedModules: studyGoals.completedCount,
    currentObjectives: studyGoals.currentModuleObjectives?.length || 0,
  });

  // 5. Get web search context if enabled
  let searchContext = "";
  if (useWebSearch && topic) {
    console.log(
      `[EnhancedQuiz] Fetching online context for goal-aligned quiz about "${topic}"`,
    );
    searchContext = await getWebSearchContext(topic, gradeLevel);
    if (searchContext) {
      console.log("[EnhancedQuiz] ✅ Online context retrieved for quiz");
    }
  }

  // 6. 🎯 Build GOAL-ALIGNED comprehensive quiz prompt
  console.log("[EnhancedQuiz] Building GOAL-ALIGNED quiz prompt...");
  let quizPrompt = `Generate a WORLD-CLASS, PERSONALIZED quiz that ALIGNS WITH the student's stated learning goals and current progress.

═══════════════════════════════════════════════════════════════

🎯 STUDENT'S LEARNING GOALS & OBJECTIVES:
─────────────────────────────────────────
Overall Goal: "${studyGoals.overallGoal}"

Study Progress:
- Completed: ${studyGoals.completedCount} of ${studyGoals.modules} modules
- Currently On: "${studyGoals.currentModuleName}"

${
  studyGoals.completedModuleNames.length > 0
    ? `Modules Already Covered: ${studyGoals.completedModuleNames.join(", ")}`
    : "No modules completed yet"
}

Current Module Objectives (What student should master):
${
  studyGoals.currentModuleObjectives.length > 0
    ? studyGoals.currentModuleObjectives
        .map((obj, i) => `${i + 1}. ${obj}`)
        .join("\n")
    : "- General understanding of the topic"
}

═══════════════════════════════════════════════════════════════

STUDENT PROFILE:
- Grade Level: ${gradeLevel || "General"} ⚠️ **CRITICAL: ALL questions MUST be appropriate for this grade level**
- Learning Style: ${learningAnalysis.learningStyle || "unknown"}
- Difficulty Level: ${learningAnalysis.difficultyLevel || "Medium"}
- Overall Progress: ${studyPlan?.progressPercentage || 0}% complete

WHAT STUDENT HAS LEARNED:
- Concepts Discussed: ${learningAnalysis.conceptsDiscussed.join(", ") || "General concepts"}
- Student Interests: ${learningAnalysis.userInterests.join(", ") || "General interests"}
- Identified Strengths: ${learningAnalysis.strengths?.join(", ") || "None identified"}
- Areas Needing Practice: ${learningAnalysis.weaknesses?.join(", ") || "None identified"}
- Key Questions Asked: ${learningAnalysis.keyQuestions?.join(", ") || "None identified"}
- Misconceptions to Address: ${learningAnalysis.misconceptions?.join(", ") || "None identified"}

⚠️ **CRITICAL REQUIREMENTS:**
1. **GOAL ALIGNMENT:** Ensure questions directly test the module objectives listed above
2. **GRADE-APPROPRIATE:** ALL content must be suitable for ${gradeLevel || "General"} students
3. **PROGRESS-AWARE:** Only test topics from completed + current module (NO untaught concepts)
4. **LEARNING STYLE MATCH:** Match format to student's ${learningAnalysis.learningStyle} learning style
5. **WEAKNESS FOCUS:** Include questions targeting identified areas for improvement
6. **NO REPETITION:** Don't repeat questions about already-mastered concepts

${
  studyPlan
    ? `STUDY PROGRESSION CONTEXT:
- Current Module (${studyPlan.currentModule + 1}/${studyPlan.studyPlan?.modules?.length || "?"}): "${moduleName}"
- Modules Completed: ${studyPlan.completedModules.length}
- Total Modules in Plan: ${studyPlan.studyPlan?.modules?.length || 0}`
    : ""
}

${
  searchContext
    ? `CURRENT RESEARCH CONTEXT (for meaningful, up-to-date questions):
${searchContext}

Note: Integrate current information while staying grounded in student's learning journey.`
    : ""
}

RECENT LEARNING CONVERSATION:
${conversationHistory
  .slice(-6)
  .map((msg) => `${msg.type}: ${msg.content}`)
  .join("\n")}
═══════════════════════════════════════════════════════════════

GENERATION REQUIREMENTS (IN ORDER OF IMPORTANCE):
1. Goal-Aligned: Questions MUST test the learning objectives stated above
2. Grade-Appropriate: Ensure all language and concepts match ${gradeLevel} level
3. Concept-Focused: Only test concepts from completed + current module
4. Weakness-Addressing: Deliberately include questions on identified weak areas
5. Learning-Style-Matched: Vary question types to suit ${learningAnalysis.learningStyle} learner
6. Difficulty-Balanced: Mix recall, comprehension, and application questions
7. Real-World-Relevant: Use current research and practical examples
8. Teaching-Focused: Provide explanations that teach, not just correct answers
9. Progress-Respecting: Acknowledge what they've already learned
10. Clear-Progression: Build from easier to harder questions

QUIZ STRUCTURE (STRICT FORMAT):
{
  "questions": [
    {
      "type": "mcq",
      "text": "Clear, specific question tailored to student's learning journey (${gradeLevel} appropriate)",
      "options": ["Option A (plausible distractor)", "Option B (correct answer)", "Option C (common misconception)", "Option D (plausible distractor)"],
      "concept": "specific concept being tested from discussions",
      "difficulty": "Easy|Medium|Hard",
      "learningStyle": "visual|auditory|kinesthetic|reading",
      "rationale": "Why this question is important for this student"
    },
    {
      "type": "text",
      "text": "Open-ended question requiring explanation or application",
      "concept": "specific concept being tested from discussions",
      "difficulty": "Easy|Medium|Hard",
      "learningStyle": "visual|auditory|kinesthetic|reading",
      "rationale": "Why this question is important for this student"
    }
  ],
  "answers": [
    {
      "type": "mcq",
      "answer": "Option B",
      "explanation": "Educational explanation that teaches and connects to student's journey",
      "addressesMisconception": true,
      "buildsOnStrength": true,
      "keyTakeaway": "One sentence summary"
    },
    {
      "type": "text",
      "answer": "Model answer demonstrating full understanding",
      "explanation": "Teaching-focused explanation connecting to student's learning",
      "addressesMisconception": true,
      "buildsOnStrength": true,
      "keyTakeaway": "One sentence summary"
    }
  ]
}

CRITICAL REMINDER:
- ALL questions must align with module objectives stated above
- ONLY include topics from completed modules or current module
- NO questions on modules the student hasn't started yet
- Match difficulty to student's current level
- Reference student's learning conversation where possible
- Address identified misconceptions and weak areas

Return VALID JSON ONLY - no markdown, no code blocks, no explanations.`;

  if (questionType === "mcq") {
    quizPrompt += `\n\nGenerate ONLY ${mcqCount} multiple choice questions focused on the student's discussed concepts.`;
  } else if (questionType === "text") {
    quizPrompt += `\n\nGenerate ONLY ${textCount} text questions that explore their understanding of discussed topics.`;
  } else if (questionType === "both") {
    quizPrompt += `\n\nGenerate ${mcqCount} MCQ questions AND ${textCount} text questions.`;
  }

  quizPrompt += `\n\nCRITICAL: Make this quiz feel PERSONAL to the student. Reference their actual learning journey where appropriate.`;

  return quizPrompt;
}

module.exports = {
  generateEnhancedQuizPrompt,
  getUserConversationHistory,
  analyzeLearningConcepts,
  getUserStudyPlan,
  getUserStudyGoalsAndObjectives,
};
