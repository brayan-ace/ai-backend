import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/study_bot_state.dart';
import '../services/study_plan_service.dart';
import '../services/study_bot_flow_controller.dart';
import '../utils/theme.dart';

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

  // Progress tracking
  double _progressPercentage = 0;
  String _botCurrentState = 'intro';

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
            });
            print(
              '[ChatScreen] Restored state: $_botCurrentState, progress: $_progressPercentage%',
            );
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
                    Text(
                      '📚 Your Learning Plan',
                      style: AppTheme.headlineSmall.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
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

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
}
