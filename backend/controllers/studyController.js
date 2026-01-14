const UserStudyState = require("../models/UserStudyState");

/**
 * Study Controller
 * Handles study-related operations and integrates with UserStudyState
 */
class StudyController {
  /**
   * Get or initialize the user's study state
   */
  static async getOrInitializeStudyState(userId, botId) {
    try {
      const state = await UserStudyState.initialize(userId, botId);
      return state;
    } catch (err) {
      console.error("Failed to get or initialize study state:", err.message);
      throw err;
    }
  }

  /**
   * Update the study state based on user interaction
   */
  static async updateStudyState(userId, botId, updates) {
    try {
      const studyState = new UserStudyState(userId, botId);

      // Apply updates
      if (updates.phase) {
        await studyState.updatePhase(updates.phase);
      }

      if (updates.studyPlan) {
        await studyState.updateStudyPlan(updates.studyPlan);
      }

      if (updates.currentModuleIndex !== undefined) {
        await studyState.updateCurrentModuleIndex(updates.currentModuleIndex);
      }

      if (updates.completedModuleIndex) {
        await studyState.markModuleCompleted(updates.completedModuleIndex);
      }

      if (updates.lastUserConfirmation !== undefined) {
        await studyState.updateLastUserConfirmation(
          updates.lastUserConfirmation
        );
      }

      if (updates.learningPreferences) {
        await studyState.updateLearningPreferences(updates.learningPreferences);
      }

      if (updates.responseMode) {
        await studyState.updateResponseMode(updates.responseMode);
      }

      if (updates.comprehensionFlags) {
        await studyState.updateComprehensionFlags(
          updates.moduleIndex,
          updates.comprehensionFlags
        );
      }

      // Return the updated state
      return await studyState.getCurrentState();
    } catch (err) {
      console.error("Failed to update study state:", err.message);
      throw err;
    }
  }

  /**
   * Generate a study plan based on the topic and grade level
   */
  static async generateStudyPlan(topic, gradeLevel, moduleCount = 5) {
    try {
      // This would typically call an AI service to generate a detailed study plan
      // For now, we'll create a basic structure
      const modules = [];

      for (let i = 0; i < moduleCount; i++) {
        modules.push({
          id: `module_${i + 1}`,
          title: `${topic} - Module ${i + 1}`,
          description: `Learn about ${topic} module ${i + 1}`,
          subtopics: [
            `Subtopic ${i + 1}.1`,
            `Subtopic ${i + 1}.2`,
            `Subtopic ${i + 1}.3`,
          ],
          estimatedEffort: "30 minutes",
          priority: i + 1,
        });
      }

      return {
        topic,
        gradeLevel,
        modules,
        createdAt: new Date().toISOString(),
      };
    } catch (err) {
      console.error("Failed to generate study plan:", err.message);
      throw err;
    }
  }

  /**
   * Get the current module being studied
   */
  static async getCurrentModule(userId, botId) {
    try {
      const studyState = new UserStudyState(userId, botId);
      const state = await studyState.getCurrentState();

      const studyPlan = JSON.parse(state.active_study_plan);
      const currentModuleIndex = state.current_module_index;

      if (studyPlan.modules && studyPlan.modules.length > currentModuleIndex) {
        return studyPlan.modules[currentModuleIndex];
      }

      return null;
    } catch (err) {
      console.error("Failed to get current module:", err.message);
      throw err;
    }
  }

  /**
   * Mark a module as completed and advance to the next one
   */
  static async completeModule(userId, botId) {
    try {
      const studyState = new UserStudyState(userId, botId);
      const state = await studyState.getCurrentState();

      const currentModuleIndex = state.current_module_index;

      // Mark current module as completed
      await studyState.markModuleCompleted(currentModuleIndex);

      // Advance to next module
      const studyPlan = JSON.parse(state.active_study_plan);
      const nextModuleIndex = currentModuleIndex + 1;

      if (studyPlan.modules && studyPlan.modules.length > nextModuleIndex) {
        await studyState.updateCurrentModuleIndex(nextModuleIndex);
        return studyPlan.modules[nextModuleIndex];
      } else {
        // All modules completed
        await studyState.updatePhase("completed");
        return null;
      }
    } catch (err) {
      console.error("Failed to complete module:", err.message);
      throw err;
    }
  }

  /**
   * Reset the study progress
   */
  static async resetStudyProgress(userId, botId) {
    try {
      const studyState = new UserStudyState(userId, botId);
      await studyState.reset();
      return await studyState.getCurrentState();
    } catch (err) {
      console.error("Failed to reset study progress:", err.message);
      throw err;
    }
  }
}

module.exports = StudyController;
