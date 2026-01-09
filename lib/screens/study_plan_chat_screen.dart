import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/study_bot_state.dart';
import '../services/study_plan_service.dart';
import '../services/study_bot_flow_controller.dart';
import '../utils/theme.dart';

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
    // Check if we have an existing state for this bot
    StudyBotState? existingState;
    if (widget.botId != null) {
      final states = await _planService.getBotStatesByBotId(widget.botId!);
      if (states.isNotEmpty) {
        existingState = states.first;
      }
    }

    if (existingState != null) {
      _botState = existingState;
      _messages = (existingState.chatHistory ?? [])
          .map((m) => StudyBotMessage.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } else {
      // Create new session
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
      print('[ChatScreen] Bot Instructions: $_botInstructions');

      // Get current user ID from Firebase Auth
      final currentUser = FirebaseAuth.instance.currentUser;
      final userId = currentUser?.uid ?? 'anonymous';
      print('[ChatScreen] User ID: $userId');

      final uri = Uri.parse('$_backendUrl/api/chat');
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
        '[ChatScreen] Response: ${resp.statusCode} ${resp.body.substring(0, 200)}',
      );

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final botResponse = body['response'] ?? 'No response';

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

  Future<void> _processUserMessage(String userMessage) async {
    final currentState = _botState?.currentState ?? StudyBotStateType.intro;
    String botResponse = '';
    StudyBotStateType? nextState;

    // Handle state transitions based on user input
    switch (currentState) {
      case StudyBotStateType.intro:
        if (userMessage.toLowerCase().contains('yes') ||
            userMessage.toLowerCase().contains('begin') ||
            userMessage.toLowerCase().contains('start')) {
          nextState = StudyBotStateType.planProposal;

          // Generate TOC
          final toc = _flowController.generateTableOfContents(
            educationLevel: widget.educationLevel ?? 'secondary',
            planDescription:
                widget.planDescription ?? widget.planName ?? 'Study Plan',
          );

          _botState = _botState!.copyWith(
            tableOfContents: toc,
            tocGenerated: true,
          );

          botResponse = _flowController.getBotResponseForState(
            StudyBotStateType.planProposal,
            planName: widget.planName,
          );
        } else {
          botResponse =
              'Of course! I can tell you more about our study approach. Are you ready to begin?';
        }
        break;

      case StudyBotStateType.planProposal:
        if (userMessage.toLowerCase().contains('approve')) {
          nextState = StudyBotStateType.planApproved;
          botResponse = _flowController.getBotResponseForState(
            StudyBotStateType.planApproved,
            botName: widget.botName,
          );
        } else if (userMessage.toLowerCase().contains('modify')) {
          nextState = StudyBotStateType.planModification;
          botResponse = _flowController.getBotResponseForState(
            StudyBotStateType.planModification,
            planName: widget.planName,
          );
        } else {
          botResponse =
              'Would you like to approve this plan or modify it? You can adjust the pace, topics, or depth.';
        }
        break;

      case StudyBotStateType.planModification:
        // Store modification request
        final mod = PlanModificationRequest(
          modificationArea: _extractModificationArea(userMessage),
          userRequest: userMessage,
          timestamp: DateTime.now(),
        );

        final mods = _botState?.modificationHistory ?? [];
        _botState = _botState!.copyWith(modificationHistory: [...mods, mod]);

        // Transition back to plan proposal to regenerate TOC
        nextState = StudyBotStateType.planProposal;

        // Regenerate TOC with modifications
        final toc = _flowController.generateTableOfContents(
          educationLevel: widget.educationLevel ?? 'secondary',
          planDescription: '${widget.planDescription} - ${userMessage}',
        );

        _botState = _botState!.copyWith(tableOfContents: toc);

        botResponse = _flowController.getBotResponseForState(
          StudyBotStateType.planProposal,
          planName: widget.planName,
        );
        botResponse =
            'Based on your feedback, I\'ve adjusted your learning path. Here\'s the updated plan:\n\n$botResponse';
        break;

      case StudyBotStateType.planApproved:
        if (userMessage.toLowerCase().contains('start')) {
          nextState = StudyBotStateType.lessonActive;
          _botState = _botState!.copyWith(currentModule: 1);
          botResponse = _flowController.getBotResponseForState(
            StudyBotStateType.lessonActive,
            botName: widget.botName,
            planName: widget.planName,
          );
        } else {
          botResponse = 'Ready? Let\'s start Module 1!';
        }
        break;

      default:
        botResponse = 'I\'m processing your request...';
    }

    // Perform state transition if valid
    if (nextState != null && _botState != null) {
      if (_flowController.canTransitionTo(currentState, nextState)) {
        _botState = _flowController.transitionTo(_botState!, nextState);
      }
    }

    // Add bot response
    await _addBotMessage(botResponse);

    // Update state
    if (_botState != null) {
      _botState = _botState!.copyWith(lastUpdated: DateTime.now());
      await _planService.saveBotState(_botState!);
    }

    setState(() {
      _isLoading = false;
    });
  }

  String _extractModificationArea(String text) {
    if (text.toLowerCase().contains('pace')) return 'pace';
    if (text.toLowerCase().contains('topic')) return 'topics';
    if (text.toLowerCase().contains('depth')) return 'depth';
    return 'general';
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
              'State: ${_botState?.currentState.toString().split('.').last.toUpperCase() ?? 'UNKNOWN'}',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          if (_botState?.tableOfContents != null &&
              _botState!.tableOfContents!.isNotEmpty)
            IconButton(
              icon: Icon(Icons.menu_book, color: AppTheme.primaryBlue),
              onPressed: () {
                setState(() => _showToc = !_showToc);
              },
            ),
        ],
      ),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Table of Contents (if visible)
            if (_showToc && _botState?.tableOfContents != null)
              _buildTableOfContentsWidget(),

            // Chat Messages
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(AppTheme.spaceMd),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isBot = msg.senderType == 'bot';
                  return Padding(
                    padding: EdgeInsets.only(bottom: AppTheme.spaceSm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: isBot
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.end,
                      children: [
                        if (isBot)
                          Container(
                            width: 32,
                            height: 32,
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
                        SizedBox(width: AppTheme.spaceXs),
                        Flexible(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceMd,
                              vertical: AppTheme.spaceSm,
                            ),
                            decoration: BoxDecoration(
                              color: isBot
                                  ? AppTheme.surfaceCard
                                  : AppTheme.primaryBlue,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd,
                              ),
                            ),
                            child: Text(
                              msg.text,
                              style: AppTheme.bodyMedium.copyWith(
                                color: isBot
                                    ? AppTheme.textPrimary
                                    : Colors.white,
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

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
}
