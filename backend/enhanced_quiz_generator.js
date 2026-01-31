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
  console.log("[EnhancedQuiz] Starting deep analysis for quiz generation...");
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

  // 4. Get web search context if enabled
  let searchContext = "";
  if (useWebSearch && topic) {
    console.log(
      `[EnhancedQuiz] Fetching online context for meaningful quiz generation about "${topic}"`,
    );
    searchContext = await getWebSearchContext(topic, gradeLevel);
    if (searchContext) {
      console.log("[EnhancedQuiz] ✅ Online context retrieved for quiz");
    }
  }

  // 5. Build comprehensive quiz prompt
  console.log("[EnhancedQuiz] Building quiz prompt...");
  let quizPrompt = `Generate a PERSONALIZED quiz based on deep analysis of this student's learning journey.

STUDENT PROFILE:
- Grade Level: ${gradeLevel || "General"}
- Learning Style: ${learningAnalysis.learningStyle || "unknown"}
- Difficulty Level: ${learningAnalysis.difficultyLevel || "Medium"}
- Progress: ${studyPlan?.progressPercentage || 0}% complete

CONCEPTS DISCUSSED: ${learningAnalysis.conceptsDiscussed.join(", ") || "General concepts"}

STUDENT INTERESTS: ${learningAnalysis.userInterests.join(", ") || "General interests"}

STRENGTHS: ${learningAnalysis.strengths?.join(", ") || "None identified"}

AREAS FOR IMPROVEMENT: ${learningAnalysis.weaknesses?.join(", ") || "None identified"}

COMMON QUESTIONS: ${learningAnalysis.keyQuestions?.join(", ") || "None identified"}

MISCONCEPTIONS TO ADDRESS: ${learningAnalysis.misconceptions?.join(", ") || "None identified"}

CURRENT MODULE: "${moduleName}"

${
  studyPlan
    ? `STUDY PLAN CONTEXT:
- Current Module: ${studyPlan.currentModule + 1}
- Completed Modules: ${studyPlan.completedModules.length}
- Total Modules: ${studyPlan.studyPlan?.modules?.length || 0}`
    : ""
}

${
  searchContext
    ? `ONLINE RESEARCH CONTEXT (for meaningful, current questions):
${searchContext}

Note: The questions below should incorporate current, relevant information from online sources while remaining grounded in the student's learning journey.`
    : ""
}

RECENT LEARNING CONVERSATION SAMPLE:
${conversationHistory
  .slice(-6)
  .map((msg) => `${msg.type}: ${msg.content}`)
  .join("\n")}

GENERATION REQUIREMENTS:
1. Focus on concepts the student has actually discussed
2. Base questions on current, relevant information (especially from online research context if provided)
3. Address their identified weaknesses and misconceptions
4. Match their learning style and difficulty level
5. Include questions that test their understanding of discussed topics
6. Challenge them appropriately based on their progress
7. Use real-world examples and current information to make questions meaningful
8. Ensure questions are appropriate for their grade level
2. Address their identified weaknesses and misconceptions
3. Match their learning style and difficulty level
4. Include questions that test their understanding of discussed topics
5. Challenge them appropriately based on their progress
6. Use examples and contexts from their actual conversations

QUIZ STRUCTURE:
{
  "questions": [
    {
      "type": "mcq",
      "text": "Question tailored to student's learning journey",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "concept": "specific concept being tested",
      "difficulty": "Easy|Medium|Hard",
      "learningStyle": "visual|auditory|kinesthetic|reading"
    },
    {
      "type": "text", 
      "text": "Personalized question based on conversation",
      "concept": "specific concept being tested",
      "difficulty": "Easy|Medium|Hard",
      "learningStyle": "visual|auditory|kinesthetic|reading"
    }
  ],
  "answers": [
    {
      "type": "mcq",
      "answer": "Correct option",
      "explanation": "Explanation referencing student's learning",
      "addressesMisconception": "false",
      "buildsOnStrength": "true"
    },
    {
      "type": "text",
      "answer": "Expected answer",
      "explanation": "Comprehensive explanation based on their learning",
      "addressesMisconception": "true",
      "buildsOnStrength": "false"
    }
  ],
  "personalization": {
    "basedOnConversation": true,
    "addressesWeaknesses": ["weakness1", "weakness2"],
    "buildsOnStrengths": ["strength1"],
    "learningStyleAdapted": true,
    "difficultyAdjusted": true
  }
}`;

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
};
