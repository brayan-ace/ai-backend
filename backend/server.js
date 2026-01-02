require("dotenv").config();
const express = require("express");
const cors = require("cors");

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors()); // Enable CORS for all origins
app.use(express.json()); // Enable JSON body parsing

// Basic error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).send("Something broke!");
});

// REST endpoint: POST /chat
app.post("/chat", async (req, res) => {
  try {
    const { message } = req.body;

    if (!message) {
      return res.status(400).json({ error: "Message is required" });
    }

    // --- Securely call AI APIs here ---
    // Replace this with your actual AI API integration (e.g., Google Gemini, OpenAI, etc.)
    // Use process.env.AI_API_KEY for your API key
    console.log(`Received message: ${message}`);
    console.log(
      `Using AI_API_KEY: ${process.env.AI_API_KEY ? "******" : "NOT SET"}`
    ); // Mask for logs

    // Example AI API call (replace with actual implementation)
    const aiResponse = `AI response to: "${message}"`; // Placeholder response
    // In a real scenario, you would make an HTTP request to the AI API here
    // and process its response.

    res.json({ response: aiResponse });
  } catch (error) {
    console.error("Error processing chat request:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

app.listen(port, () => {
  console.log(`Backend server listening at http://localhost:${port}`);
});
