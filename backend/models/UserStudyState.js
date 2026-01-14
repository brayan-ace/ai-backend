const { pool } = require("../db");

/**
 * UserStudyState Model
 * Represents the persistent state of a user's study journey
 */
class UserStudyState {
  constructor(userId, botId) {
    this.userId = userId;
    this.botId = botId;
  }

  /**
   * Initialize or retrieve the user's study state
   */
  static async initialize(userId, botId) {
    try {
      // Check if state already exists
      const existingState = await pool.query(
        `SELECT * FROM user_study_state WHERE user_id = $1 AND bot_id = $2`,
        [userId, botId]
      );

      if (existingState.rows.length > 0) {
        return existingState.rows[0];
      }

      // Create new state if it doesn't exist
      const newState = await pool.query(
        `INSERT INTO user_study_state (
          user_id, 
          bot_id, 
          current_phase, 
          active_study_plan, 
          current_module_index, 
          completed_modules, 
          last_user_confirmation, 
          learning_preferences, 
          response_mode, 
          comprehension_flags
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        RETURNING *`,
        [
          userId,
          botId,
          "greeting", // Initial phase
          JSON.stringify({ modules: [] }), // Empty study plan
          0, // Start at first module
          JSON.stringify([]), // No completed modules
          null, // No confirmation yet
          JSON.stringify({}), // Empty learning preferences
          "normal", // Default response mode
          JSON.stringify({}), // Empty comprehension flags
        ]
      );

      return newState.rows[0];
    } catch (err) {
      console.error("Failed to initialize UserStudyState:", err.message);
      throw err;
    }
  }

  /**
   * Update the current phase of the study journey
   */
  async updatePhase(phase) {
    const validPhases = [
      "greeting",
      "planning",
      "studying",
      "quiz",
      "completed",
    ];
    if (!validPhases.includes(phase)) {
      throw new Error(`Invalid phase: ${phase}`);
    }

    await pool.query(
      `UPDATE user_study_state SET current_phase = $1 WHERE user_id = $2 AND bot_id = $3`,
      [phase, this.userId, this.botId]
    );
  }

  /**
   * Update the active study plan
   */
  async updateStudyPlan(plan) {
    if (!plan || typeof plan !== "object") {
      throw new Error("Invalid study plan structure");
    }

    await pool.query(
      `UPDATE user_study_state SET active_study_plan = $1 WHERE user_id = $2 AND bot_id = $3`,
      [JSON.stringify(plan), this.userId, this.botId]
    );
  }

  /**
   * Update the current module index
   */
  async updateCurrentModuleIndex(index) {
    if (typeof index !== "number" || index < 0) {
      throw new Error("Invalid module index");
    }

    await pool.query(
      `UPDATE user_study_state SET current_module_index = $1 WHERE user_id = $2 AND bot_id = $3`,
      [index, this.userId, this.botId]
    );
  }

  /**
   * Mark a module as completed
   */
  async markModuleCompleted(moduleIndex) {
    // Get current state
    const currentState = await pool.query(
      `SELECT completed_modules FROM user_study_state WHERE user_id = $1 AND bot_id = $2`,
      [this.userId, this.botId]
    );

    const completedModules = JSON.parse(
      currentState.rows[0].completed_modules || "[]"
    );

    if (!completedModules.includes(moduleIndex)) {
      completedModules.push(moduleIndex);

      await pool.query(
        `UPDATE user_study_state SET completed_modules = $1 WHERE user_id = $2 AND bot_id = $3`,
        [JSON.stringify(completedModules), this.userId, this.botId]
      );
    }
  }

  /**
   * Update the last user confirmation
   */
  async updateLastUserConfirmation(confirmation) {
    await pool.query(
      `UPDATE user_study_state SET last_user_confirmation = $1 WHERE user_id = $2 AND bot_id = $3`,
      [confirmation, this.userId, this.botId]
    );
  }

  /**
   * Update learning preferences
   */
  async updateLearningPreferences(preferences) {
    if (!preferences || typeof preferences !== "object") {
      throw new Error("Invalid learning preferences structure");
    }

    await pool.query(
      `UPDATE user_study_state SET learning_preferences = $1 WHERE user_id = $2 AND bot_id = $3`,
      [JSON.stringify(preferences), this.userId, this.botId]
    );
  }

  /**
   * Update response mode
   */
  async updateResponseMode(mode) {
    const validModes = ["normal", "detailed"];
    if (!validModes.includes(mode)) {
      throw new Error(`Invalid response mode: ${mode}`);
    }

    await pool.query(
      `UPDATE user_study_state SET response_mode = $1 WHERE user_id = $2 AND bot_id = $3`,
      [mode, this.userId, this.botId]
    );
  }

  /**
   * Update comprehension flags for a module
   */
  async updateComprehensionFlags(moduleIndex, flags) {
    if (!flags || typeof flags !== "object") {
      throw new Error("Invalid comprehension flags structure");
    }

    // Get current flags
    const currentState = await pool.query(
      `SELECT comprehension_flags FROM user_study_state WHERE user_id = $1 AND bot_id = $2`,
      [this.userId, this.botId]
    );

    const comprehensionFlags = JSON.parse(
      currentState.rows[0].comprehension_flags || "{}"
    );
    comprehensionFlags[moduleIndex] = flags;

    await pool.query(
      `UPDATE user_study_state SET comprehension_flags = $1 WHERE user_id = $2 AND bot_id = $3`,
      [JSON.stringify(comprehensionFlags), this.userId, this.botId]
    );
  }

  /**
   * Get the current state
   */
  async getCurrentState() {
    const result = await pool.query(
      `SELECT * FROM user_study_state WHERE user_id = $1 AND bot_id = $2`,
      [this.userId, this.botId]
    );

    if (result.rows.length === 0) {
      throw new Error("User study state not found");
    }

    return result.rows[0];
  }

  /**
   * Reset the study state (for testing or starting over)
   */
  async reset() {
    await pool.query(
      `UPDATE user_study_state SET 
        current_phase = 'greeting',
        active_study_plan = '{"modules": []}',
        current_module_index = 0,
        completed_modules = '[]',
        last_user_confirmation = NULL,
        comprehension_flags = '{}'
      WHERE user_id = $1 AND bot_id = $2`,
      [this.userId, this.botId]
    );
  }
}

module.exports = UserStudyState;
