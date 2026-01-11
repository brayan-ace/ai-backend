import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/study_bot_state.dart';
import '../services/study_plan_service.dart';
import '../services/study_bot_flow_controller.dart';
import '../utils/theme.dart';
import 'study_plan_editor_screen.dart';
import 'quiz_config_screen.dart';
import '../widgets/quiz_artifact_widget.dart';

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

  // Progress tracking
  double _progressPercentage = 0;
  String _botCurrentState = 'intro';

  // Quiz tracking
  int? _currentQuizId;

  // Backend URL
  static const String _backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://ai-backend-vf75.onrender.com',
  );

  @override
  void initState() {
    super.initState();
    _planService = StudyPlanService();
    _flowController = StudyBotFlowController();

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

      // Check if we have an existing state for this bot
      StudyBotState? existingState;
      if (widget.botId != null) {
        final states = await _planService.getBotStatesByBotId(widget.botId!);
        if (states.isNotEmpty) {
          existingState = states.first;
        }
      }

      if (existingState != null && _messages.isEmpty) {
        _botState = existingState;
        _messages = (existingState.chatHistory ?? [])
            .map((m) => StudyBotMessage.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      } else if (_messages.isEmpty) {
        // Create new session only if no messages were loaded
        _botState = _flowController.createNewSession(botId: widget.botId!);
        _messages = [];

        // Add initial bot greeting
        await _addBotMessage(
          _flowController.getBotResponseForState(
            StudyBotStateType.intro,
            botName: widget.botName,
            planName: widget.planName,
          ),
        );
      }

      setState(() {});
    } catch (e) {
      print('[ChatScreen] Error in _initPhase2: $e');
    }
  }

  Future<void> _addBotMessage(String text) async {
    // Check if this is a quiz popup trigger
    if (text.contains('[SHOW_QUIZ_POPUP]')) {
      // Extract the actual message (without the marker)
      final displayText = text.replaceAll('[SHOW_QUIZ_POPUP]', '').trim();

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
        text: text,
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
      final payload = {
        'message': userMessage,
        'botId': widget.botId,
        'userId': userId,
        'systemInstructions': _botInstructions,
      };

      final payloadStr = jsonEncode(payload);
      final maxLen = payloadStr.length > 200 ? 200 : payloadStr.length;
      print('[ChatScreen] Payload: ${payloadStr.substring(0, maxLen)}');

      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(Duration(seconds: 30));

      print(
        '[ChatScreen] Response: ${resp.statusCode} ${resp.body.substring(0, resp.body.length > 200 ? 200 : resp.body.length)}',
      );

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final botResponse = body['response'] ?? 'No response';
        final newState = body['state'] ?? _botCurrentState;
        final progress = body['progress'] as Map<String, dynamic>?;

        setState(() {
          _botCurrentState = newState;
          if (progress != null) {
            _progressPercentage = (progress['percentage'] ?? 0).toDouble();
          }
        });

        await _addBotMessage(botResponse);
      } else {
        await _addBotMessage('Error: ${resp.statusCode}. ${resp.body}');
      }
    } catch (e) {
      print('[ChatScreen] Error: $e');
      await _addBotMessage('Network error: $e');
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
      backgroundColor: AppTheme.backgroundDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _botCurrentState == 'learning'
            ? IconButton(
                icon: Icon(
                  Icons.bookmark_outline,
                  color: AppTheme.primaryBlue,
                  size: 28,
                ),
                tooltip: 'View & Edit Learning Plan',
                onPressed: () => _showModulesModal(),
              )
            : null,
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
            if (_botCurrentState.isNotEmpty)
              Text(
                _botCurrentState == 'intro'
                    ? 'Ready to learn? Say "ready"'
                    : _botCurrentState == 'plan_review'
                    ? 'Plan created - Ready to start?'
                    : 'Learning mode - Step by step',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
          ],
        ),
      ),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Enhanced Progress Bar with Concept Tracking
            if (_botCurrentState == 'learning')
              Container(
                padding: EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue.withOpacity(0.05),
                      AppTheme.primaryBlue.withOpacity(0.02),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      width: 1,
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
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_progressPercentage.toStringAsFixed(0)}%',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progressPercentage / 100,
                        minHeight: 8,
                        backgroundColor: AppTheme.primaryBlue.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '✨ Say "I understand" when you master a concept to track progress',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
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
                              color: AppTheme.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.smart_toy,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        Flexible(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceMd,
                              vertical: AppTheme.spaceMd,
                            ),
                            decoration: BoxDecoration(
                              color: isBot
                                  ? AppTheme.surfaceCard
                                  : AppTheme.primaryBlue,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(
                                  isBot ? 4 : AppTheme.radiusMd,
                                ),
                                topRight: Radius.circular(
                                  isBot ? AppTheme.radiusMd : 4,
                                ),
                                bottomLeft: Radius.circular(AppTheme.radiusMd),
                                bottomRight: Radius.circular(AppTheme.radiusMd),
                              ),
                            ),
                            child: isBot
                                ? FormattedTextWidget(msg.text)
                                : Text(
                                    msg.text,
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: Colors.white,
                                      height: 1.5,
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
            Container(
              padding: EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                border: Border(
                  top: BorderSide(color: AppTheme.surfaceElevated),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          borderSide: BorderSide(
                            color: AppTheme.surfaceElevated,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMd,
                          vertical: AppTheme.spaceSm,
                        ),
                      ),
                      onSubmitted: (text) {
                        if (text.isNotEmpty && !_isLoading) {
                          _addUserMessage(text);
                        }
                      },
                    ),
                  ),
                  SizedBox(width: AppTheme.spaceSm),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
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
            ),
          ],
        ),
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

  /// Build drawer menu with navigation options
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppTheme.backgroundDeep,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue,
                  AppTheme.primaryBlue.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  widget.botName ?? 'Study Bot',
                  style: AppTheme.headlineMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: AppTheme.spaceSm),
                Text(
                  'Menu',
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.home, color: AppTheme.primaryBlue),
            title: Text(
              'Back to Main AI',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
            ),
            onTap: () {
              Navigator.of(context).pop(); // Close drawer
              Navigator.of(context).pop(); // Return to main page
            },
          ),
          Divider(
            color: AppTheme.surfaceElevated,
            height: AppTheme.spaceLg,
            indent: AppTheme.spaceMd,
            endIndent: AppTheme.spaceMd,
          ),
          ListTile(
            leading: Icon(Icons.info_outline, color: AppTheme.primaryBlue),
            title: Text(
              'About This Bot',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
            ),
            onTap: () {
              Navigator.of(context).pop(); // Close drawer
              _showAboutDialog();
            },
          ),
        ],
      ),
    );
  }

  /// Show about dialog with bot information
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
    if (_studyPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Study plan not loaded yet. Please try again.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final userId = currentUser?.uid ?? 'anonymous';

    Navigator.pop(context); // Close the modal

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

    // Reload plan after editor closes
    if (result != null) {
      _loadStudyPlan();
    }
  }

  Future<void> _savePlanChanges(
    Map<String, dynamic> updatedPlan,
    String userId,
  ) async {
    try {
      // Update plan in state
      setState(() => _studyPlan = updatedPlan);

      // Send to backend
      final uri = Uri.parse('$_backendUrl/api/update-study-plan');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'botId': widget.botId,
              'userId': userId,
              'updatedPlan': updatedPlan,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Study plan updated! I\'ll adjust my teaching strategy.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        print('[ChatScreen] Plan saved successfully');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('[ChatScreen] Error saving plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadStudyPlan() async {
    if (widget.botId == null) return;

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
        });
      }
    } catch (e) {
      print('[ChatScreen] Error loading study plan: $e');
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

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
}
