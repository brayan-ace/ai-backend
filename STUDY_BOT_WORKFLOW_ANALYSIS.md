# Study Bot Workflow Analysis

## Overview

This document explains the workflow and connections between the key components of the study bot AI aspect of the app. The components include:

1. **UserStudyState** - Manages the persistent state of a user's study journey.
2. **StudyController** - Handles study-related operations and integrates with UserStudyState.
3. **Study Routes** - Defines API endpoints for study-related operations.
4. **ConversationMemory** - Manages conversation history and context for the AI.
5. **Server.js** - Backend server that handles API requests and integrates with AI services.
6. **db.js** - Database connection and configuration.
7. **Bot Processing Screen** - Frontend screen for creating and processing study bots.
8. **Study Plan Chat Screen** - Frontend screen for interacting with the study bot.

## Component Connections and Workflow

### 1. UserStudyState

- **Purpose**: Manages the persistent state of a user's study journey, including phases, study plans, module progress, and preferences.
- **Connections**:
  - **Database**: Uses `db.js` to interact with the `user_study_state` table.
  - **StudyController**: Used by `StudyController` to update and retrieve the user's study state.
- **Key Methods**:
  - `initialize(userId, botId)`: Initializes or retrieves the user's study state.
  - `updatePhase(phase)`: Updates the current phase of the study journey.
  - `updateStudyPlan(plan)`: Updates the active study plan.
  - `markModuleCompleted(moduleIndex)`: Marks a module as completed.
  - `getCurrentState()`: Retrieves the current state.

### 2. StudyController

- **Purpose**: Handles study-related operations and integrates with `UserStudyState`.
- **Connections**:
  - **UserStudyState**: Uses `UserStudyState` to manage the user's study state.
  - **Study Routes**: Used by `studyRoutes.js` to handle API requests.
- **Key Methods**:
  - `getOrInitializeStudyState(userId, botId)`: Retrieves or initializes the user's study state.
  - `updateStudyState(userId, botId, updates)`: Updates the study state based on user interactions.
  - `generateStudyPlan(topic, gradeLevel, moduleCount)`: Generates a study plan.
  - `getCurrentModule(userId, botId)`: Retrieves the current module being studied.
  - `completeModule(userId, botId)`: Marks a module as completed and advances to the next one.

### 3. Study Routes

- **Purpose**: Defines API endpoints for study-related operations.
- **Connections**:
  - **StudyController**: Uses `StudyController` to handle study-related operations.
  - **Server.js**: Integrated into `server.js` to handle API requests.
- **Key Endpoints**:
  - `GET /:userId/:botId/state`: Retrieves or initializes the study state.
  - `POST /:userId/:botId/state`: Updates the study state.
  - `POST /:userId/:botId/plan`: Generates a study plan.
  - `GET /:userId/:botId/current-module`: Retrieves the current module.
  - `POST /:userId/:botId/complete-module`: Marks a module as completed.

### 4. ConversationMemory

- **Purpose**: Manages conversation history and context for the AI.
- **Connections**:
  - **Database**: Uses `db.js` to interact with the `conversation_memory` table.
  - **Server.js**: Used by `server.js` to manage conversation context and history.
- **Key Methods**:
  - `addInteraction(userMessage, aiResponse, intent, topicSignature)`: Adds a new interaction to the conversation memory.
  - `getRelevantContext(newMessage)`: Retrieves relevant context for a new message.
  - `loadFromDatabase()`: Loads conversation memory from the database.
  - `clearMemory()`: Clears the conversation memory.

### 5. Server.js

- **Purpose**: Backend server that handles API requests and integrates with AI services.
- **Connections**:
  - **Database**: Uses `db.js` to interact with the database.
  - **Study Routes**: Integrates `studyRoutes.js` to handle study-related API requests.
  - **ConversationMemory**: Uses `ConversationMemory` to manage conversation context and history.
  - **AI Services**: Integrates with AI services like Groq and Gemini for generating responses and quizzes.
- **Key Endpoints**:
  - `POST /api/chat-enhanced`: Handles chat messages and generates AI responses.
  - `POST /api/generate-quiz`: Generates quizzes based on study content.
  - `POST /api/create-study-bot`: Creates a new study bot.
  - `GET /api/chat-history/:botId/:userId`: Retrieves chat history for a bot and user.

### 6. db.js

- **Purpose**: Database connection and configuration.
- **Connections**:
  - **UserStudyState**: Used by `UserStudyState` to interact with the database.
  - **ConversationMemory**: Used by `ConversationMemory` to interact with the database.
  - **Server.js**: Used by `server.js` to interact with the database.
- **Key Configuration**:
  - Configures a PostgreSQL connection pool using environment variables.

### 7. Bot Processing Screen

- **Purpose**: Frontend screen for creating and processing study bots.
- **Connections**:
  - **Server.js**: Calls the `POST /api/create-study-bot` endpoint to create a new study bot.
  - **Study Plan Chat Screen**: Navigates to the `StudyPlanChatScreen` after the bot is created.
- **Key Functions**:
  - `_callCreateStudyBot()`: Calls the backend to create a new study bot.
  - `_startProcessing()`: Starts the bot creation process and navigates to the chat screen.

### 8. Study Plan Chat Screen

- **Purpose**: Frontend screen for interacting with the study bot.
- **Connections**:
  - **Server.js**: Calls various endpoints to interact with the study bot, including:
    - `POST /api/chat-enhanced`: Sends messages to the bot and receives responses.
    - `POST /api/generate-quiz`: Generates quizzes.
    - `GET /api/chat-history/:botId/:userId`: Retrieves chat history.
  - **Study Plan Service**: Uses `StudyPlanService` to manage the study plan and bot state.
  - **Study Bot Flow Controller**: Uses `StudyBotFlowController` to manage the flow of the study bot.
- **Key Functions**:
  - `_sendMessageToBackend(userMessage)`: Sends a message to the backend and receives a response.
  - `_fetchInitialGreeting()`: Fetches the initial greeting from the bot.
  - `_generateQuiz(config)`: Generates a quiz based on the study content.

## Workflow

### Bot Creation

1. **Bot Processing Screen**: The user initiates the creation of a study bot by providing details like name, description, topic, and grade level.
2. **Server.js**: The `POST /api/create-study-bot` endpoint is called, which creates a new study bot and initializes its state.
3. **Database**: The bot details and initial state are stored in the database.
4. **Study Plan Chat Screen**: The user is navigated to the chat screen to interact with the bot.

### Bot Interaction

1. **Study Plan Chat Screen**: The user sends a message to the bot.
2. **Server.js**: The `POST /api/chat-enhanced` endpoint is called, which processes the message and generates a response using AI services.
3. **ConversationMemory**: The conversation history is updated with the new interaction.
4. **Study Plan Chat Screen**: The bot's response is displayed to the user.

### Study Plan Management

1. **Study Plan Chat Screen**: The user requests to generate or update a study plan.
2. **Server.js**: The `POST /:userId/:botId/plan` endpoint is called, which generates a study plan using the `StudyController`.
3. **UserStudyState**: The study plan is stored in the user's study state.
4. **Study Plan Chat Screen**: The study plan is displayed to the user.

### Quiz Generation

1. **Study Plan Chat Screen**: The user requests to generate a quiz.
2. **Server.js**: The `POST /api/generate-quiz` endpoint is called, which generates a quiz based on the study content.
3. **Study Plan Chat Screen**: The quiz is displayed to the user.

## Conclusion

The study bot AI aspect of the app is well-connected and follows a clear workflow. Each component has a specific purpose and interacts with other components to provide a seamless experience for the user. The connections are well-implemented, and the workflow ensures that the user's study journey is managed effectively.

## Debugging the Study Bot Chat

To debug the 500 server error in the study bot chat, follow these steps:

1. **Check the Server Logs**: Look for any error messages or stack traces in the server logs.
2. **Verify API Endpoints**: Ensure that all API endpoints are correctly configured and accessible.
3. **Test Database Connections**: Verify that the database connections are working and that the required tables exist.
4. **Review AI Service Integrations**: Ensure that the AI services (Groq, Gemini) are correctly configured and that the API keys are valid.
5. **Inspect Request Payloads**: Check the payloads sent to the server to ensure they are correctly formatted and contain the required data.
6. **Test Individual Components**: Test each component individually to identify the source of the error.

By following these steps, you can identify and resolve the 500 server error in the study bot chat.
