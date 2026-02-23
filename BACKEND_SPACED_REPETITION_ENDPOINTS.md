/\*\*

- SPACED REPETITION BACKEND ENDPOINTS
-
- Add these endpoints to your express server (server.js)
- After the existing endpoints like /api/chat-enhanced
-
- Remember to require the spaced-repetition-utils.js file at top:
- const srUtils = require('./spaced-repetition-utils');
  \*/

/\*\*

- ENDPOINT 1: GET Daily Review Schedule
-
- GET /api/daily-reviews/:botId/:userId
-
- Returns:
- - concepts due today
- - concepts due in next 7 days
- - overdue concepts
- - recommended daily goal
- - user's current streak
    \*/
    app.get('/api/daily-reviews/:botId/:userId', authenticateToken, async (req, res) => {
    try {
    const { botId, userId } = req.params;

        // Verify user owns this bot
        const botCheck = await pool.query(
          'SELECT * FROM study_bots WHERE id = $1 AND user_id = $2',
          [botId, userId]
        );
        if (botCheck.rows.length === 0) {
          return res.status(403).json({ error: 'Access denied' });
        }

        // Get due concepts
        const dueToday = await srUtils.getConceptsDueForReview(pool, botId, userId);
        const overdue = await srUtils.getOverdueReviews(pool, botId, userId);
        const stats = await srUtils.getSpacedRepetitionStats(pool, botId, userId);
        const recommendedDaily = srUtils.calculateDailyGoal(stats);

        // Get user's current streak
        const streakQuery = `
          SELECT
            COALESCE(MAX(streak_count), 0) as current_streak,
            MAX(streak_date) as last_streak_date
          FROM review_streaks
          WHERE bot_id = $1 AND user_id = $2 AND streak_date >= CURRENT_DATE - INTERVAL '1 day'
        `;
        const streakResult = await pool.query(streakQuery, [botId, userId]);
        const streak = streakResult.rows[0];

        res.json({
          status: 'success',
          data: {
            dueToday: dueToday.length,
            conceptsDueToday: dueToday,
            overdue: overdue.length,
            conceptsOverdue: overdue,
            stats: {
              totalConcepts: parseInt(stats.total_concepts),
              conceptsMastered: parseInt(stats.concepts_mastered),
              masteryPercentage: parseFloat(stats.mastery_percentage),
              averageEasiness: parseFloat(stats.average_easiness),
            },
            recommendedDaily,
            streak: {
              current: streak.current_streak,
              lastDate: streak.last_streak_date,
            },
          },
        });

    } catch (error) {
    console.error('Error fetching daily reviews:', error);
    res.status(500).json({ error: 'Failed to fetch daily reviews' });
    }
    });

/\*\*

- ENDPOINT 2: Log Review Completion
-
- POST /api/log-review/:botId/:userId/:moduleIndex/:conceptIndex
-
- Body:
- {
- "quality": 3, // 0-5 rating of review quality
- "timeSpent": 120 // seconds spent on review
- }
-
- Returns:
- - updated review record
- - next review date
- - mastery status
    \*/
    app.post(
    '/api/log-review/:botId/:userId/:moduleIndex/:conceptIndex',
    authenticateToken,
    async (req, res) => {
    try {
    const { botId, userId, moduleIndex, conceptIndex } = req.params;
    const { quality, timeSpent } = req.body;

          // Validate quality
          if (quality < 0 || quality > 5) {
            return res.status(400).json({
              error: 'Quality must be between 0 and 5',
            });
          }

          // Verify user owns this bot
          const botCheck = await pool.query(
            'SELECT * FROM study_bots WHERE id = $1 AND user_id = $2',
            [botId, userId]
          );
          if (botCheck.rows.length === 0) {
            return res.status(403).json({ error: 'Access denied' });
          }

          // Log review completion
          const updatedRecord = await srUtils.logReviewCompletion(
            pool,
            botId,
            userId,
            parseInt(moduleIndex),
            parseInt(conceptIndex),
            parseInt(quality)
          );

          // Log time spent (optional analytics)
          if (timeSpent) {
            await pool.query(
              `INSERT INTO review_analytics (bot_id, user_id, module_index, concept_index, time_spent, quality)
               VALUES ($1, $2, $3, $4, $5, $6)`,
              [botId, userId, moduleIndex, conceptIndex, timeSpent, quality]
            );
          }

          // Update streak if quality >= 3
          if (quality >= 3) {
            const todayQuery = `
              SELECT * FROM review_streaks
              WHERE bot_id = $1 AND user_id = $2 AND streak_date = CURRENT_DATE
            `;
            const streakCheck = await pool.query(todayQuery, [botId, userId]);

            if (streakCheck.rows.length === 0) {
              // Check if streak should continue
              const yesterdayQuery = `
                SELECT streak_count FROM review_streaks
                WHERE bot_id = $1 AND user_id = $2
                AND streak_date = CURRENT_DATE - INTERVAL '1 day'
              `;
              const yesterday = await pool.query(yesterdayQuery, [botId, userId]);

              const newStreakCount = yesterday.rows.length > 0
                ? yesterday.rows[0].streak_count + 1
                : 1;

              await pool.query(
                `INSERT INTO review_streaks (bot_id, user_id, streak_date, streak_count)
                 VALUES ($1, $2, CURRENT_DATE, $3)`,
                [botId, userId, newStreakCount]
              );
            }
          }

          // Determine if concept is now mastered
          const isMastered = updatedRecord.review_count >= 5;

          res.json({
            status: 'success',
            data: {
              record: updatedRecord,
              nextReviewDate: updatedRecord.next_review_date,
              isMastered,
              message: isMastered
                ? '🎉 Concept mastered! Moving to next.'
                : `Next review scheduled for ${updatedRecord.next_review_date}`,
            },
          });
        } catch (error) {
          console.error('Error logging review:', error);
          res.status(500).json({ error: 'Failed to log review' });
        }

    }
    );

/\*\*

- ENDPOINT 3: Initialize Concept Review Schedule
-
- POST /api/initialize-review/:botId/:userId/:moduleIndex/:conceptIndex
-
- Call this after checkpoint quiz is passed
-
- Returns:
- - review record created
- - first review date (usually same day)
    \*/
    app.post(
    '/api/initialize-review/:botId/:userId/:moduleIndex/:conceptIndex',
    authenticateToken,
    async (req, res) => {
    try {
    const { botId, userId, moduleIndex, conceptIndex } = req.params;

          // Verify user owns this bot
          const botCheck = await pool.query(
            'SELECT * FROM study_bots WHERE id = $1 AND user_id = $2',
            [botId, userId]
          );
          if (botCheck.rows.length === 0) {
            return res.status(403).json({ error: 'Access denied' });
          }

          // Initialize review
          const record = await srUtils.initializeConceptReview(
            pool,
            botId,
            userId,
            parseInt(moduleIndex),
            parseInt(conceptIndex)
          );

          res.json({
            status: 'success',
            data: {
              record,
              message: 'Review schedule initialized. First review available now!',
            },
          });
        } catch (error) {
          console.error('Error initializing review:', error);
          res.status(500).json({ error: 'Failed to initialize review' });
        }

    }
    );

/\*\*

- ENDPOINT 4: Get Review Schedule Calendar
-
- GET /api/review-schedule/:botId/:userId?startDate=2024-01-01&days=30
-
- Returns:
- - calendar of upcoming reviews
- - concepts due each day
- - overdue count
    \*/
    app.get('/api/review-schedule/:botId/:userId', authenticateToken, async (req, res) => {
    try {
    const { botId, userId } = req.params;
    const { startDate, days } = req.query;

        const start = startDate ? new Date(startDate) : new Date();
        const daysAhead = parseInt(days) || 30;

        // Verify user owns this bot
        const botCheck = await pool.query(
          'SELECT * FROM study_bots WHERE id = $1 AND user_id = $2',
          [botId, userId]
        );
        if (botCheck.rows.length === 0) {
          return res.status(403).json({ error: 'Access denied' });
        }

        // Generate schedule
        const schedule = await srUtils.generateReviewSchedule(
          pool,
          botId,
          userId,
          start,
          daysAhead
        );

        // Get stats
        const stats = await srUtils.getSpacedRepetitionStats(pool, botId, userId);

        res.json({
          status: 'success',
          data: {
            schedule,
            stats: {
              totalConcepts: parseInt(stats.total_concepts),
              overdueConcepts: parseInt(stats.overdue_concepts),
              dueToday: parseInt(stats.due_today),
            },
          },
        });

    } catch (error) {
    console.error('Error fetching review schedule:', error);
    res.status(500).json({ error: 'Failed to fetch review schedule' });
    }
    });

/\*\*

- ENDPOINT 5: Get Concept Review History
-
- GET /api/concept-review-history/:botId/:userId/:moduleIndex/:conceptIndex
-
- Returns:
- - full review history for a concept
- - current review count
- - easiness factor
- - days until next review
    \*/
    app.get(
    '/api/concept-review-history/:botId/:userId/:moduleIndex/:conceptIndex',
    authenticateToken,
    async (req, res) => {
    try {
    const { botId, userId, moduleIndex, conceptIndex } = req.params;

          // Verify user owns this bot
          const botCheck = await pool.query(
            'SELECT * FROM study_bots WHERE id = $1 AND user_id = $2',
            [botId, userId]
          );
          if (botCheck.rows.length === 0) {
            return res.status(403).json({ error: 'Access denied' });
          }

          const history = await srUtils.getConceptReviewHistory(
            pool,
            botId,
            userId,
            parseInt(moduleIndex),
            parseInt(conceptIndex)
          );

          if (!history) {
            return res.status(404).json({
              error: 'Concept review not found',
            });
          }

          res.json({
            status: 'success',
            data: {
              history,
              message: `Concept reviewed ${history.review_count} times`,
            },
          });
        } catch (error) {
          console.error('Error fetching concept history:', error);
          res.status(500).json({ error: 'Failed to fetch concept history' });
        }

    }
    );

/\*\*

- ENDPOINT 6: Reset Concept Review
-
- POST /api/reset-review/:botId/:userId/:moduleIndex/:conceptIndex
-
- Admin only - resets a concept back to beginning
  \*/
  app.post(
  '/api/reset-review/:botId/:userId/:moduleIndex/:conceptIndex',
  authenticateToken,
  async (req, res) => {
  try {
  const { botId, userId, moduleIndex, conceptIndex } = req.params;

        // Verify user owns this bot
        const botCheck = await pool.query(
          'SELECT * FROM study_bots WHERE id = $1 AND user_id = $2',
          [botId, userId]
        );
        if (botCheck.rows.length === 0) {
          return res.status(403).json({ error: 'Access denied' });
        }

        const reset = await srUtils.resetConceptReview(
          pool,
          botId,
          userId,
          parseInt(moduleIndex),
          parseInt(conceptIndex)
        );

        res.json({
          status: 'success',
          data: {
            record: reset,
            message: 'Concept review reset to beginning',
          },
        });
      } catch (error) {
        console.error('Error resetting review:', error);
        res.status(500).json({ error: 'Failed to reset review' });
      }

  }
  );

/\*\*

- ENDPOINT 7: Bulk Update Reviews (when study plan changes)
-
- POST /api/update-all-reviews/:botId/:userId
-
- Body:
- {
- "action": "reschedule" | "reset" | "archive"
- }
-
- Reschedule: Move all reviews forward by 1 day
- Reset: Clear all review history
- Archive: Don't show in active schedules
  \*/
  app.post('/api/update-all-reviews/:botId/:userId', authenticateToken, async (req, res) => {
  try {
  const { botId, userId } = req.params;
  const { action } = req.body;

      // Verify user owns this bot
      const botCheck = await pool.query(
        'SELECT * FROM study_bots WHERE id = $1 AND user_id = $2',
        [botId, userId]
      );
      if (botCheck.rows.length === 0) {
        return res.status(403).json({ error: 'Access denied' });
      }

      let query;
      let message;

      switch (action) {
        case 'reschedule':
          query = `
            UPDATE concept_review_schedule
            SET next_review_date = next_review_date + INTERVAL '1 day'
            WHERE bot_id = $1 AND user_id = $2
          `;
          message = 'All reviews rescheduled forward by 1 day';
          break;

        case 'reset':
          query = `
            UPDATE concept_review_schedule
            SET
              review_count = 0,
              easiness_factor = 2.5,
              interval_days = 1,
              next_review_date = NOW()
            WHERE bot_id = $1 AND user_id = $2
          `;
          message = 'All reviews reset to beginning';
          break;

        case 'archive':
          query = `
            DELETE FROM concept_review_schedule
            WHERE bot_id = $1 AND user_id = $2
          `;
          message = 'All review data archived';
          break;

        default:
          return res.status(400).json({
            error: 'Invalid action. Must be: reschedule, reset, or archive',
          });
      }

      const result = await pool.query(query, [botId, userId]);

      res.json({
        status: 'success',
        data: {
          rowsAffected: result.rowCount,
          message,
        },
      });

  } catch (error) {
  console.error('Error updating reviews:', error);
  res.status(500).json({ error: 'Failed to update reviews' });
  }
  });

/\*\*

- ENDPOINT 8: Get Learning Recommendations
-
- GET /api/learning-recommendations/:botId/:userId
-
- Returns personalized recommendations based on:
- - Current review schedule
- - Mastery levels
- - Time availability
- - Learning pace
    \*/
    app.get(
    '/api/learning-recommendations/:botId/:userId',
    authenticateToken,
    async (req, res) => {
    try {
    const { botId, userId } = req.params;

          // Verify user owns this bot
          const botCheck = await pool.query(
            'SELECT * FROM study_bots WHERE id = $1 AND user_id = $2',
            [botId, userId]
          );
          if (botCheck.rows.length === 0) {
            return res.status(403).json({ error: 'Access denied' });
          }

          const stats = await srUtils.getSpacedRepetitionStats(pool, botId, userId);
          const daily = await srUtils.calculateDailyGoal(stats);

          // Generate recommendations
          const recommendations = [];

          if (stats.overdue_concepts > 0) {
            recommendations.push({
              type: 'catch_up',
              priority: 'high',
              message: `You have ${stats.overdue_concepts} overdue reviews. Catch up to maintain your streak!`,
              action: 'startOverdueReviews',
            });
          }

          if (stats.due_today > 0) {
            recommendations.push({
              type: 'daily_goal',
              priority: 'medium',
              message: `${stats.due_today} reviews due today. Complete ${daily} for optimal learning!`,
              action: 'startDailyGoal',
            });
          }

          if (stats.total_concepts > 0 && stats.concepts_mastered / stats.total_concepts >= 0.5) {
            recommendations.push({
              type: 'achievement',
              priority: 'low',
              message: `You've mastered ${stats.concepts_mastered} concepts! Keep going!`,
              action: 'celebrate',
            });
          }

          if (stats.average_easiness < 2.0) {
            recommendations.push({
              type: 'difficulty',
              priority: 'high',
              message: 'These concepts are challenging. Consider studying the prerequisites.',
              action: 'reviewPrerequisites',
            });
          }

          res.json({
            status: 'success',
            data: {
              recommendations,
              recommendedDaily: daily,
              stats: {
                totalConcepts: stats.total_concepts,
                mastered: stats.concepts_mastered,
                overdue: stats.overdue_concepts,
                dueToday: stats.due_today,
              },
            },
          });
        } catch (error) {
          console.error('Error fetching recommendations:', error);
          res.status(500).json({ error: 'Failed to fetch recommendations' });
        }

    }
    );

/\*\*

- INTEGRATION CHECKLIST:
-
- 1.  Copy spaced-repetition-utils.js to backend/
- 2.  Add to server.js top: const srUtils = require('./spaced-repetition-utils');
- 3.  Create database table concept_review_schedule (see utils file)
- 4.  Create optional tables: review_analytics, review_streaks
- 5.  Add these endpoints to server.js
- 6.  Test each endpoint with Postman/Insomnia
- 7.  Update frontend to call these endpoints
- 8.  Monitor database performance with heavy usage
- \*/
