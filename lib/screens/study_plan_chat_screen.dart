import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/study_bot_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/study_plan_service.dart';
import '../services/study_bot_flow_controller.dart';
import '../services/tutor_engagement_service.dart';
import '../services/progress_tracking_service.dart';
import '../services/study_bot_storage_service.dart';
import '../services/study_bot_firebase_service.dart';
import '../services/gamification_service.dart';
import '../services/analytics_service.dart';
import '../utils/theme.dart';
import 'study_plan_editor_screen.dart';
import 'quiz_config_screen.dart';
import '../widgets/quiz_artifact_widget.dart';
import '../widgets/premium_study_plan_menu.dart';
import '../widgets/premium_typing_indicator.dart';
import '../widgets/premium_message_bubble.dart';
import '../services/study_activity_service.dart';
import '../services/study_notification_service.dart';
import '../services/text_to_speech_service.dart';

// Premium color palette matching bot creation and processing screens
class PremiumColors {
  static const Color darkBg = Color(0xFF0a0a0a); // Pure black
  static const Color darkBg2 = Color(0xFF1a1a2e); // Deep blue-black
  static const Color accentGradient1 = Color(0xFF6366f1); // Indigo
  static const Color accentGradient2 = Color(0xFF8b5cf6); // Purple
  static const Color accentGradient3 = Color(0xFF3b82f6); // Blue
  static const Color cardBg = Color(0xFF111827); // Very dark gray
  static const Color focusBorder = Color(0xFF4f46e5); // Focus blue
  static const Color successGreen = Color(0xFF10b981); // Success green
}

// Widget to render formatted text with emojis and markdown-like styling
// Includes professional spacing, line separators, and full-width containers
class FormattedTextWidget extends StatelessWidget {
  final String text;

  const FormattedTextWidget(this.text, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Split text by double newlines (paragraphs) for better formatting
    final paragraphs = text.split(RegExp(r'\n\n+'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < paragraphs.length; i++) ...[
          _buildParagraph(paragraphs[i].trim()),
          // Add space between paragraphs, but not after the last one
          if (i < paragraphs.length - 1) SizedBox(height: AppTheme.spaceSm),
        ],
      ],
    );
  }

  Widget _buildParagraph(String paragraph) {
    if (paragraph.isEmpty) return SizedBox.shrink();

    final spans = _parseMarkdownToSpans(paragraph);
    return RichText(
      text: TextSpan(
        children: spans,
        style: AppTheme.bodyMedium.copyWith(
          color: AppTheme.textPrimary,
          height: 1.5,
        ),
      ),
    );
  }

  List<TextSpan> _parseMarkdownToSpans(String text) {
    final spans = <TextSpan>[];

    // Enhanced regex pattern for:
    // - **bold text**
    // - ### Heading 3
    // - ## Heading 2
    // - # Heading 1
    // - •️ Bullet points
    final pattern = RegExp(
      r'\*\*(.+?)\*\*|###\s+(.+?)(?=\n|$)|##\s+(.+?)(?=\n|$)|#\s+(.+?)(?=\n|$)',
      multiLine: true,
    );

    var lastIndex = 0;
    for (final match in pattern.allMatches(text)) {
      // Add plain text before the match
      if (lastIndex < match.start) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }

      // Handle bold text
      if (match.group(1) != null) {
        spans.add(
          TextSpan(
            text: match.group(1),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryBlue,
            ),
          ),
        );
      }
      // Handle heading level 3
      else if (match.group(2) != null) {
        spans.add(
          TextSpan(
            text: match.group(2),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.primaryBlue,
            ),
          ),
        );
      }
      // Handle heading level 2
      else if (match.group(3) != null) {
        spans.add(
          TextSpan(
            text: match.group(3),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppTheme.primaryBlue,
            ),
          ),
        );
      }
      // Handle heading level 1
      else if (match.group(4) != null) {
        spans.add(
          TextSpan(
            text: match.group(4),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.primaryBlue,
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return spans.isEmpty ? [TextSpan(text: text)] : spans;
  }
}

class StudyPlanChatScreen extends StatefulWidget {
  // Phase 1 Bot Parameters
  final String? botId;
  final String? planName;
  final String? planDescription;
  final String? botName;
  final String? educationLevel;
  final Map<String, dynamic>? systemInstructions;

  // Legacy parameters (for backward compatibility)
  final String? planId;
  final String? planTitle;
  final String? planContext;

  // Phase 2 Parameters
  final StudyBotState? initialState;

  const StudyPlanChatScreen({
    Key? key,
    // Phase 1
    this.botId,
    this.planName,
    this.planDescription,
    this.botName,
    this.educationLevel,
    this.systemInstructions,
    // Legacy
    this.planId,
    this.planTitle,
    this.planContext,
    // Phase 2
    this.initialState,
  }) : super(key: key);

  @override
  State<StudyPlanChatScreen> createState() => _StudyPlanChatScreenState();
}

class _StudyPlanChatScreenState extends State<StudyPlanChatScreen> {
  late StudyPlanService _planService;
  late StudyBotFlowController _flowController;
  late TutorEngagementService _tutorService;
  late ProgressTrackingService _progressService;
  late GamificationService _gamificationService;
  late AnalyticsService _analyticsService;
  late StudyActivityService _studyActivityService;
  late StudyNotificationService _studyNotificationService;

  bool _isPhase1 = false;
  bool _isPhase2 = false;

  // Phase 2 state
  StudyBotState? _botState;
  List<StudyBotMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;
  bool _showToc = false;
  bool _showScrollToBottom = false;

  // Analytics tracking
  DateTime? _sessionStartTime;
  List<String> _conceptsLearned = [];
  int _sessionMessageCount = 0;

  // Bot instructions from database
  Map<String, dynamic>? _botInstructions;

  // Study plan management
  Map<String, dynamic>? _studyPlan;
  int _planVersion = 1;

  // Progress tracking
  double _progressPercentage = 0;
  String _botCurrentState = 'intro';
  LearnerProfile? _learnerProfile;
  UserMoodState? _currentMood;

  // Quiz tracking
  int? _currentQuizId;

  // Backend URL
  static const String _backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://ai-backend-vf75.onrender.com',
  );

  // Firebase Firestore instance - EXACT same pattern as OnlineAiScreen
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late StudyBotStorageService _storageService;
  late StudyBotFirebaseService _firebaseService;

  @override
  void initState() {
    super.initState();
    _planService = StudyPlanService();
    _flowController = StudyBotFlowController();
    _tutorService = TutorEngagementService();
    _progressService = ProgressTrackingService();
    _gamificationService = GamificationService();
    _analyticsService = AnalyticsService();
    _studyActivityService = StudyActivityService();
    _studyNotificationService = StudyNotificationService();
    _storageService = StudyBotStorageService();
    _firebaseService = StudyBotFirebaseService();

    // Add scroll listener for scroll-to-bottom button
    _scrollController.addListener(_onScroll);

    // Initialize bot instructions from parameters
    _botInstructions = widget.systemInstructions;
    print(
      '[ChatScreen] initState: botId=${widget.botId}, instructions loaded=${_botInstructions != null}',
    );

    // Detect mode
    _isPhase1 = widget.botId != null && widget.botName != null;
    _isPhase2 =
        _isPhase1 &&
        widget.initialState == null; // Check if Phase 2 should be initialized

    if (_isPhase2) {
      _initPhase2();
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final shouldShow = maxScroll - currentScroll > 200;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      HapticFeedback.lightImpact();
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _initPhase2() async {
    try {
      // Initialize botState first so screen can render
      if (_botState == null && widget.botId != null) {
        _botState = _flowController.createNewSession(botId: widget.botId!);
      }

      // Initialize progress tracking for this session
      if (_botState != null) {
        final toc = _botState!.tableOfContents;
        final totalModules = toc?.length ?? 8;
        await _progressService.initializeProgress(
          _botState!.sessionId,
          totalModules,
        );
      }

      // If resuming a bot, load chat history from Firebase and progress from backend
      if (widget.botId != null) {
        final currentUser = FirebaseAuth.instance.currentUser;
        final userId = currentUser?.uid ?? 'anonymous';

        // Initialize Firebase chat session
        try {
          await _storageService.getOrCreateBotChat(
            botId: widget.botId!,
            botName: widget.botName ?? 'Study Bot',
            topic: widget.planName,
            description: widget.planDescription,
          );
          print('[ChatScreen] 🔥 Firebase chat session initialized');

          // Save bot metadata to Firestore for RecentStudyBotsScreen
          try {
            await _firebaseService.saveBot(
              botId: widget.botId!,
              name: widget.botName ?? 'Study Bot',
              topic: widget.planName ?? '',
              description: widget.planDescription ?? '',
              gradeLevel: widget.educationLevel ?? '',
              systemInstructions: widget.systemInstructions,
              progressPercentage: _progressPercentage,
              currentModule: 0,
              botState: _botCurrentState,
            );
            print('[ChatScreen] 🔥 Bot metadata saved to Firestore');
          } catch (e) {
            print('[ChatScreen] ⚠️ Bot metadata save error (non-blocking): $e');
          }
        } catch (e) {
          print('[ChatScreen] ⚠️ Firebase init error (non-blocking): $e');
        }

        // Load chat history from Firebase (primary source)
        try {
          final firebaseMessages = await _storageService.getMessages(
            widget.botId!,
          );
          if (firebaseMessages.isNotEmpty) {
            final messages = firebaseMessages
                .map(
                  (m) => StudyBotMessage(
                    id:
                        m['id'] as String? ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    senderType:
                        m['senderType'] as String? ??
                        (m['fromUser'] == true ? 'user' : 'bot'),
                    text: m['text'] as String? ?? '',
                    timestamp:
                        (m['timestamp'] as dynamic)?.toDate() ?? DateTime.now(),
                  ),
                )
                .toList();

            setState(() => _messages = messages);
            print(
              '[ChatScreen] 🔥 Loaded ${messages.length} messages from Firebase',
            );
          }
        } catch (e) {
          print('[ChatScreen] ⚠️ Firebase history load error: $e');
          // Fallback to backend if Firebase fails
          try {
            final historyUri = Uri.parse(
              '$_backendUrl/api/chat-history/${widget.botId}/$userId',
            );
            final historyRes = await http
                .get(historyUri)
                .timeout(const Duration(seconds: 15));

            if (historyRes.statusCode == 200) {
              final body = jsonDecode(historyRes.body);
              final messages = (body['messages'] as List? ?? [])
                  .map(
                    (m) => StudyBotMessage(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      senderType: m['senderType'] as String? ?? 'user',
                      text: m['text'] as String? ?? '',
                      timestamp: DateTime.parse(
                        m['timestamp'] as String? ??
                            DateTime.now().toIso8601String(),
                      ),
                    ),
                  )
                  .toList();

              setState(() => _messages = messages);
              print(
                '[ChatScreen] 📡 Loaded ${messages.length} messages from backend (fallback)',
              );
            }
          } catch (backendErr) {
            print('[ChatScreen] ❌ Backend history also failed: $backendErr');
          }
        }

        // Fetch bot progress and state from backend
        try {
          final progressUri = Uri.parse(
            '$_backendUrl/api/bot-progress/${widget.botId}/$userId',
          );
          final progressRes = await http
              .get(progressUri)
              .timeout(const Duration(seconds: 15));

          if (progressRes.statusCode == 200) {
            final body = jsonDecode(progressRes.body);
            setState(() {
              _botCurrentState = body['bot_state'] as String? ?? 'intro';
              _progressPercentage =
                  (body['progress']?['percentage'] as num?)?.toDouble() ?? 0.0;
              _studyPlan = body['study_plan'] as Map<String, dynamic>?;
            });
            print(
              '[ChatScreen] Restored state: $_botCurrentState, progress: $_progressPercentage%',
            );
            if (_studyPlan != null) {
              print('[ChatScreen] Loaded study plan with modules');
            }
          }
        } catch (e) {
          print('[ChatScreen] Error loading progress: $e');
        }
      }

      // If no messages loaded, create fresh session and fetch greeting
      if (_messages.isEmpty) {
        _botState = _flowController.createNewSession(botId: widget.botId!);

        // Fetch fresh system instructions from backend FIRST
        if (widget.botId != null) {
          await _fetchFreshSystemInstructions(widget.botId!);
        }

        // Fetch initial greeting from backend
        await _fetchInitialGreeting();
      }

      setState(() {});
    } catch (e) {
      print('[ChatScreen] Error in _initPhase2: $e');
    }
  }

  // Note: frontend warm greetings removed. All greetings must come from backend.

  /// Fetch the latest system instructions from the backend database
  Future<void> _fetchFreshSystemInstructions(String botId) async {
    try {
      final uri = Uri.parse('$_backendUrl/api/bot/$botId/instructions');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final freshInstructions =
            body['systemInstructions'] as Map<String, dynamic>?;

        if (freshInstructions != null) {
          setState(() {
            _botInstructions = freshInstructions;
          });
          print('[ChatScreen] ✅ Fresh system instructions fetched and updated');
          print(
            '[ChatScreen] Bot: ${body['botName']}, Topic: ${body['topic']}',
          );
        }
      } else {
        print(
          '[ChatScreen] ⚠️ Failed to fetch fresh instructions: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('[ChatScreen] ⚠️ Error fetching fresh instructions: $e');
      // Non-blocking error - continue with existing instructions
    }
  }

  /// Fetch the initial greeting from backend
  /// This triggers the AI to generate a greeting based on system instructions
  Future<void> _fetchInitialGreeting() async {
    try {
      print(
        '[ChatScreen] 🎯 _fetchInitialGreeting() CALLED - Getting fresh AI greeting',
      );
      print(
        '[ChatScreen] 📋 System Instructions available: ${_botInstructions != null}',
      );
      if (_botInstructions != null) {
        final instructions = _botInstructions?['instructions'] as String? ?? '';
        print(
          '[ChatScreen] 📝 Instructions preview: "${instructions.substring(0, 150)}..."',
        );
      }
      final currentUser = FirebaseAuth.instance.currentUser;
      final userId = currentUser?.uid ?? 'anonymous';
      print('[ChatScreen] 👤 User ID: $userId');

      final uri = Uri.parse('$_backendUrl/api/chat-enhanced');
      print('[ChatScreen] 🔗 Calling endpoint: $uri');

      final payload = {
        'message': '[START_SESSION]', // Special message to trigger greeting
        'botId': widget.botId,
        'userId': userId,
        'systemInstructions': _botInstructions,
      };
      print(
        '[ChatScreen] 📨 Payload: message=[START_SESSION], botId=${widget.botId}',
      );

      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(Duration(seconds: 30));

      print('[ChatScreen] 📬 Response status: ${resp.statusCode}');

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        print('[ChatScreen] 📦 Full response body: $body');
        final botResponse = body['response'] ?? 'Let\'s get started!';
        print('[ChatScreen] ✅ AI GREETING RECEIVED from backend');
        print('[ChatScreen] 💬 Greeting text: "$botResponse"');
        print('[ChatScreen] 💬 Greeting length: ${botResponse.length} chars');
        await _addBotMessage(botResponse);
        print(
          '[ChatScreen] ✅ Initial greeting fetched from backend and displayed',
        );
      } else {
        print('[ChatScreen] ⚠️ Failed to fetch greeting: ${resp.statusCode}');
        print('[ChatScreen] Response body: ${resp.body}');
        // Fallback - still let user interact, backend will respond when they type
      }
    } catch (e) {
      print('[ChatScreen] ❌ Error fetching initial greeting: $e');
      // Non-blocking - user can still send messages and backend will respond
    }
  }

  /// Add study plan card to chat when plan is generated
  Future<void> _addStudyPlanToChat(Map<String, dynamic> plan) async {
    final modules = plan['modules'] as List? ?? [];
    if (modules.isEmpty) return;

    // Build a formatted study plan message
    final buffer = StringBuffer();
    buffer.writeln('📚 **Your Study Plan is Ready!**\n');
    buffer.writeln(
      'I\'ve created a personalized study plan with **${modules.length} modules**:\n',
    );

    for (int i = 0; i < modules.length; i++) {
      final mod = modules[i] as Map<String, dynamic>;
      final title = mod['title'] ?? mod['module_name'] ?? 'Module ${i + 1}';
      final topics = mod['key_topics'] ?? mod['subtopics'] ?? [];
      final topicCount = (topics as List).length;
      buffer.writeln('**${i + 1}. $title** ($topicCount topics)');
    }

    buffer.writeln(
      '\n✨ *Tap the menu icon ☰ to view the full plan and track your progress!*',
    );

    final message = StudyBotMessage(
      id: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      senderType: 'bot',
      text: buffer.toString(),
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(message);
    });
  }

  Future<void> _addBotMessage(String text) async {
    // Apply mood-aware response adaptation
    String adaptedText = _applyMoodAdaptation(text);

    // Check if this is a quiz popup trigger
    if (adaptedText.contains('[SHOW_QUIZ_POPUP]')) {
      // Extract the actual message (without the marker)
      final displayText = adaptedText
          .replaceAll('[SHOW_QUIZ_POPUP]', '')
          .trim();

      // Add the message without the marker
      final message = StudyBotMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderType: 'bot',
        text: displayText,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(message);
      });

      if (_botState != null) {
        _botState = _botState!.copyWith(
          chatHistory: _messages.map((m) => m.toJson()).toList(),
        );
        await _planService.saveBotState(_botState!);
      }

      // Show quiz popup after a short delay to let the message display
      Future.delayed(Duration(milliseconds: 500), () {
        _showQuizPopup();
      });
    } else {
      // Normal message handling
      final message = StudyBotMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderType: 'bot',
        text: adaptedText,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(message);
      });

      // Save bot message to Firebase
      if (widget.botId != null) {
        try {
          await _storageService.saveMessage(
            botId: widget.botId!,
            text: adaptedText,
            fromUser: false,
          );
          print('[ChatScreen] 🔥 Bot message saved to Firebase');

          // Update bot metadata in Firestore
          await _firebaseService.saveBot(
            botId: widget.botId!,
            name: widget.botName ?? 'Study Bot',
            topic: widget.planName ?? '',
            description: widget.planDescription ?? '',
            gradeLevel: widget.educationLevel ?? '',
            systemInstructions: widget.systemInstructions,
            progressPercentage: _progressPercentage,
            currentModule: 0,
            botState: _botCurrentState,
          );
          print('[ChatScreen] 🔥 Bot metadata updated in Firestore');
        } catch (e) {
          print('[ChatScreen] ⚠️ Firebase save error (non-blocking): $e');
        }
      }

      if (_botState != null) {
        _botState = _botState!.copyWith(
          chatHistory: _messages.map((m) => m.toJson()).toList(),
        );
        await _planService.saveBotState(_botState!);
      }
    }
  }

  Future<void> _addUserMessage(String text) async {
    // Stop any active speech when user sends a new message
    try {
      await TextToSpeechService().stop();
      print('[ChatScreen] 🔇 Stopped active speech on new user message');
    } catch (e) {
      print('[ChatScreen] ⚠️ Error stopping speech: $e');
    }

    final message = StudyBotMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderType: 'user',
      text: text,
      timestamp: DateTime.now(),
    );

    // Save user message to Firebase
    if (widget.botId != null) {
      try {
        await _storageService.saveMessage(
          botId: widget.botId!,
          text: text,
          fromUser: true,
        );
        print('[ChatScreen] 🔥 User message saved to Firebase');

        // Update bot metadata in Firestore
        await _firebaseService.saveBot(
          botId: widget.botId!,
          name: widget.botName ?? 'Study Bot',
          topic: widget.planName ?? '',
          description: widget.planDescription ?? '',
          gradeLevel: widget.educationLevel ?? '',
          systemInstructions: widget.systemInstructions,
          progressPercentage: _progressPercentage,
          currentModule: 0,
          botState: _botCurrentState,
        );
        print('[ChatScreen] 🔥 Bot metadata updated in Firestore');
      } catch (e) {
        print('[ChatScreen] ⚠️ Firebase save error (non-blocking): $e');
      }
    }

    // Detect user mood from this message
    _currentMood = _tutorService.detectMood(text);
    print('[ChatScreen] Detected mood: ${_currentMood?.sentiment}');

    // Check if user is indicating understanding or confusion
    if (_indicatesUnderstanding(text)) {
      print('[ChatScreen] User indicated understanding');
      // Will trigger milestone recording after backend response
    } else if (_indicatesConfusion(text)) {
      print('[ChatScreen] User indicated confusion');
      // Backend will know to provide clarification
    }

    // Build learner profile from initial exchanges if not yet built
    if (_learnerProfile == null && _messages.length < 6) {
      // Build profile from first few exchanges
      final exchange = _messages
          .map((m) => {'text': m.text, 'sender': m.senderType})
          .toList();
      exchange.add({'text': text, 'sender': 'user'});
      _learnerProfile = _tutorService.buildLearnerProfile(
        _botState?.sessionId ?? 'unknown',
        exchange.cast<Map<String, String>>(),
      );
      print(
        '[ChatScreen] Learner profile built: ${_learnerProfile?.learningStyle}',
      );
    }

    setState(() {
      _messages.add(message);
      _inputController.clear();
      _isLoading = true;
    });

    // Send message to backend AI
    await _sendMessageToBackend(text);
  }

  Future<void> _sendMessageToBackend(String userMessage) async {
    try {
      print('[ChatScreen] Sending message to backend: $userMessage');
      print('[ChatScreen] Bot ID: ${widget.botId}');

      // Get current user ID from Firebase Auth
      final currentUser = FirebaseAuth.instance.currentUser;
      final userId = currentUser?.uid ?? 'anonymous';
      print('[ChatScreen] User ID: $userId');

      // Get conversation history from Firebase for AI context
      List<Map<String, String>> conversationHistory = [];
      if (widget.botId != null) {
        try {
          conversationHistory = await _storageService
              .getConversationHistoryForAI(widget.botId!, limit: 20);
          print(
            '[ChatScreen] 🔥 Loaded ${conversationHistory.length} messages for AI context',
          );
        } catch (e) {
          print('[ChatScreen] ⚠️ Could not load Firebase history for AI: $e');
        }
      }

      final uri = Uri.parse('$_backendUrl/api/chat-enhanced');

      // Build enhanced payload with learner profile, mood, and conversation history
      final payload = {
        'message': userMessage,
        'botId': widget.botId,
        'userId': userId,
        'systemInstructions': _botInstructions,
        'learnerProfile': _learnerProfile?.toJson(),
        'currentMood': _currentMood?.toJson(),
        'conversationHistory': conversationHistory,
      };

      final payloadStr = jsonEncode(payload);
      final maxLen = payloadStr.length > 200 ? 200 : payloadStr.length;
      print('[ChatScreen] 📤 Payload: ${payloadStr.substring(0, maxLen)}');
      print(
        '[ChatScreen] 📋 Instructions present: ${_botInstructions != null}',
      );
      print('[ChatScreen] 👤 Learner profile: ${_learnerProfile != null}');
      print('[ChatScreen] 🎭 Current mood: ${_currentMood?.sentiment}');

      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(Duration(seconds: 30));

      final respPreview = resp.body.substring(
        0,
        resp.body.length > 200 ? 200 : resp.body.length,
      );
      print('[ChatScreen] 📬 Response status: ${resp.statusCode}');
      print('[ChatScreen] 📬 Response: $respPreview');

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        try {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          final botResponse = body['response'] ?? 'No response';
          final newState = body['state'] ?? _botCurrentState;
          final progress = body['progress'] as Map<String, dynamic>?;
          final instructionSource = body['instructionSource'] ?? 'unknown';
          final profileApplied = body['learnerProfileApplied'] ?? false;
          final moodApplied = body['moodApplied'] ?? false;
          final moduleCompleted = body['moduleCompleted'] ?? false;
          final conceptCompleted = body['conceptCompleted'] ?? false;
          final triggerQuiz = body['triggerQuiz'] ?? false;

          print('[ChatScreen] ✅ Backend processing info:');
          print('[ChatScreen]    - Instructions from: $instructionSource');
          print('[ChatScreen]    - Learner profile applied: $profileApplied');
          print('[ChatScreen]    - Mood applied: $moodApplied');
          print('[ChatScreen]    - Concept completed: $conceptCompleted');
          print('[ChatScreen]    - Module completed: $moduleCompleted');
          print('[ChatScreen]    - Trigger quiz: $triggerQuiz');

          // 🔥 RECORD STUDY ACTIVITY - Track this message as a study interaction
          try {
            final streakData = await _studyActivityService.recordStudyActivity(
              activityType: 'message',
              botId: widget.botId,
              metadata:
                  'Message: ${userMessage.substring(0, min(userMessage.length, 50))}',
            );

            print('[ChatScreen] 📊 Study activity recorded:');
            print('[ChatScreen]    - Streak: ${streakData.currentStreak}');
            print(
              '[ChatScreen]    - Incremented: ${streakData.streakIncremented}',
            );

            // Check if milestone should be notified
            if (streakData.streakIncremented) {
              final currentStreak = streakData.currentStreak;
              if (_studyActivityService.shouldNotifyMilestone(currentStreak)) {
                // Notify milestone
                await _studyNotificationService.notifyStreakMilestone(
                  currentStreak,
                );
              }
            }
          } catch (e) {
            print('[ChatScreen] ⚠️ Could not record study activity: $e');
          }

          setState(() {
            _botCurrentState = newState;
            if (progress != null) {
              _progressPercentage = (progress['percentage'] ?? 0).toDouble();
              print('[ChatScreen] 📊 Progress: $_progressPercentage%');
            }
            print('[ChatScreen] 📊 State updated: $_botCurrentState');
          });

          // Show celebration if module was completed
          if (moduleCompleted) {
            _showModuleCompletionCelebration(progress);
          }

          // Trigger quiz if backend signals it
          if (triggerQuiz) {
            _showQuizPopup();
          }

          // If backend returned a generated study plan, save it and show in hamburger AND chat
          if (body['showStudyPlan'] == true) {
            final planPayload = body['studyPlan'] ?? body['study_plan'];
            if (planPayload != null) {
              final plan = Map<String, dynamic>.from(planPayload);
              setState(() => _studyPlan = plan);
              print(
                '[ChatScreen] 📚 Study plan received and set: ${_studyPlan?['modules']?.length ?? 0} modules',
              );

              // Add study plan card to chat
              await _addStudyPlanToChat(plan);
            }
          }

          // Always reload study plan from backend to ensure hamburger menu is updated
          await _loadStudyPlan();

          await _addBotMessage(botResponse);
        } catch (parseErr) {
          print('[ChatScreen] ❌ Error parsing response JSON: $parseErr');
          await _addBotMessage(
            'Error: Could not parse backend response. Please try again.',
          );
        }
      } else if (resp.statusCode == 500) {
        print('[ChatScreen] ❌ ERROR 500 - Server error from backend');
        print('[ChatScreen] ❌ Response body: ${resp.body}');
        await _addBotMessage(
          'Backend error (500): The server encountered an error. Please check:\n1. Bot instructions are stored correctly\n2. API key is configured\n3. Bot ID is valid',
        );
      } else if (resp.statusCode == 404) {
        print('[ChatScreen] ❌ ERROR 404 - Bot or endpoint not found');
        await _addBotMessage(
          'Error 404: Bot not found. Please ensure the bot was created successfully.',
        );
      } else if (resp.statusCode == 400) {
        print('[ChatScreen] ❌ ERROR 400 - Bad request');
        await _addBotMessage(
          'Error 400: Invalid request format. Check all required fields are present.',
        );
      } else {
        print('[ChatScreen] ⚠️ Unexpected status code: ${resp.statusCode}');
        await _addBotMessage('Error: ${resp.statusCode}. ${resp.body}');
      }
    } catch (e) {
      print('[ChatScreen] ❌ Network/Connection Error: $e');
      await _addBotMessage(
        'Network error: $e\n\nPlease check your internet connection and try again.',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPhase1 && !_isPhase2) {
      return _buildPhase1ConfirmationScreen();
    } else if (_isPhase2 && _botState != null) {
      return _buildPhase2ChatScreen();
    } else {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDeep,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        ),
      );
    }
  }

  Widget _buildPhase1ConfirmationScreen() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.botName ?? 'Study Bot',
              style: AppTheme.headlineSmall.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.educationLevel ?? 'Self-Learner',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Study Bot Header Card
                Container(
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryBlue.withOpacity(0.15),
                        AppTheme.primaryBlue.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppTheme.primaryGradient,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.psychology,
                              color: Colors.black,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: AppTheme.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Study Bot is Ready',
                                  style: AppTheme.headlineSmall.copyWith(
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Phase 1: Setup Complete',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Study Bot Identity Section
                Text(
                  'Study Bot Identity',
                  style: AppTheme.headlineSmall.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: AppTheme.spaceMd),
                Container(
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    border: Border.all(
                      color: AppTheme.textSecondary.withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        label: 'Bot Name',
                        value: widget.botName ?? 'N/A',
                        icon: Icons.person,
                      ),
                      SizedBox(height: AppTheme.spaceMd),
                      _buildInfoRow(
                        label: 'Education Level',
                        value: widget.educationLevel ?? 'N/A',
                        icon: Icons.school,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Study Plan Information
                Text(
                  'Study Plan',
                  style: AppTheme.headlineSmall.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: AppTheme.spaceMd),
                Container(
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    border: Border.all(
                      color: AppTheme.textSecondary.withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Name',
                        style: AppTheme.labelSmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.planName ?? 'N/A',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: AppTheme.spaceMd),
                      Text(
                        'Description',
                        style: AppTheme.labelSmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.planDescription ?? 'N/A',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),

                // What's Next Section
                Container(
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.withOpacity(0.15),
                        Colors.green.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.green, size: 24),
                          SizedBox(width: AppTheme.spaceSm),
                          Text(
                            'What\'s Next?',
                            style: AppTheme.labelMedium.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppTheme.spaceMd),
                      Text(
                        'Phase 1 is complete! Your Study Bot has been created.\n\n'
                        'Click "Next" to enter Phase 2 where ${widget.botName} will guide you through an interactive learning experience.',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Transition to Phase 2
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => StudyPlanChatScreen(
                                botId: widget.botId,
                                planName: widget.planName,
                                planDescription: widget.planDescription,
                                botName: widget.botName,
                                educationLevel: widget.educationLevel,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          padding: EdgeInsets.symmetric(
                            vertical: AppTheme.spaceMd,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                          ),
                        ),
                        child: Text(
                          'What\'s Next?',
                          style: AppTheme.labelLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: AppTheme.spaceMd,
                          ),
                          side: BorderSide(
                            color: AppTheme.primaryBlue.withOpacity(0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                          ),
                        ),
                        child: Text(
                          'Create Another',
                          style: AppTheme.labelMedium.copyWith(
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spaceLg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhase2ChatScreen() {
    return GestureDetector(
      // Swipe from left to open hamburger menu
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          _scaffoldKey.currentState?.openDrawer();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppTheme.backgroundGradientStartFromContext(context),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: null,
          title: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [AppTheme.accentBlue, AppTheme.primaryBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.botName ?? 'Study Bot',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (_botCurrentState.isNotEmpty)
                  Text(
                    _botCurrentState == 'intro'
                        ? '✨ Ready to learn'
                        : _botCurrentState == 'plan_review'
                        ? '📋 Plan ready'
                        : '🎓 Learning mode',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            // Bookmark Icon - Study Plan Access
            if (_botCurrentState == 'learning' ||
                _botCurrentState == 'plan_review')
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.accentBlue.withOpacity(0.2),
                        AppTheme.primaryBlue.withOpacity(0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.bookmark,
                      color: AppTheme.primaryBlue,
                      size: 22,
                    ),
                    tooltip: 'View Study Plan',
                    onPressed: () {
                      print(
                        '[ChatScreen] 📖 Bookmark tapped - showing modules modal',
                      );
                      _showModulesModal();
                    },
                  ),
                ),
              ),
            // 3-Dot Menu
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: AppTheme.textSecondaryFromContext(context),
              ),
              color: AppTheme.surfaceCardFromContext(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.2)),
              ),
              onSelected: (value) {
                HapticFeedback.selectionClick();
                switch (value) {
                  case 'main_ai':
                    Navigator.pushNamed(context, '/online-ai');
                    break;
                  case 'bot_history':
                    Navigator.pushNamed(context, '/bot-history');
                    break;
                  case 'chat_history':
                    Navigator.pushNamed(context, '/chat-history');
                    break;
                  case 'change_mode':
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Mode switching coming soon!'),
                        backgroundColor: AppTheme.primaryBlue,
                      ),
                    );
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'main_ai',
                  child: Row(
                    children: [
                      Icon(
                        Icons.smart_toy,
                        color: AppTheme.primaryBlue,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Go to Main AI',
                        style: TextStyle(
                          color: AppTheme.textPrimaryFromContext(context),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'bot_history',
                  child: Row(
                    children: [
                      Icon(Icons.school, color: AppTheme.primaryBlue, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'My Study Bots',
                        style: TextStyle(
                          color: AppTheme.textPrimaryFromContext(context),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'chat_history',
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        color: AppTheme.primaryBlue,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Chat History',
                        style: TextStyle(
                          color: AppTheme.textPrimaryFromContext(context),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'change_mode',
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz, color: Colors.white54, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Change Mode',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        drawer: _buildDrawer(),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.backgroundGradientStartFromContext(context),
                AppTheme.backgroundGradientEndFromContext(
                  context,
                ).withOpacity(0.5),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Enhanced Progress Bar with Concept Tracking
                if (_botCurrentState == 'learning')
                  Container(
                    padding: EdgeInsets.all(AppTheme.spaceMd),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryBlue.withOpacity(0.08),
                          AppTheme.accentBlue.withOpacity(0.05),
                        ],
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.primaryBlue.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '🎯 Concepts Mastered',
                              style: AppTheme.bodySmall.copyWith(
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.accentBlue,
                                    AppTheme.primaryBlue,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_progressPercentage.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _progressPercentage / 100,
                            minHeight: 6,
                            backgroundColor: AppTheme.primaryBlue.withOpacity(
                              0.15,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '✨ Say "I understand" when you master a concept',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Table of Contents (if visible)
                if (_showToc && _botState?.tableOfContents != null)
                  _buildTableOfContentsWidget(),

                // Chat Messages with Premium Bubbles and Scroll-to-Bottom
                Expanded(
                  child: Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        itemCount: _messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Show typing indicator at the end when loading
                          if (_isLoading && index == _messages.length) {
                            return PremiumTypingIndicator(
                              botName: widget.botName,
                              showAvatar: true,
                            );
                          }

                          final msg = _messages[index];
                          final isBot = msg.senderType == 'bot';
                          final isLastMessage = index == _messages.length - 1;

                          return PremiumMessageBubble(
                            message: msg.text,
                            isBot: isBot,
                            timestamp: msg.timestamp,
                            botName: widget.botName,
                            showAvatar: isBot,
                            animate: isLastMessage,
                            onLongPress: () {
                              HapticFeedback.mediumImpact();
                            },
                          );
                        },
                      ),
                      // Scroll-to-bottom floating button
                      if (_showScrollToBottom)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: AnimatedOpacity(
                            opacity: _showScrollToBottom ? 1.0 : 0.0,
                            duration: Duration(milliseconds: 200),
                            child: GestureDetector(
                              onTap: _scrollToBottom,
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.accentBlue,
                                      AppTheme.primaryBlue,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentBlue.withOpacity(
                                        0.4,
                                      ),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Quick Action Chips (show contextual suggestions)
                if (!_isLoading && _messages.isNotEmpty)
                  _buildQuickActionChips(),

                // Premium Input Area
                _buildPremiumInputArea(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Quick Action Chips for common responses
  Widget _buildQuickActionChips() {
    final lastMessage = _messages.isNotEmpty ? _messages.last : null;
    final isBot = lastMessage?.senderType == 'bot';

    // Contextual suggestions based on conversation state
    List<String> suggestions = [];

    if (_botCurrentState == 'waiting_for_user' || _botCurrentState == 'intro') {
      suggestions = ['Yes, create my plan', 'Tell me more', 'What topics?'];
    } else if (_botCurrentState == 'in_study' ||
        _botCurrentState == 'learning') {
      suggestions = [
        'I understand',
        'Explain more',
        'Give an example',
        'Next topic',
      ];
    } else {
      suggestions = ['Continue', 'I understand', 'Tell me more'];
    }

    return Container(
      padding: EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: suggestions.map((text) {
            return Padding(
              padding: EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _addUserMessage(text);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryBlue.withOpacity(0.15),
                          AppTheme.accentBlue.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Premium Input Area with enhanced design
  Widget _buildPremiumInputArea() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.backgroundGradientEndFromContext(context).withOpacity(0.9),
            AppTheme.surfaceCardFromContext(context),
          ],
        ),
        border: Border(
          top: BorderSide(
            color: AppTheme.primaryBlue.withOpacity(0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Attachment button
            Builder(
              builder: (context) {
                final isDarkMode =
                    Theme.of(context).brightness == Brightness.dark;
                return Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.08)
                        : Color(0xFF1F2937).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.add,
                      color: isDarkMode ? Colors.white54 : Color(0xFF6B7280),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showAttachmentOptions();
                    },
                  ),
                );
              },
            ),
            SizedBox(width: 12),
            // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final isDarkMode =
                              Theme.of(context).brightness == Brightness.dark;
                          return TextField(
                            controller: _inputController,
                            enabled: !_isLoading,
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white
                                  : Color(0xFF000000),
                              fontSize: 15,
                            ),
                            maxLines: 4,
                            minLines: 1,
                            decoration: InputDecoration(
                              hintText: 'Message ${widget.botName ?? "AI"}...',
                              hintStyle: TextStyle(
                                color: isDarkMode
                                    ? Colors.white38
                                    : Color(0xFF9CA3AF),
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (text) {
                              if (text.isNotEmpty && !_isLoading) {
                                _addUserMessage(text);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12),
            // Send button with animation
            AnimatedContainer(
              duration: Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: _inputController.text.isNotEmpty || _isLoading
                    ? LinearGradient(
                        colors: [AppTheme.accentBlue, AppTheme.primaryBlue],
                      )
                    : null,
                color: _inputController.text.isEmpty && !_isLoading
                    ? Colors.white.withOpacity(0.1)
                    : null,
                shape: BoxShape.circle,
                boxShadow: _inputController.text.isNotEmpty
                    ? [
                        BoxShadow(
                          color: AppTheme.accentBlue.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Builder(
                builder: (context) {
                  final isDarkMode =
                      Theme.of(context).brightness == Brightness.dark;
                  return IconButton(
                    icon: _isLoading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(
                                isDarkMode ? Colors.white : Color(0xFF000000),
                              ),
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            Icons.arrow_upward,
                            color: isDarkMode
                                ? Colors.white
                                : Color(0xFF6B7280),
                            size: 22,
                          ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (_inputController.text.isNotEmpty) {
                              HapticFeedback.mediumImpact();
                              _addUserMessage(_inputController.text);
                            }
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.surfaceCardFromContext(context),
              AppTheme.backgroundGradientEndFromContext(context),
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentOption(
                    icon: Icons.quiz,
                    label: 'Take Quiz',
                    onTap: () {
                      Navigator.pop(context);
                      _showQuizPopup();
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.note_add,
                    label: 'Save Note',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.mic,
                    label: 'Voice',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue.withOpacity(0.2),
                  AppTheme.accentBlue.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 28),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondaryFromContext(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Legacy Input Area (kept for reference)
  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.backgroundGradientEndFromContext(context).withOpacity(0.8),
            AppTheme.surfaceCardFromContext(context),
          ],
        ),
        border: Border(
          top: BorderSide(
            color: AppTheme.primaryBlue.withOpacity(0.2),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.surfaceCardFromContext(context).withOpacity(0.6),
                    AppTheme.backgroundGradientEndFromContext(
                      context,
                    ).withOpacity(0.4),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _inputController,
                enabled: !_isLoading,
                style: TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Ask me anything...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (text) {
                  if (text.isNotEmpty && !_isLoading) {
                    _addUserMessage(text);
                  }
                },
              ),
            ),
          ),
          SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.accentBlue, AppTheme.primaryBlue],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentBlue.withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IconButton(
              icon: _isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(Icons.send, color: Colors.white),
              onPressed: _isLoading
                  ? null
                  : () {
                      if (_inputController.text.isNotEmpty) {
                        _addUserMessage(_inputController.text);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableOfContentsWidget() {
    final toc = _botState?.tableOfContents ?? [];
    if (toc.isEmpty) return SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        border: Border(bottom: BorderSide(color: AppTheme.surfaceElevated)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: toc.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: AppTheme.surfaceElevated),
        itemBuilder: (context, index) {
          final module = toc[index];
          return Padding(
            padding: EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${module.moduleNumber}',
                          style: AppTheme.labelMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            module.title,
                            style: AppTheme.labelLarge.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            module.difficultyLevel,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 20),
        SizedBox(width: AppTheme.spaceSm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTheme.labelSmall.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              value,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Convert backend study plan to TableOfContentsItem list
  List<TableOfContentsItem> _convertStudyPlanToToc() {
    if (_studyPlan == null) return [];

    final modules = _studyPlan!['modules'] as List? ?? [];
    return modules.asMap().entries.map((entry) {
      final idx = entry.key;
      final mod = entry.value as Map<String, dynamic>;

      return TableOfContentsItem(
        moduleNumber: idx + 1,
        title: mod['title'] ?? mod['module_name'] ?? 'Module ${idx + 1}',
        description: mod['objective'] ?? mod['description'] ?? '',
        subtopics: List<String>.from(
          mod['key_topics'] ??
              mod['subtopics'] ??
              mod['learning_objectives'] ??
              [],
        ),
        estimatedTime:
            mod['estimated_effort'] ?? mod['duration'] ?? '30 minutes',
        difficultyLevel: mod['difficulty'] ?? 'Medium',
      );
    }).toList();
  }

  /// Build drawer menu with navigation options
  Widget _buildDrawer() {
    // Debug: Log study plan state
    print(
      '[ChatScreen] 🍔 Building drawer - _studyPlan: ${_studyPlan != null ? "EXISTS with ${(_studyPlan!['modules'] as List?)?.length ?? 0} modules" : "NULL"}',
    );

    // Use converted study plan or fallback to botState tableOfContents
    final tocItems = _studyPlan != null
        ? _convertStudyPlanToToc()
        : _botState?.tableOfContents ?? [];

    print('[ChatScreen] 🍔 tocItems count: ${tocItems.length}');

    return PremiumStudyPlanMenu(
      key: ValueKey(
        'study_plan_${_planVersion}_${_studyPlan?.hashCode ?? 0}',
      ), // Force rebuild when study plan changes
      tableOfContents: tocItems.isNotEmpty ? tocItems : null,
      currentModule: _botState?.currentModule ?? 0,
      completedModules: _botState?.completedModules,
      progressPercentage: _progressPercentage,
      planVersion: _planVersion,
      planTitle: _studyPlan?['title'] as String?,
      context: context, // Pass context for theme access
      onModuleEdit: (moduleIndex, moduleName) {
        print('[ChatScreen] Edit module $moduleIndex: $moduleName');
        _openPlanEditor();
      },
      onModuleTap: (moduleIndex) {
        print('[ChatScreen] Module $moduleIndex tapped');
        Navigator.pop(context);
        _sendMessageToBackend('Let\'s focus on module ${moduleIndex + 1}');
      },
      onEditPlan: () {
        print('[ChatScreen] Edit plan button pressed');
        _openPlanEditor();
      },
      onClose: () {
        print('[ChatScreen] Hamburger menu closed');
      },
    );
  }

  /// Show about dialog with bot information
  @pragma('vm:entry-point')
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.backgroundDeep,
          title: Text(
            widget.botName ?? 'Study Bot',
            style: AppTheme.headlineSmall.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plan: ${widget.planName ?? 'N/A'}',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: AppTheme.spaceSm),
              Text(
                'Level: ${widget.educationLevel ?? 'Self-Learner'}',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              SizedBox(height: AppTheme.spaceMd),
              Text(
                widget.planDescription ?? 'No description available',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show modules/plan editor modal
  void _showModulesModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(height: AppTheme.spaceMd),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '📚 Your Learning Plan',
                          style: AppTheme.headlineSmall.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_studyPlan != null)
                          IconButton(
                            icon: Icon(Icons.edit, color: AppTheme.primaryBlue),
                            tooltip: 'Edit Plan',
                            onPressed: () => _openPlanEditor(),
                          ),
                      ],
                    ),
                    SizedBox(height: AppTheme.spaceSm),
                    Text(
                      'Tap any module to see details and concepts',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: AppTheme.spaceLg),

                    // Modules List
                    if (_botCurrentState == 'learning' &&
                        widget.planName != null)
                      Text(
                        '✨ ${widget.planName}',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                    SizedBox(height: AppTheme.spaceSm),
                    Text(
                      'Your personalized study plan has been created. As you learn each concept, your progress will update here automatically.',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),

                    SizedBox(height: AppTheme.spaceLg),

                    // Modules List - MAIN CONTENT
                    if (_studyPlan != null &&
                        (_studyPlan!['modules'] as List?)?.isNotEmpty == true)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📚 Modules',
                            style: AppTheme.headlineSmall.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: AppTheme.spaceMd),
                          ...((_studyPlan!['modules'] as List? ?? []).asMap().entries.map((
                            entry,
                          ) {
                            final index = entry.key;
                            final module = entry.value as Map<String, dynamic>;
                            final isCompleted =
                                (_botState?.completedModules ?? []).contains(
                                  index,
                                );
                            final isCurrent =
                                _botCurrentState == 'learning' &&
                                _botState?.currentModule == index;

                            return Container(
                              margin: EdgeInsets.only(bottom: AppTheme.spaceMd),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceCard,
                                border: Border.all(
                                  color: isCurrent
                                      ? AppTheme.primaryBlue
                                      : AppTheme.primaryBlue.withOpacity(0.2),
                                  width: isCurrent ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd,
                                ),
                              ),
                              child: ExpansionTile(
                                title: Row(
                                  children: [
                                    if (isCompleted)
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 20,
                                      )
                                    else if (isCurrent)
                                      Icon(
                                        Icons.play_circle,
                                        color: AppTheme.primaryBlue,
                                        size: 20,
                                      )
                                    else
                                      Icon(
                                        Icons.radio_button_unchecked,
                                        color: AppTheme.textSecondary,
                                        size: 20,
                                      ),
                                    SizedBox(width: AppTheme.spaceSm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Module ${index + 1}: ${module['title'] ?? 'Untitled'}',
                                            style: AppTheme.bodyMedium.copyWith(
                                              color: AppTheme.textPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            module['duration'] ?? 'N/A',
                                            style: AppTheme.bodySmall.copyWith(
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(AppTheme.spaceMd),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Description',
                                          style: AppTheme.bodyMedium.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        SizedBox(height: AppTheme.spaceSm),
                                        Text(
                                          module['description'] ??
                                              'No description',
                                          style: AppTheme.bodySmall.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        SizedBox(height: AppTheme.spaceMd),
                                        Text(
                                          'Learning Objectives',
                                          style: AppTheme.bodyMedium.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        SizedBox(height: AppTheme.spaceSm),
                                        ...((module['objectives'] as List? ??
                                                [])
                                            .map(
                                              (obj) => Padding(
                                                padding: EdgeInsets.only(
                                                  bottom: AppTheme.spaceSm,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '• ',
                                                      style: AppTheme.bodySmall
                                                          .copyWith(
                                                            color: AppTheme
                                                                .textSecondary,
                                                          ),
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        obj as String? ?? '',
                                                        style: AppTheme
                                                            .bodySmall
                                                            .copyWith(
                                                              color: AppTheme
                                                                  .textSecondary,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                            .toList()),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList()),
                          SizedBox(height: AppTheme.spaceLg),
                        ],
                      )
                    else
                      Padding(
                        padding: EdgeInsets.all(AppTheme.spaceMd),
                        child: Text(
                          'No modules available yet. Create a study plan to get started!',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),

                    SizedBox(height: AppTheme.spaceLg),

                    // Progress summary
                    Container(
                      padding: EdgeInsets.all(AppTheme.spaceMd),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryBlue.withOpacity(0.1),
                            AppTheme.primaryBlue.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🎯 Learning Progress',
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: AppTheme.spaceSm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Concepts Mastered',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                '${_progressPercentage.toStringAsFixed(0)}%',
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _progressPercentage / 100,
                              minHeight: 6,
                              backgroundColor: AppTheme.primaryBlue.withOpacity(
                                0.2,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: AppTheme.spaceLg),

                    // Tips
                    Container(
                      padding: EdgeInsets.all(AppTheme.spaceMd),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.primaryBlue.withOpacity(0.2),
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '💡 Pro Tips',
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: AppTheme.spaceSm),
                          Text(
                            '• When you understand a concept, tell me "I understand" or "that makes sense"\n• I\'ll track your progress automatically\n• Take your time - quality over speed\n• Ask questions anytime!',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: AppTheme.spaceLg),

                    // Close button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          padding: EdgeInsets.symmetric(
                            vertical: AppTheme.spaceMd,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                          ),
                        ),
                        child: Text(
                          'Back to Learning',
                          style: AppTheme.labelMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: AppTheme.spaceMd),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openPlanEditor() async {
    // Try to load plan if not available
    if (_studyPlan == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loading study plan...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 1),
          ),
        );
      }

      final loaded = await _loadStudyPlan();
      if (!loaded || _studyPlan == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No study plan available yet. Ask your tutor to create one!',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final userId = currentUser?.uid ?? 'anonymous';

    // Close any open modal/drawer first
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudyPlanEditorScreen(
          studyPlan: _studyPlan!,
          onSave: (updatedPlan) async {
            await _savePlanChanges(updatedPlan, userId);
          },
        ),
      ),
    );

    // Reload plan after editor closes to sync any changes
    if (result != null || mounted) {
      await _loadStudyPlan();
    }
  }

  Future<void> _savePlanChanges(
    Map<String, dynamic> updatedPlan,
    String userId, {
    bool apply = true,
  }) async {
    // Store backup of current plan in case save fails
    final backupPlan = _studyPlan != null
        ? Map<String, dynamic>.from(_studyPlan!)
        : null;
    final backupVersion = _planVersion;

    try {
      // Validate plan structure before saving
      if (updatedPlan['modules'] == null ||
          !(updatedPlan['modules'] is List) ||
          (updatedPlan['modules'] as List).isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Invalid plan: Must have at least one module'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Validate each module has a title
      for (int i = 0; i < (updatedPlan['modules'] as List).length; i++) {
        final mod = updatedPlan['modules'][i] as Map<String, dynamic>;
        if ((mod['title'] == null || mod['title'].toString().isEmpty) &&
            (mod['module_name'] == null ||
                mod['module_name'].toString().isEmpty)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ Module ${i + 1} must have a title'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      // Optimistically update local state
      setState(() => _studyPlan = updatedPlan);

      // Send to backend - apply immediately to make plan active
      final uri = Uri.parse('$_backendUrl/api/apply-study-plan');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'botId': widget.botId,
              'userId': userId,
              'studyPlan': updatedPlan,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final newVersion = body['plan_version'] as int? ?? (_planVersion + 1);

        setState(() {
          _planVersion = newVersion;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Study plan saved (v$newVersion)! AI will adapt to your changes.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
        print('[ChatScreen] Plan applied successfully, version: $newVersion');

        // Notify AI about plan update
        await _addBotMessage(
          "Got it — I've updated our study route. We'll continue with the revised plan.",
        );
      } else if (response.statusCode == 400 || response.statusCode == 404) {
        // Fallback to update endpoint if apply not available
        final fallbackUri = Uri.parse('$_backendUrl/api/update-study-plan');
        final fallbackResp = await http
            .post(
              fallbackUri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'botId': widget.botId,
                'userId': userId,
                'updatedPlan': updatedPlan,
                'apply': apply,
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (fallbackResp.statusCode == 200) {
          final body = jsonDecode(fallbackResp.body);
          final newVersion = body['plan_version'] as int? ?? (_planVersion + 1);

          setState(() {
            _planVersion = newVersion;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Study plan updated (v$newVersion)'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Server error: ${fallbackResp.statusCode}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('[ChatScreen] Error saving plan: $e');

      // Restore backup on failure - don't lose local edits
      if (backupPlan != null) {
        setState(() {
          _studyPlan = backupPlan;
          _planVersion = backupVersion;
        });
      }

      if (mounted) {
        // Show retry option
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Failed to save plan. Your changes are preserved locally.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: () {
                _savePlanChanges(updatedPlan, userId, apply: apply);
              },
            ),
          ),
        );
      }
    }
  }

  Future<bool> _loadStudyPlan() async {
    if (widget.botId == null) return false;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final userId = currentUser?.uid ?? 'anonymous';

      final uri = Uri.parse(
        '$_backendUrl/api/bot-progress/${widget.botId}/$userId',
      );
      print('[ChatScreen] 📡 Loading study plan from: $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      print('[ChatScreen] 📡 Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final loadedPlan = body['study_plan'] as Map<String, dynamic>?;
        final modules = loadedPlan?['modules'] as List?;

        print('[ChatScreen] 📡 study_plan in response: ${loadedPlan != null}');
        print('[ChatScreen] 📡 modules count: ${modules?.length ?? 0}');

        setState(() {
          _studyPlan = loadedPlan;
          _planVersion = body['plan_version'] as int? ?? 1;
          _progressPercentage =
              (body['progress']?['percentage'] as num?)?.toDouble() ?? 0.0;
          _botCurrentState = body['bot_state'] as String? ?? 'intro';
        });
        print(
          '[ChatScreen] ✅ Loaded study plan v$_planVersion with ${modules?.length ?? 0} modules',
        );
        return true;
      } else if (response.statusCode == 404) {
        // No progress record yet - this is okay for new bots
        print('[ChatScreen] No study plan found (404) - new bot');
        return false;
      } else {
        print('[ChatScreen] Failed to load study plan: ${response.statusCode}');
        print('[ChatScreen] Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('[ChatScreen] Error loading study plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load study plan. Check your connection.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: () => _loadStudyPlan(),
            ),
          ),
        );
      }
      return false;
    }
  }

  /// Show celebration dialog when a module is completed
  void _showModuleCompletionCelebration(Map<String, dynamic>? progress) {
    final percentage = progress?['percentage'] ?? 0;
    final currentModule = (progress?['currentModule'] ?? 0) + 1;
    final completedCount = progress?['completedModules'] ?? 1;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.surfaceCardFromContext(context),
                  AppTheme.backgroundGradientEndFromContext(context),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.primaryBlue.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentBlue.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Celebration icon with glow
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppTheme.accentBlue, AppTheme.primaryBlue],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentBlue.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text('🎉', style: TextStyle(fontSize: 40)),
                  ),
                ),
                SizedBox(height: 20),

                // Title
                Text(
                  'Module Complete!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),

                // Subtitle
                Text(
                  'Great job! You\'ve mastered this module.',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),

                // Progress indicator
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Overall Progress',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '$percentage%',
                            style: TextStyle(
                              color: AppTheme.primaryBlue,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      // Premium progress bar
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: percentage / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.accentBlue,
                                  AppTheme.primaryBlue,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryBlue.withOpacity(0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '$completedCount modules completed',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Reload study plan to get updated progress
                      _loadStudyPlan();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Continue to Next Module →',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Validate quiz data structure
  bool _isValidQuizData(Map<String, dynamic> quiz) {
    try {
      final questions = quiz['questions'] as List<dynamic>? ?? [];
      final answers = quiz['answers'] as List<dynamic>? ?? [];

      if (questions.isEmpty) {
        print('[ChatScreen] Invalid quiz: no questions');
        return false;
      }

      if (answers.isEmpty) {
        print('[ChatScreen] Invalid quiz: no answers');
        return false;
      }

      // Validate each question has required fields
      for (int i = 0; i < questions.length; i++) {
        final q = questions[i];
        if (q is! Map<String, dynamic>) {
          print('[ChatScreen] Question $i is not a valid map');
          return false;
        }

        // Check for either 'question' or 'text' field
        final questionText = q['question'] as String? ?? q['text'] as String?;
        if (questionText == null || questionText.isEmpty) {
          print('[ChatScreen] Question $i missing text');
          return false;
        }
      }

      // Validate answers have required fields
      for (int i = 0; i < answers.length; i++) {
        final a = answers[i];
        if (a is! Map<String, dynamic>) {
          print('[ChatScreen] Answer $i is not a valid map');
          return false;
        }

        final answer = a['answer'] as String? ?? '';
        if (answer.isEmpty) {
          print('[ChatScreen] Answer $i missing answer text');
          return false;
        }
      }

      return true;
    } catch (e) {
      print('[ChatScreen] Quiz validation error: $e');
      return false;
    }
  }

  /// Show quiz popup asking if user wants to take quiz now or later
  void _showQuizPopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDarkMode
              ? AppTheme.backgroundDeep
              : Color(0xFFFAFAFA),
          title: Text(
            '📝 Ready for a Quiz?',
            style: AppTheme.headlineSmall.copyWith(
              color: isDarkMode ? AppTheme.textPrimary : Color(0xFF1F2937),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Do you want to take a quiz now to test your knowledge, or would you prefer to do it later?',
            style: AppTheme.bodyMedium.copyWith(
              color: isDarkMode ? AppTheme.textSecondary : Color(0xFF6B7280),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _sendMessageToBackend('Later');
              },
              child: Text(
                'Later',
                style: AppTheme.bodyMedium.copyWith(
                  color: isDarkMode
                      ? AppTheme.textSecondary
                      : Color(0xFF6B7280),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showQuizConfiguration();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
              ),
              child: Text(
                'Now',
                style: AppTheme.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show quiz configuration screen
  void _showQuizConfiguration() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return QuizConfigScreen(
          moduleName: 'Module Quiz',
          onStartQuiz: (config) async {
            await _generateQuiz(config);
          },
        );
      },
    );
  }

  /// Generate quiz by calling backend endpoint
  Future<void> _generateQuiz(Map<String, dynamic> config) async {
    try {
      print('[ChatScreen] Starting quiz generation with config: $config');

      setState(() => _isLoading = true);

      final currentUser = FirebaseAuth.instance.currentUser;
      final userId = currentUser?.uid ?? 'anonymous';

      final uri = Uri.parse('$_backendUrl/api/generate-quiz');
      final moduleContext = _getModuleContext();
      print('[ChatScreen] Module context length: ${moduleContext.length}');
      if (moduleContext.isNotEmpty) {
        print(
          '[ChatScreen] Module context preview: ${moduleContext.substring(0, min(moduleContext.length, 100))}',
        );
      }

      final payload = {
        'botId': widget.botId,
        'userId': userId,
        'moduleName':
            'Module ${((_botState?.chatHistory?.length) ?? 0) ~/ 5 + 1}',
        'moduleContent': moduleContext,
        'questionType': config['questionType'] ?? 'both',
        'mcqCount': config['mcqCount'] ?? 5,
        'textCount': config['textCount'] ?? 3,
        'useWebSearch': config['useWebSearch'] ?? true,
        'gradeLevel': widget.educationLevel ?? 'General',
        'topic': widget.planName ?? 'General',
      };

      print('[ChatScreen] Calling quiz generation endpoint');
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(
            Duration(seconds: 45),
            onTimeout: () {
              throw TimeoutException(
                'Quiz generation took too long. Please try again.',
              );
            },
          );

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final quiz = body['quiz'] as Map<String, dynamic>?;
        final quizId = body['quizId'] as int?;

        print('[ChatScreen] Quiz generated successfully');
        print('[ChatScreen] Quiz data: ${quiz?.keys.toList()}');
        print(
          '[ChatScreen] Quiz questions count: ${(quiz?['questions'] as List?)?.length ?? 0}',
        );
        print(
          '[ChatScreen] Quiz answers count: ${(quiz?['answers'] as List?)?.length ?? 0}',
        );

        if (quiz != null && quiz.isNotEmpty && _isValidQuizData(quiz)) {
          // Store quiz ID for explanation callbacks
          _currentQuizId = quizId;
          print('[ChatScreen] Showing quiz artifact with ID: $quizId');
          // Show quiz artifact
          if (mounted) {
            _showQuizArtifact(quiz);
          }
        } else {
          print('[ChatScreen] Quiz is invalid: $quiz');
          if (mounted) {
            _addBotMessage(
              '📝 Quiz generation completed, but the quiz structure seems invalid. Let me regenerate it for you.',
            );
          }
        }
      } else if (resp.statusCode == 408 || resp.statusCode == 504) {
        print('[ChatScreen] Quiz generation timeout: ${resp.statusCode}');
        if (mounted) {
          _addBotMessage(
            '⏱️ The quiz generation is taking longer than expected. Please try again in a moment, and I\'ll create a personalized quiz based on our conversation.',
          );
        }
      } else if (resp.statusCode == 400) {
        print('[ChatScreen] Invalid quiz request: ${resp.body}');
        if (mounted) {
          _addBotMessage(
            '❌ I couldn\'t generate the quiz with those parameters. Let me try with different settings.',
          );
        }
      } else if (resp.statusCode >= 500) {
        print('[ChatScreen] Backend error: ${resp.statusCode} - ${resp.body}');
        if (mounted) {
          _addBotMessage(
            '🔧 Our quiz generator is having trouble right now. Please try again in a few moments!',
          );
        }
      } else {
        print(
          '[ChatScreen] Unexpected error: ${resp.statusCode} - ${resp.body}',
        );
        if (mounted) {
          _addBotMessage(
            '❓ Something unexpected happened while generating the quiz. Want to try again?',
          );
        }
      }
    } on TimeoutException catch (e) {
      print('[ChatScreen] Timeout: $e');
      if (mounted) {
        _addBotMessage(
          '⏱️ The quiz generation took too long. Please try again with fewer questions or simpler content.',
        );
      }
    } catch (e) {
      print('[ChatScreen] Error: $e');
      if (mounted) {
        _addBotMessage(
          '⚠️ I had trouble generating the quiz. Please check your internet connection and try again.',
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Show quiz artifact dialog
  void _showQuizArtifact(Map<String, dynamic> quiz) {
    // Track quiz start
    _analyticsService.trackQuizStart(quiz);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(AppTheme.spaceMd),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              children: [
                Expanded(
                  child: QuizArtifactWidget(
                    quizData: quiz,
                    onExplainAnswer: _handleExplainAnswer,
                  ),
                ),
                SizedBox(height: AppTheme.spaceMd),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();

                    // Track quiz completion
                    await _analyticsService.trackQuizCompletion(quiz);
                    await _recordMilestone('Quiz completed', 'quiz_completion');

                    _sendMessageToBackend('I\'ve completed the quiz review.');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceLg,
                      vertical: AppTheme.spaceMd,
                    ),
                  ),
                  child: Text(
                    'Close Quiz',
                    style: AppTheme.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Extract module context for quiz generation
  String _getModuleContext() {
    // Extract last few messages as module context
    final recentMessages = _messages
        .where((m) => m.senderType == 'bot')
        .toList()
        .asMap()
        .entries
        .where(
          (e) => e.key >= (_messages.length - 10).clamp(0, _messages.length),
        )
        .map((e) => e.value.text)
        .join('\n\n');

    return recentMessages.isNotEmpty
        ? recentMessages
        : 'Use the topic: ${widget.planName} at ${widget.educationLevel} level';
  }

  /// Handle student requesting a deeper explanation for a quiz answer
  Future<String?> _handleExplainAnswer(
    int questionIndex,
    String questionText,
    String answerText,
    String currentExplanation,
  ) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Getting a simpler explanation...'),
            duration: Duration(seconds: 1),
            backgroundColor: AppTheme.primaryBlue,
          ),
        );
      }

      // Get the quiz ID from quiz_data table
      final quizResult = await http.post(
        Uri.parse('$_backendUrl/api/explain-answer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'botId': widget.botId,
          'userId': (FirebaseAuth.instance.currentUser?.uid ?? 'anonymous'),
          'quizId': _currentQuizId ?? 0,
          'questionIndex': questionIndex,
          'questionText': questionText,
          'answerText': answerText,
          'currentExplanation': currentExplanation,
        }),
      );

      if (quizResult.statusCode == 200) {
        final responseData = jsonDecode(quizResult.body);
        final newExplanation = responseData['explanation'] as String? ?? '';

        if (newExplanation.isNotEmpty) {
          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Explanation updated!'),
                duration: Duration(seconds: 1),
                backgroundColor: AppTheme.success,
              ),
            );
          }
          return newExplanation;
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to get explanation'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      print('[_handleExplainAnswer] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting explanation'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
    return null;
  }

  /// Apply mood-aware adaptation to bot responses
  String _applyMoodAdaptation(String response) {
    if (_currentMood == null) return response;

    switch (_currentMood!.sentiment) {
      case 'frustrated':
        // Add supportive message and simplification
        return '${_tutorService.getSupportMessage()}\n\n$response';

      case 'confused':
        // Add check-in with encouragement
        return '$response\n\n${_tutorService.getCheckInMessage()}';

      case 'positive':
        // Add affirmation and advance
        return '${_tutorService.getAffirmationMessage()} $response\n\n${_tutorService.getTransitionMessage()}';

      default:
        return response;
    }
  }

  /// Record milestone and update progress
  Future<void> _recordMilestone(
    String description,
    String type, {
    double? progressIncrement,
  }) async {
    if (_botState == null) return;

    try {
      final updatedProgress = await _progressService.addMilestone(
        _botState!.sessionId,
        description,
        type,
        progressIncrement: progressIncrement,
      );

      setState(() {
        _progressPercentage = (updatedProgress.overallProgress * 100).clamp(
          0,
          100,
        );
      });

      // Award XP for learning milestones
      int xpAmount = 10; // Base XP
      if (type == 'concept_mastery') xpAmount = 25;
      if (type == 'quiz_completion') xpAmount = 50;
      if (type == 'module_completion') xpAmount = 100;

      await _gamificationService.awardXP(xpAmount, reason: description);

      // Track analytics
      await _analyticsService.trackConceptLearned(
        description,
        'Module ${_botState?.currentModule ?? 1}',
        300, // Assume 5 minutes spent
      );

      // Automatically mark modules as completed based on milestones
      await _updateModuleCompletion(type, description);

      print(
        '[ChatScreen] Milestone recorded: $description, Progress: ${_progressPercentage.toStringAsFixed(1)}%, XP: +$xpAmount',
      );
    } catch (e) {
      print('[ChatScreen] Error recording milestone: $e');
    }
  }

  /// Automatically update module completion based on milestones
  Future<void> _updateModuleCompletion(
    String milestoneType,
    String description,
  ) async {
    if (_botState == null || _studyPlan == null) return;

    final modules = _studyPlan!['modules'] as List?;
    if (modules == null || modules.isEmpty) return;

    final currentModuleIndex = _botState!.currentModule;
    final completedModules = List<int>.from(_botState!.completedModules ?? []);

    bool shouldMarkComplete = false;

    // Logic to determine when a module should be marked complete
    switch (milestoneType) {
      case 'module_completion':
        shouldMarkComplete = true;
        break;
      case 'concept_mastery':
        // Mark complete if user has demonstrated understanding multiple times
        // or if this is a significant milestone
        if (description.toLowerCase().contains('mastered') ||
            description.toLowerCase().contains('completed') ||
            description.toLowerCase().contains('understood')) {
          shouldMarkComplete = true;
        }
        break;
      case 'quiz_completion':
        // Quiz completion often indicates module mastery
        shouldMarkComplete = true;
        break;
    }

    if (shouldMarkComplete && !completedModules.contains(currentModuleIndex)) {
      completedModules.add(currentModuleIndex);

      // Update bot state with completed modules
      final updatedState = _botState!.copyWith(
        completedModules: completedModules,
        currentModule: currentModuleIndex + 1, // Move to next module
      );

      // Save updated state to backend
      try {
        await _planService.saveBotState(updatedState);
        setState(() {
          _botState = updatedState;
        });

        print(
          '[ChatScreen] Module $currentModuleIndex marked as completed. Moving to module ${currentModuleIndex + 1}',
        );

        // Reload study plan to update hamburger menu
        await _loadStudyPlan();
      } catch (e) {
        print('[ChatScreen] Error updating module completion: $e');
      }
    }
  }

  /// Handle user validation of understanding
  @pragma('vm:entry-point')
  Future<void> _handleUnderstandingValidation() async {
    if (_botState == null) return;

    // Record concept mastery
    await _recordMilestone(
      'User confirmed understanding',
      'concept_mastery',
      progressIncrement: 0.05,
    );

    // Trigger active recall question
    _triggerActiveRecall();
  }

  /// Trigger active recall quiz question
  void _triggerActiveRecall() {
    if (_messages.isEmpty) return;

    // Get the last bot message as context
    final lastBotMessage = _messages.lastWhere(
      (m) => m.senderType == 'bot',
      orElse: () => _messages.first,
    );

    // Generate recall question based on previous content
    final recallQuestion = _tutorService.generateActiveRecallQuestion(
      lastBotMessage.text,
      _botState?.currentModule ?? 1,
    );

    print('[ChatScreen] Active recall triggered: $recallQuestion');

    // Add as a bot message with special formatting
    _addBotMessage(recallQuestion);
  }

  /// Check if user's message indicates understanding
  bool _indicatesUnderstanding(String message) {
    final lowerMessage = message.toLowerCase();
    return lowerMessage.contains('got it') ||
        lowerMessage.contains('understand') ||
        lowerMessage.contains('makes sense') ||
        lowerMessage.contains('clear') ||
        lowerMessage.contains('i get it') ||
        lowerMessage.contains('yes') ||
        lowerMessage.contains('👍');
  }

  /// Check if user's message indicates confusion
  bool _indicatesConfusion(String message) {
    final lowerMessage = message.toLowerCase();
    return lowerMessage.contains('confused') ||
        lowerMessage.contains('not sure') ||
        lowerMessage.contains('explain') ||
        lowerMessage.contains('again') ||
        lowerMessage.contains('huh') ||
        lowerMessage.contains('what');
  }
}
