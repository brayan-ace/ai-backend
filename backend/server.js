require("dotenv").config();
const express = require("express");
const cors = require("cors");

const app = express();
app.use(cors());
app.use(express.json());

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

          console.log("[Chat] Calling Groq API...");
          const response = await fetch(
            "https://api.groq.com/openai/v1/chat/completions",
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${process.env.GROQ_API_KEY}`,
              },
              body: JSON.stringify({
                messages: [{ role: "user", content: userMessage }],
                model: "llama-3.3-70b-chat",
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

          return res.json({
            provider: "groq",
            reply:
              result.choices?.[0]?.message?.content || "No response from API",
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
          // This is a mock response - replace with real Tavily API call
          return res.json({
            provider: "tavily",
            results: ["Mock search result 1", "Mock search result 2"],
            message:
              "This is a mock response. Configure TAVILY_API_KEY to enable real searches.",
            timestamp: new Date().toISOString(),
            status: "success",
          });
        } catch (searchError) {
          console.error("[Search] Error:", searchError.message);
          return res.status(500).json({
            error: "Search request failed",
            message: searchError.message,
            provider: "tavily",
            timestamp: new Date().toISOString(),
          });
        }

      case "image":
        console.log("[Image Case] Processing image request:", data);
        try {
          // This is a mock response - replace with real Gemini API call
          return res.json({
            provider: "gemini",
            analysis: "Mock image analysis",
            message:
              "This is a mock response. Configure GEMINI_API_KEY to enable real analysis.",
            timestamp: new Date().toISOString(),
            status: "success",
          });
        } catch (imageError) {
          console.error("[Image] Error:", imageError.message);
          return res.status(500).json({
            error: "Image request failed",
            message: imageError.message,
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
