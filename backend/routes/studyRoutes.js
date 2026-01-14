const express = require("express");
const router = express.Router();
const StudyController = require("../controllers/studyController");

/**
 * Study Routes
 * Handles all study-related API endpoints
 */

// Get or initialize study state
router.get("/:userId/:botId/state", async (req, res) => {
  try {
    const { userId, botId } = req.params;
    const state = await StudyController.getOrInitializeStudyState(
      userId,
      botId
    );
    res.json({ success: true, state });
  } catch (err) {
    console.error("Failed to get study state:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

// Update study state
router.post("/:userId/:botId/state", async (req, res) => {
  try {
    const { userId, botId } = req.params;
    const updates = req.body;
    const updatedState = await StudyController.updateStudyState(
      userId,
      botId,
      updates
    );
    res.json({ success: true, state: updatedState });
  } catch (err) {
    console.error("Failed to update study state:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

// Generate study plan
router.post("/:userId/:botId/plan", async (req, res) => {
  try {
    const { userId, botId } = req.params;
    const { topic, gradeLevel, moduleCount } = req.body;

    const studyPlan = await StudyController.generateStudyPlan(
      topic,
      gradeLevel,
      moduleCount
    );

    // Update the study state with the new plan
    await StudyController.updateStudyState(userId, botId, {
      studyPlan,
      phase: "planning",
    });

    res.json({ success: true, studyPlan });
  } catch (err) {
    console.error("Failed to generate study plan:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

// Get current module
router.get("/:userId/:botId/current-module", async (req, res) => {
  try {
    const { userId, botId } = req.params;
    const module = await StudyController.getCurrentModule(userId, botId);
    res.json({ success: true, module });
  } catch (err) {
    console.error("Failed to get current module:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

// Complete current module
router.post("/:userId/:botId/complete-module", async (req, res) => {
  try {
    const { userId, botId } = req.params;
    const nextModule = await StudyController.completeModule(userId, botId);

    if (nextModule) {
      res.json({
        success: true,
        nextModule,
        message: "Module completed successfully. Advanced to next module.",
      });
    } else {
      res.json({
        success: true,
        message: "All modules completed! Well done!",
      });
    }
  } catch (err) {
    console.error("Failed to complete module:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

// Reset study progress
router.post("/:userId/:botId/reset", async (req, res) => {
  try {
    const { userId, botId } = req.params;
    const resetState = await StudyController.resetStudyProgress(userId, botId);
    res.json({
      success: true,
      state: resetState,
      message: "Study progress reset successfully",
    });
  } catch (err) {
    console.error("Failed to reset study progress:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
