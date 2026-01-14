const { pool } = require("../db");

class ConversationMemory {
  constructor(conversationId) {
    this.conversationId = conversationId;
    this.shortTermMemory = [];
    this.maxShortTermSize = 10; // Store last 10 interactions
  }

  // Add a new interaction to short-term memory
  async addInteraction(userMessage, aiResponse, intent, topicSignature) {
    const interaction = {
      user_message: userMessage,
      ai_response: aiResponse,
      detected_intent: intent,
      topic_signature: topicSignature,
      timestamp: new Date().toISOString(),
    };

    // Add to short-term memory
    this.shortTermMemory.push(interaction);

    // Trim to max size
    if (this.shortTermMemory.length > this.maxShortTermSize) {
      this.shortTermMemory = this.shortTermMemory.slice(-this.maxShortTermSize);
    }

    // Save to database
    try {
      await pool.query(
        `INSERT INTO conversation_memory (conversation_id, interaction_data) VALUES ($1, $2)
         ON CONFLICT (conversation_id) DO UPDATE SET interaction_data = $2`,
        [this.conversationId, JSON.stringify(this.shortTermMemory)]
      );
    } catch (err) {
      console.error("Failed to save conversation memory:", err.message);
    }
  }

  // Get relevant context for a new message
  async getRelevantContext(newMessage) {
    // Always load the last 10 interactions as reference for context awareness
    if (this.shortTermMemory.length > 0) {
      // Return all recent interactions for comprehensive context
      return this.shortTermMemory;
    }

    return null;
  }

  // Get a summary of recent context for prompt injection
  getContextSummary() {
    if (this.shortTermMemory.length === 0) {
      return null;
    }

    // Create a summary of the last 10 interactions
    const summary = this.shortTermMemory
      .map((interaction, index) => {
        return `Interaction ${index + 1}: User: "${
          interaction.user_message
        }" | AI: "${interaction.ai_response}"`;
      })
      .join("\n");

    return summary;
  }

  // Load conversation memory from database
  async loadFromDatabase() {
    try {
      const result = await pool.query(
        `SELECT interaction_data FROM conversation_memory WHERE conversation_id = $1`,
        [this.conversationId]
      );

      if (result.rows.length > 0) {
        this.shortTermMemory = JSON.parse(result.rows[0].interaction_data);
      }
    } catch (err) {
      console.error("Failed to load conversation memory:", err.message);
    }
  }

  // Clear conversation memory
  async clearMemory() {
    this.shortTermMemory = [];
    try {
      await pool.query(
        `DELETE FROM conversation_memory WHERE conversation_id = $1`,
        [this.conversationId]
      );
    } catch (err) {
      console.error("Failed to clear conversation memory:", err.message);
    }
  }
}

module.exports = ConversationMemory;
