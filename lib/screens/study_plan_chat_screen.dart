import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/study_bot_state.dart';
import '../services/study_plan_service.dart';
import '../services/study_bot_flow_controller.dart';
import '../services/tutor_engagement_service.dart';
import '../services/progress_tracking_service.dart';
import '../utils/theme.dart';
import 'study_plan_editor_screen.dart';
import 'quiz_config_screen.dart';
import '../widgets/quiz_artifact_widget.dart';
import '../widgets/study_plan_hamburger_menu.dart';
import '../widgets/professional_message_widget.dart';

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

  bool _isPhase1 = false;
  bool _isPhase2 = false;

  // Phase 2 state
  StudyBotState? _botState;
  List<StudyBotMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  bool _isLoading = false;
  bool _showToc = false;

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

  void initState() {
    super.initState();
    _planService = StudyPlanService();
    _flowController = StudyBotFlowController();
    _tutorService = TutorEngagementService();
    _progressService = ProgressTrackingService();

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

      // If resuming a bot, load chat history and progress from backend
      if (widget.botId != null) {
        final currentUser = FirebaseAuth.instance.currentUser;
        final userId = currentUser?.uid ?? 'anonymous';

        // Fetch chat history
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
              '[ChatScreen] Loaded ${messages.length} messages from backend',
            );
          }
        } catch (e) {
          print('[ChatScreen] Error loading chat history: $e');
        }

        // Fetch bot progress and state
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
                  (body['progress'] as num?)?.toDouble() ?? 0.0;
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

      // Always create fresh session - no state caching
      // This ensures we always fetch fresh greeting from backend AI
      _botState = _flowController.createNewSession(botId: widget.botId!);
      _messages = [];

      // Fetch fresh system instructions from backend FIRST
      // This ensures instructions are available when greeting is fetched
      if (widget.botId != null) {
        await _fetchFreshSystemInstructions(widget.botId!);
      }

      // Always fetch initial greeting from backend - ALL responses come from AI
      // The backend will use system instructions to generate personalized greeting
      await _fetchInitialGreeting();

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

      if (_botState != null) {
        _botState = _botState!.copyWith(
          chatHistory: _messages.map((m) => m.toJson()).toList(),
        );
        await _planService.saveBotState(_botState!);
      }
    }
  }

  Future<void> _addUserMessage(String text) async {
    final message = StudyBotMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderType: 'user',
      text: text,
      timestamp: DateTime.now(),
    );

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

      final uri = Uri.parse('$_backendUrl/api/chat-enhanced');

      // Build enhanced payload with learner profile and mood
      final payload = {
        'message': userMessage,
        'botId': widget.botId,
        'userId': userId,
        'systemInstructions': _botInstructions,
        'learnerProfile': _learnerProfile?.toJson(),
        'currentMood': _currentMood?.toJson(),
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

          print('[ChatScreen] ✅ Backend processing info:');
          print('[ChatScreen]    - Instructions from: $instructionSource');
          print('[ChatScreen]    - Learner profile applied: $profileApplied');
          print('[ChatScreen]    - Mood applied: $moodApplied');

          setState(() {
            _botCurrentState = newState;
            if (progress != null) {
              _progressPercentage = (progress['percentage'] ?? 0).toDouble();
            }
            print('[ChatScreen] 📊 State updated: $_botCurrentState');
          });

          // If backend returned a generated study plan, open editor for review
          if (body['showStudyPlan'] == true) {
            final planPayload = body['studyPlan'] ?? body['study_plan'];
            if (planPayload != null) {
              setState(
                () => _studyPlan = Map<String, dynamic>.from(planPayload),
              );

              // Navigate to editor so user can review and save/apply
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StudyPlanEditorScreen(
                    studyPlan: _studyPlan!,
                    onSave: (updatedPlan) async {
                      await _savePlanChanges(updatedPlan, userId, apply: true);
                    },
                  ),
                ),
              );

              if (result != null) {
                await _loadStudyPlan();
              }
            }
          }

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
    return Scaffold(
      backgroundColor: PremiumColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: null,
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              PremiumColors.accentGradient2,
              PremiumColors.accentGradient1,
            ],
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
              padding: EdgeInsets.only(right: AppTheme.spaceMd),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      PremiumColors.accentGradient2.withOpacity(0.2),
                      PremiumColors.accentGradient1.withOpacity(0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: PremiumColors.accentGradient1.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.bookmark,
                    color: PremiumColors.accentGradient1,
                    size: 24,
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
        ],
      ),
      drawer: _buildDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PremiumColors.darkBg,
              PremiumColors.darkBg2.withOpacity(0.5),
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
                        PremiumColors.accentGradient1.withOpacity(0.08),
                        PremiumColors.accentGradient2.withOpacity(0.05),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: PremiumColors.accentGradient1.withOpacity(0.2),
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
                                  PremiumColors.accentGradient2,
                                  PremiumColors.accentGradient1,
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
                          backgroundColor: PremiumColors.accentGradient1
                              .withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            PremiumColors.accentGradient1,
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

              // Chat Messages
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMd,
                    vertical: AppTheme.spaceMd,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isBot = msg.senderType == 'bot';
                    return Padding(
                      padding: EdgeInsets.only(bottom: AppTheme.spaceMd),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: isBot
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.end,
                        children: [
                          if (isBot)
                            Container(
                              width: 32,
                              height: 32,
                              margin: EdgeInsets.only(right: AppTheme.spaceSm),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    PremiumColors.accentGradient2,
                                    PremiumColors.accentGradient1,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: PremiumColors.accentGradient2
                                        .withOpacity(0.3),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.psychology,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          Flexible(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: isBot
                                    ? LinearGradient(
                                        colors: [
                                          PremiumColors.cardBg.withOpacity(0.8),
                                          PremiumColors.darkBg2.withOpacity(
                                            0.6,
                                          ),
                                        ],
                                      )
                                    : LinearGradient(
                                        colors: [
                                          PremiumColors.accentGradient2,
                                          PremiumColors.accentGradient1,
                                        ],
                                      ),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(isBot ? 4 : 16),
                                  topRight: Radius.circular(isBot ? 16 : 4),
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                                border: isBot
                                    ? Border.all(
                                        color: PremiumColors.accentGradient1
                                            .withOpacity(0.2),
                                        width: 1,
                                      )
                                    : null,
                                boxShadow: isBot
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: isBot
                                  ? ProfessionalMessageWidget(
                                      msg.text,
                                      isBot: true,
                                    )
                                  : Text(
                                      msg.text,
                                      style: TextStyle(
                                        color: Colors.white,
                                        height: 1.5,
                                        fontSize: 15,
                                      ),
                                    ),
                            ),
                          ),
                          if (!isBot) SizedBox(width: AppTheme.spaceXs),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Input Area
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  // Input Area
  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            PremiumColors.darkBg2.withOpacity(0.8),
            PremiumColors.cardBg,
          ],
        ),
        border: Border(
          top: BorderSide(
            color: PremiumColors.accentGradient1.withOpacity(0.2),
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
                    PremiumColors.cardBg.withOpacity(0.6),
                    PremiumColors.darkBg2.withOpacity(0.4),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: PremiumColors.accentGradient1.withOpacity(0.2),
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
                colors: [
                  PremiumColors.accentGradient2,
                  PremiumColors.accentGradient1,
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: PremiumColors.accentGradient2.withOpacity(0.4),
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
        subtopics: List<String>.from(mod['key_topics'] ?? mod['subtopics'] ?? mod['learning_objectives'] ?? []),
        estimatedTime: mod['estimated_effort'] ?? mod['duration'] ?? '30 minutes',
        difficultyLevel: mod['difficulty'] ?? 'Medium',
      );
    }).toList();
  }

  /// Build drawer menu with navigation options
  Widget _buildDrawer() {
    // Use converted study plan or fallback to botState tableOfContents
    final tocItems = _studyPlan != null 
        ? _convertStudyPlanToToc() 
        : _botState?.tableOfContents ?? [];
    
    return StudyPlanHamburgerMenu(
      tableOfContents: tocItems.isNotEmpty ? tocItems : null,
      currentModule: _botState?.currentModule ?? 0,
      completedModules: _botState?.completedModules,
      progressPercentage: _progressPercentage,
      planVersion: _planVersion,
      onModuleEdit: (moduleIndex, moduleName) {
        // Handle module edit - navigate to editor
        print('[ChatScreen] Edit module $moduleIndex: $moduleName');
        _openPlanEditor();
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
              content: Text('No study plan available yet. Ask your tutor to create one!'),
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
            (mod['module_name'] == null || mod['module_name'].toString().isEmpty)) {
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
              content: Text('✅ Study plan saved (v$newVersion)! AI will adapt to your changes.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
        print('[ChatScreen] Plan applied successfully, version: $newVersion');
        
        // Notify AI about plan update
        await _addBotMessage("Got it — I've updated our study route. We'll continue with the revised plan.");
        
      } else if (response.statusCode == 400 || response.statusCode == 404) {
        // Fallback to update endpoint if apply not available
        final fallbackUri = Uri.parse('$_backendUrl/api/update-study-plan');
        final fallbackResp = await http.post(
          fallbackUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'botId': widget.botId,
            'userId': userId,
            'updatedPlan': updatedPlan,
            'apply': apply,
          }),
        ).timeout(const Duration(seconds: 30));

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
            content: Text('❌ Failed to save plan. Your changes are preserved locally.'),
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
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _studyPlan = body['study_plan'] as Map<String, dynamic>?;
          _planVersion = body['plan_version'] as int? ?? 1;
          _progressPercentage = (body['progress']?['percentage'] as num?)?.toDouble() ?? 0.0;
          _botCurrentState = body['bot_state'] as String? ?? 'intro';
        });
        print('[ChatScreen] Loaded study plan v$_planVersion');
        return true;
      } else if (response.statusCode == 404) {
        // No progress record yet - this is okay for new bots
        print('[ChatScreen] No study plan found (404) - new bot');
        return false;
      } else {
        print('[ChatScreen] Failed to load study plan: ${response.statusCode}');
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

  /// Show quiz popup asking if user wants to take quiz now or later
  void _showQuizPopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.backgroundDeep,
          title: Text(
            '📝 Ready for a Quiz?',
            style: AppTheme.headlineSmall.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Do you want to take a quiz now to test your knowledge, or would you prefer to do it later?',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
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
                  color: AppTheme.textSecondary,
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
      final payload = {
        'botId': widget.botId,
        'userId': userId,
        'moduleName':
            'Module ${((_botState?.chatHistory?.length) ?? 0) ~/ 5 + 1}',
        'moduleContent': _getModuleContext(),
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
          .timeout(Duration(seconds: 45));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final quiz = body['quiz'] as Map<String, dynamic>?;
        final quizId = body['quizId'] as int?;

        print('[ChatScreen] Quiz generated successfully');

        if (quiz != null) {
          // Store quiz ID for explanation callbacks
          _currentQuizId = quizId;
          // Show quiz artifact
          _showQuizArtifact(quiz);
        }
      } else {
        print('[ChatScreen] Quiz generation failed: ${resp.statusCode}');
        _addBotMessage(
          'Sorry, I had trouble generating the quiz. Let\'s try again later!',
        );
      }
    } catch (e) {
      print('[ChatScreen] Error: $e');
      _addBotMessage('Network error while generating quiz: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Show quiz artifact dialog
  void _showQuizArtifact(Map<String, dynamic> quiz) {
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
                  onPressed: () {
                    Navigator.of(context).pop();
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

      print(
        '[ChatScreen] Milestone recorded: $description, Progress: ${_progressPercentage.toStringAsFixed(1)}%',
      );
    } catch (e) {
      print('[ChatScreen] Error recording milestone: $e');
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

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
}
