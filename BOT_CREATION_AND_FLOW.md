# Bot Creation & Runtime Flow (analysis)

This document summarizes what happens when a Study Bot is created in the app, which instructions are embedded in the bot, how greetings and study-plan interactions are handled, and where the frontend should display the study plan.

## Endpoints involved

- `POST /api/create-study-bot` — creates the bot record and initial progress, generates system instructions, and inserts an initial bot greeting into `chat_messages` if none exists.
- `GET /api/bot/:botId/instructions` — fetches the saved `system_instructions` for a bot.
- `POST /api/chat-enhanced` — primary chat endpoint: fetches DB instructions, builds messages for the model, returns AI response, and now (after recent changes) avoids duplicate greetings and persists greetings into `chat_messages`.
- `POST /api/update-study-plan` — saves an updated study plan into `bot_progress`.
- `POST /api/generate-quiz` — generates and saves quizzes related to modules.

## Database artifacts

- `study_bots.system_instructions` (JSONB): stores the bot's system_instructions object. On creation this contains `{ instructions: <string> }` where `<string>` is the generated instruction template.
- `bot_progress.study_plan` (JSONB): stores the saved study plan for a bot/user. On creation it's initialized to `{ modules: [] }`.
- `bot_progress.bot_state` (VARCHAR): tracks the bot lifecycle state (examples: `intro`, `waiting_for_user`, `in_study`).
- `chat_messages` rows of type `bot` persist AI-sent messages (welcome, quizzes, etc.).

## Instructions injected into bots at creation

- The instruction text is produced by `generateNaturalStudyBotInstructions(botName, botTopic, description, gradeLevel)`.
- Key directives present in the generated instructions:
  - A warm, human persona and communication style.
  - "FIRST MESSAGE BEHAVIOR": explicit greeting template and guidance to ask "How are you doing today?" before starting study content.
  - Teaching approach: step-by-step, check for understanding, ask follow-ups, adapt tone and pace.
  - Module completion and quiz handling: when a module is completed, the bot should trigger the quiz popup by including the token `[SHOW_QUIZ_POPUP]` and save progress.
  - New: Study-plan creation directive — the bot will explicitly ask the user whether they want a personalized study plan. If the user agrees, the bot must include the token `[SHOW_STUDY_PLAN]` and present a concise plan summary for the frontend to render.

## How duplicate greetings are prevented (server-side)

- On creation: `POST /api/create-study-bot` inserts an initial `bot_progress` row (state `intro`) and, if no `chat_messages` bot message exists, inserts a deterministic welcome message into `chat_messages`.
- On session start: `POST /api/chat-enhanced` checks if the incoming message is the literal `[START_SESSION]`. If so, it will return the earliest bot `chat_messages` entry instead of asking the model to produce a greeting again.
- The chat flow also reads `bot_progress.bot_state` and when the state is not `intro` it adds a system directive to the model messages: "Do NOT repeat the initial welcome message." This reduces model-side duplication.
- After generating an AI response that looks like a greeting, the backend persists it into `chat_messages` (if not duplicate) and updates `bot_progress.bot_state` to `waiting_for_user` (or `in_study` depending on response content).

## Study plan creation and display

- Instruction token: The bot will include the literal token `[SHOW_STUDY_PLAN]` in a response when it proposes a study plan or after the user agrees to create one.
- Frontend display location: The app's frontend should detect the `[SHOW_STUDY_PLAN]` token in AI responses and navigate to the Study Plan UI (e.g., `StudyPlanChatScreen` or equivalent). The frontend should then fetch the saved plan from `bot_progress.study_plan` (or call `GET /api/bot/:botId/instructions` and `GET /api/chat-history/:botId/:userId` as needed) or accept a plan payload returned inline with the bot message.
- Creating & saving the plan:
  - The bot should only create a plan after explicit user consent.
  - The frontend may send the generated plan back to `POST /api/update-study-plan` as `updatedPlan` to persist it in `bot_progress.study_plan`.
  - Alternatively, the backend may persist the plan server-side if the bot returns structured JSON for the plan and the backend receives the user's confirmation; current code supports `POST /api/update-study-plan` to store the plan.

## Recommended frontend integration behavior (from server analysis)

- On bot creation success, frontend navigates to `StudyPlanChatScreen`. The backend now returns a `verification` object in the create response which includes a `welcomeMessagesCount` and `welcomeMessage` preview — the frontend can use this to decide immediate navigation.
- On initial session start (`[START_SESSION]`), the frontend should call `POST /api/chat-enhanced` with `message: "[START_SESSION]"` and display the returned `response` (the stored greeting) without prompting the model.
- Detect `[SHOW_STUDY_PLAN]` in AI responses and open the Study Plan UI. If the AI also included a serialized plan in its message (recommended), parse it and either display as preview and prompt the user to confirm saving, or send it to `POST /api/update-study-plan` immediately if consent was obtained.

## Edge cases and notes

- The current system ensures a deterministic initial welcome is inserted at creation if none exists; however, third-party model responses could still include greetings later — the backend now adds a system message to avoid repeats when `bot_progress.bot_state !== 'intro'` and persists greetings only once.
- The `generateNaturalStudyBotInstructions` function contains several tokens/markers used by the frontend (`[SHOW_QUIZ_POPUP]`) and now `[SHOW_STUDY_PLAN]`. The frontend should look for these markers exactly (case-sensitive) in the AI response body.
- Study plan structure: by default `bot_progress.study_plan` is `{ modules: [] }`. The app and bot should agree on a plan schema (module name, objectives, length, estimated time) when exchanging plans.

## Quick checklist for implementing a smooth UX

- Frontend: when receiving `create-study-bot` success, navigate to StudyPlan screen if `verification.welcomeMessagesCount` is 1 and `verification.welcomeMessage` exists.
- Frontend: detect `[SHOW_STUDY_PLAN]` in AI replies and open Study Plan UI.
- Frontend: send user decisions (accept/decline/modify plan) to `POST /api/update-study-plan`.
- Backend: the server already persists initial greetings, avoids duplicates, and updates `bot_progress.bot_state` to `waiting_for_user` after greeting.

---

If you want, I can:

- Add structured JSON output support for the bot to return a fully-formed study plan inline (so the backend can persist it automatically once the user confirms), or
- Implement a `/api/apply-study-plan` endpoint that accepts a generated plan and sets `bot_progress.study_plan` and `bot_progress.bot_state` atomically.

Which would you like next?
