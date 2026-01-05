require("dotenv").config();
const express = require("express");
const cors = require("cors");
const axios = require("axios");

const app = express();
app.use(cors());
app.use(express.json());

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

// Global error handler middleware - catches all async errors
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
          // Check if API key exists
          if (!process.env.GROQ_API_KEY) {
            console.error("[Chat] GROQ_API_KEY not configured");
            return res.status(500).json({
              error: "API configuration error",
              message: "GROQ_API_KEY not configured",
              provider: "groq",
              timestamp: new Date().toISOString(),
            });
          }

          // Create system prompt based on mode
          let systemPrompt;
          if (responseMode === "detailed") {
            systemPrompt =
              'You are a helpful AI assistant. Provide comprehensive, detailed explanations with context, examples, and thorough analysis. Write in clear, flowing paragraphs and use bullet points with dashes (-) for lists. Include relevant background information and multiple perspectives when appropriate. CRITICAL FORMATTING RULES: 1) NEVER use tables or tabular formats with | symbols. 2) NEVER use numbered lists (1., 2., 3.) or markdown headings with numbers (### 1.). 3) Use bullet points with dashes (-) or write in paragraphs only. 4) When explaining multiple points, introduce them naturally in text ("First, ", "Additionally, ", "Moreover, ") rather than numbered sections. Your responses should be rich in content and can be lengthy when needed to fully explain the topic.';
          } else {
            // quick/straight mode (default)
            systemPrompt =
              "You are a helpful AI assistant. Provide informative, well-rounded answers with good context. Structure your response in 2 solid paragraphs that cover the key points thoroughly. Each paragraph should be 3-5 sentences. Give enough detail to be genuinely helpful while staying focused and conversational. This is the default mode users expect - make it count.";
          }

          console.log(`[Chat] Using ${responseMode} mode with Groq API...`);
          const response = await fetch(
            "https://api.groq.com/openai/v1/chat/completions",
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${process.env.GROQ_API_KEY}`,
              },
              body: JSON.stringify({
                messages: [
                  { role: "system", content: systemPrompt },
                  { role: "user", content: userMessage },
                ],
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

          const result = await response.json();
          console.log("[Chat] Groq API success:", result);

          const rawText =
            result.choices?.[0]?.message?.content || "No response from API";
          const structured = structureTextResponse(rawText);

          // If client requested a summarize action, return the concise form
          if (data?.action === "summarize" && data?.mode === "concise") {
            return res.json({
              provider: "groq",
              reply: structured.concise,
              structured: structured,
              fullResponse: result,
              timestamp: new Date().toISOString(),
              status: "success",
            });
          }

          return res.json({
            provider: "groq",
            reply: rawText,
            structured: structured,
            fullResponse: result,
            timestamp: new Date().toISOString(),
            status: "success",
          });
        } catch (chatError) {
          console.error("[Chat] Exception caught:", {
            message: chatError.message,
            stack: chatError.stack,
            name: chatError.name,
          });
          return res.status(500).json({
            error: "Failed to process chat request",
            message: chatError.message,
            provider: "groq",
            errorType: chatError.name,
            timestamp: new Date().toISOString(),
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

          return res.json({
            provider: "tavily",
            results: resp.data,
            reply: resultsText,
            structured: structured,
            timestamp: new Date().toISOString(),
            status: "success",
          });
        } catch (searchError) {
          console.error(
            "[Search] Error:",
            searchError?.response?.data || searchError.message || searchError
          );
          return res.status(searchError?.response?.status || 500).json({
            error: "Search request failed",
            message: searchError?.response?.data || searchError.message,
            provider: "tavily",
            timestamp: new Date().toISOString(),
          });
        }

      case "image":
        console.log("[Image Case] Processing image request:", data);
        try {
          // Check for Gemini API key
          const GEMINI_KEY = process.env.geminiApi;
          if (!GEMINI_KEY) {
            console.error(
              "[Image] GEMINI API key not configured (env 'geminiapikey')"
            );
            return res.status(500).json({
              error: "API configuration error",
              message:
                "Gemini API key not configured. Set env var 'geminiapikey'.",
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
            `https://generativelanguage.googleapis.com/v1beta/models/gemini-pro-vision:generateContent?key=${GEMINI_KEY}`,
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

          return res.json({
            provider: "gemini",
            analysis: analysisText,
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
          return res.status(imageError?.response?.status || 500).json({
            error: "Image analysis failed",
            message:
              imageError?.response?.data?.error?.message || imageError.message,
            provider: "gemini",
            timestamp: new Date().toISOString(),
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
    return res.status(500).json({
      error: "Request processing failed",
      message: mainError.message,
      errorType: mainError.name,
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
