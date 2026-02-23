/**
 * SPACED REPETITION BACKEND UTILITIES
 *
 * Server-side implementation of SM-2 algorithm for spaced repetition.
 * This complements the frontend Dart implementation.
 *
 * Database table required:
 * CREATE TABLE concept_review_schedule (
 *   id SERIAL PRIMARY KEY,
 *   bot_id UUID NOT NULL,
 *   user_id UUID NOT NULL,
 *   module_index INT,
 *   concept_index INT,
 *   last_review_date TIMESTAMP,
 *   next_review_date TIMESTAMP,
 *   review_count INT DEFAULT 0,
 *   easiness_factor DECIMAL(3,2) DEFAULT 2.5,
 *   interval_days INT DEFAULT 1,
 *   created_at TIMESTAMP DEFAULT NOW(),
 *   FOREIGN KEY (bot_id) REFERENCES study_bots(id),
 *   FOREIGN KEY (user_id) REFERENCES users(id),
 *   UNIQUE(bot_id, user_id, module_index, concept_index)
 * );
 */

const MINIMUM_EASINESS_FACTOR = 1.3;
const MAXIMUM_EASINESS_FACTOR = 2.8;

/**
 * Calculate next review date and easiness factor using SM-2 algorithm
 * @param {Object} options
 * @param {number} options.quality - Quality of review (0-5)
 * @param {number} options.easinessFactor - Current easiness factor
 * @param {number} options.previousInterval - Previous interval in days
 * @param {Date} options.lastReviewDate - Date of last review
 * @returns {Object} {nextReviewDate, newEasiness, newInterval}
 */
function calculateNextReview({
  quality = 3,
  easinessFactor = 2.5,
  previousInterval = 1,
  lastReviewDate = new Date(),
}) {
  // Validate quality (0-5)
  if (quality < 0 || quality > 5) {
    throw new Error("Quality must be between 0 and 5");
  }

  let newEasiness = easinessFactor;
  let newInterval = previousInterval;

  if (quality < 3) {
    // Quality 0-2: Review failed, reset to 1 day
    newInterval = 1;
    newEasiness = Math.max(
      MINIMUM_EASINESS_FACTOR,
      easinessFactor + (0.1 - (5 - quality) * 0.08),
    );
  } else {
    // Quality 3-5: Review passed, increase interval
    if (previousInterval === 0 || previousInterval === 1) {
      // First or second review
      newInterval = 3;
    } else {
      // Subsequent reviews: multiply by easiness factor
      newInterval = Math.round(previousInterval * easinessFactor);
    }

    // Update easiness factor
    newEasiness = easinessFactor + 0.1 - (5 - quality) * 0.08;
  }

  // Clamp easiness factor
  newEasiness = Math.max(
    MINIMUM_EASINESS_FACTOR,
    Math.min(MAXIMUM_EASINESS_FACTOR, newEasiness),
  );

  // Calculate next review date
  const nextReviewDate = new Date(lastReviewDate);
  nextReviewDate.setDate(nextReviewDate.getDate() + newInterval);

  return {
    nextReviewDate,
    newEasiness: parseFloat(newEasiness.toFixed(2)),
    newInterval,
    quality,
  };
}

/**
 * Get all concepts that are due for review for a user
 * @param {Object} pool - Database connection pool
 * @param {string} botId - Study bot ID
 * @param {string} userId - User ID
 * @returns {Array} Array of due review records
 */
async function getConceptsDueForReview(pool, botId, userId) {
  const query = `
    SELECT 
      module_index,
      concept_index,
      next_review_date,
      easiness_factor,
      interval_days,
      review_count,
      CASE 
        WHEN next_review_date <= NOW() THEN true
        ELSE false
      END as is_overdue,
      CASE 
        WHEN DATE(next_review_date) = CURRENT_DATE THEN true
        ELSE false
      END as is_today
    FROM concept_review_schedule
    WHERE bot_id = $1 
      AND user_id = $2
      AND next_review_date <= NOW() + INTERVAL '1 day'
    ORDER BY next_review_date ASC
  `;

  try {
    const result = await pool.query(query, [botId, userId]);
    return result.rows;
  } catch (error) {
    console.error("Error fetching concepts due for review:", error);
    throw error;
  }
}

/**
 * Get overdue concepts (for catch-up reminders)
 * @param {Object} pool - Database connection pool
 * @param {string} botId - Study bot ID
 * @param {string} userId - User ID
 * @returns {Array} Array of overdue review records
 */
async function getOverdueReviews(pool, botId, userId) {
  const query = `
    SELECT 
      module_index,
      concept_index,
      next_review_date,
      EXTRACT(DAY FROM NOW() - next_review_date) as days_overdue
    FROM concept_review_schedule
    WHERE bot_id = $1 
      AND user_id = $2
      AND next_review_date < NOW()
    ORDER BY next_review_date ASC
  `;

  try {
    const result = await pool.query(query, [botId, userId]);
    return result.rows;
  } catch (error) {
    console.error("Error fetching overdue reviews:", error);
    throw error;
  }
}

/**
 * Log a review completion and calculate next review
 * @param {Object} pool - Database connection pool
 * @param {string} botId - Study bot ID
 * @param {string} userId - User ID
 * @param {number} moduleIndex - Module index
 * @param {number} conceptIndex - Concept index
 * @param {number} quality - Quality rating (0-5)
 * @returns {Object} Updated review record
 */
async function logReviewCompletion(
  pool,
  botId,
  userId,
  moduleIndex,
  conceptIndex,
  quality,
) {
  // Get current review record
  const getQuery = `
    SELECT 
      easiness_factor,
      interval_days,
      review_count,
      last_review_date
    FROM concept_review_schedule
    WHERE bot_id = $1 
      AND user_id = $2
      AND module_index = $3
      AND concept_index = $4
  `;

  try {
    const result = await pool.query(getQuery, [
      botId,
      userId,
      moduleIndex,
      conceptIndex,
    ]);

    if (result.rows.length === 0) {
      throw new Error("Review record not found");
    }

    const record = result.rows[0];
    const lastReviewDate = record.last_review_date || new Date();

    // Calculate next review using SM-2
    const nextReview = calculateNextReview({
      quality,
      easinessFactor: parseFloat(record.easiness_factor),
      previousInterval: record.interval_days,
      lastReviewDate,
    });

    // Update record
    const updateQuery = `
      UPDATE concept_review_schedule
      SET 
        last_review_date = NOW(),
        next_review_date = $1,
        easiness_factor = $2,
        interval_days = $3,
        review_count = review_count + 1
      WHERE bot_id = $4 
        AND user_id = $5
        AND module_index = $6
        AND concept_index = $7
      RETURNING *
    `;

    const updateResult = await pool.query(updateQuery, [
      nextReview.nextReviewDate,
      nextReview.newEasiness,
      nextReview.newInterval,
      botId,
      userId,
      moduleIndex,
      conceptIndex,
    ]);

    return updateResult.rows[0];
  } catch (error) {
    console.error("Error logging review completion:", error);
    throw error;
  }
}

/**
 * Initialize a new concept in the review schedule
 * @param {Object} pool - Database connection pool
 * @param {string} botId - Study bot ID
 * @param {string} userId - User ID
 * @param {number} moduleIndex - Module index
 * @param {number} conceptIndex - Concept index
 * @returns {Object} Created review record
 */
async function initializeConceptReview(
  pool,
  botId,
  userId,
  moduleIndex,
  conceptIndex,
) {
  const query = `
    INSERT INTO concept_review_schedule (
      bot_id,
      user_id,
      module_index,
      concept_index,
      next_review_date,
      last_review_date,
      easiness_factor,
      interval_days,
      review_count
    ) VALUES ($1, $2, $3, $4, NOW(), NOW(), 2.5, 1, 0)
    ON CONFLICT (bot_id, user_id, module_index, concept_index) 
    DO UPDATE SET
      next_review_date = EXCLUDED.next_review_date,
      last_review_date = EXCLUDED.last_review_date
    RETURNING *
  `;

  try {
    const result = await pool.query(query, [
      botId,
      userId,
      moduleIndex,
      conceptIndex,
    ]);
    return result.rows[0];
  } catch (error) {
    console.error("Error initializing concept review:", error);
    throw error;
  }
}

/**
 * Get spaced repetition statistics for a user
 * @param {Object} pool - Database connection pool
 * @param {string} botId - Study bot ID
 * @param {string} userId - User ID
 * @returns {Object} Statistics object
 */
async function getSpacedRepetitionStats(pool, botId, userId) {
  const query = `
    SELECT 
      COUNT(*) as total_concepts,
      SUM(CASE WHEN review_count >= 5 THEN 1 ELSE 0 END) as concepts_mastered,
      SUM(CASE WHEN next_review_date < NOW() THEN 1 ELSE 0 END) as overdue_concepts,
      SUM(CASE WHEN DATE(next_review_date) = CURRENT_DATE THEN 1 ELSE 0 END) as due_today,
      AVG(easiness_factor) as average_easiness,
      AVG(CASE WHEN review_count >= 3 THEN 1.0 ELSE 0.0 END) * 100 as mastery_percentage
    FROM concept_review_schedule
    WHERE bot_id = $1 AND user_id = $2
  `;

  try {
    const result = await pool.query(query, [botId, userId]);
    return (
      result.rows[0] || {
        total_concepts: 0,
        concepts_mastered: 0,
        overdue_concepts: 0,
        due_today: 0,
        average_easiness: 0,
        mastery_percentage: 0,
      }
    );
  } catch (error) {
    console.error("Error fetching spaced repetition stats:", error);
    throw error;
  }
}

/**
 * Calculate recommended daily review goal
 * @param {Object} stats - Statistics object from getSpacedRepetitionStats
 * @returns {number} Recommended number of daily reviews
 */
function calculateDailyGoal(stats) {
  const totalConcepts = stats.total_concepts || 0;
  const overdueCount = stats.overdue_concepts || 0;

  // Formula: base load + overhead for catch-up
  let recommendedDaily = Math.max(5, Math.ceil(totalConcepts / 20));

  // Increase if overdue
  if (overdueCount > 0) {
    recommendedDaily = Math.ceil(overdueCount / 3) + recommendedDaily;
  }

  // Cap at maximum
  return Math.min(recommendedDaily, 30);
}

/**
 * Generate review schedule for calendar display
 * @param {Object} pool - Database connection pool
 * @param {string} botId - Study bot ID
 * @param {string} userId - User ID
 * @param {Date} startDate - Start date (default: today)
 * @param {number} daysAhead - Number of days to project (default: 30)
 * @returns {Object} Map of dates to concepts scheduled
 */
async function generateReviewSchedule(
  pool,
  botId,
  userId,
  startDate = new Date(),
  daysAhead = 30,
) {
  const endDate = new Date(startDate);
  endDate.setDate(endDate.getDate() + daysAhead);

  const query = `
    SELECT 
      DATE(next_review_date) as review_date,
      COUNT(*) as review_count,
      array_agg(json_build_object(
        'moduleIndex', module_index,
        'conceptIndex', concept_index,
        'reviewCount', review_count,
        'easinessFactor', easiness_factor
      )) as concepts
    FROM concept_review_schedule
    WHERE bot_id = $1 
      AND user_id = $2
      AND next_review_date >= $3
      AND next_review_date <= $4
    GROUP BY DATE(next_review_date)
    ORDER BY review_date ASC
  `;

  try {
    const result = await pool.query(query, [botId, userId, startDate, endDate]);

    // Convert to map for easier frontend consumption
    const schedule = {};
    result.rows.forEach((row) => {
      schedule[row.review_date] = {
        reviewCount: row.review_count,
        concepts: row.concepts,
      };
    });

    return schedule;
  } catch (error) {
    console.error("Error generating review schedule:", error);
    throw error;
  }
}

/**
 * Get a single concept's review history
 * @param {Object} pool - Database connection pool
 * @param {string} botId - Study bot ID
 * @param {string} userId - User ID
 * @param {number} moduleIndex - Module index
 * @param {number} conceptIndex - Concept index
 * @returns {Object} Review record with full details
 */
async function getConceptReviewHistory(
  pool,
  botId,
  userId,
  moduleIndex,
  conceptIndex,
) {
  const query = `
    SELECT 
      module_index,
      concept_index,
      last_review_date,
      next_review_date,
      review_count,
      easiness_factor,
      interval_days,
      EXTRACT(DAY FROM next_review_date - NOW()) as days_until_due,
      CASE 
        WHEN next_review_date < NOW() THEN true
        ELSE false
      END as is_overdue
    FROM concept_review_schedule
    WHERE bot_id = $1 
      AND user_id = $2
      AND module_index = $3
      AND concept_index = $4
  `;

  try {
    const result = await pool.query(query, [
      botId,
      userId,
      moduleIndex,
      conceptIndex,
    ]);

    if (result.rows.length === 0) {
      return null;
    }

    return result.rows[0];
  } catch (error) {
    console.error("Error fetching concept review history:", error);
    throw error;
  }
}

/**
 * Reset a concept's review schedule (for manual reset)
 * @param {Object} pool - Database connection pool
 * @param {string} botId - Study bot ID
 * @param {string} userId - User ID
 * @param {number} moduleIndex - Module index
 * @param {number} conceptIndex - Concept index
 * @returns {Object} Updated review record
 */
async function resetConceptReview(
  pool,
  botId,
  userId,
  moduleIndex,
  conceptIndex,
) {
  const query = `
    UPDATE concept_review_schedule
    SET 
      next_review_date = NOW(),
      review_count = 0,
      easiness_factor = 2.5,
      interval_days = 1
    WHERE bot_id = $1 
      AND user_id = $2
      AND module_index = $3
      AND concept_index = $4
    RETURNING *
  `;

  try {
    const result = await pool.query(query, [
      botId,
      userId,
      moduleIndex,
      conceptIndex,
    ]);
    return result.rows[0];
  } catch (error) {
    console.error("Error resetting concept review:", error);
    throw error;
  }
}

module.exports = {
  calculateNextReview,
  getConceptsDueForReview,
  getOverdueReviews,
  logReviewCompletion,
  initializeConceptReview,
  getSpacedRepetitionStats,
  calculateDailyGoal,
  generateReviewSchedule,
  getConceptReviewHistory,
  resetConceptReview,
  MINIMUM_EASINESS_FACTOR,
  MAXIMUM_EASINESS_FACTOR,
};
