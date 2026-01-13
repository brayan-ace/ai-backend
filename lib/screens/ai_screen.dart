import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/gemini_services.dart';
import '../utils/theme.dart';
import '../widgets/typing_indicator.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  // API keys removed — requests go through the backend
  final GeminiService _gemini = GeminiService();

  final List<_Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _isWaiting = false;
  bool _detailedMode = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _Message(
        text: 'Welcome to Online AI — type a message below to get started.',
        fromUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isWaiting) return;

    setState(() {
      _messages.add(_Message(text: text, fromUser: true));
      _controller.clear();
      _isWaiting = true;
    });

    final response = await _callWithFallback(text);

    setState(() {
      _messages.add(_Message(text: response ?? 'No response', fromUser: false));
      _isWaiting = false;
    });
  }

  Future<String?> _callWithFallback(String prompt) async {
    try {
      final resp = await _gemini.generateContent(prompt);
      return resp;
    } catch (e) {
      return '⚠️ All AI services are currently unavailable. ($e)';
    }
  }

  void _notImplemented(String what) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$what not implemented yet')));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.backgroundGradientStart,
            AppTheme.backgroundGradientEnd,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: AppTheme.glassGradient),
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.surfaceElevated.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
            ),
          ),
          title: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: AppTheme.accentGradient,
            ).createShader(bounds),
            child: Text(
              'AI Assistant',
              style: AppTheme.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          centerTitle: true,
          actions: [
            Container(
              margin: EdgeInsets.only(right: AppTheme.spaceSm),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: AppTheme.glassGradient),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _detailedMode ? Icons.menu_book : Icons.article,
                      color: AppTheme.textPrimary,
                    ),
                    tooltip: _detailedMode ? 'Detailed mode' : 'Concise mode',
                    onPressed: () =>
                        setState(() => _detailedMode = !_detailedMode),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: AppTheme.textPrimary),
                    onPressed: () => _notImplemented('More options'),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  itemCount: _messages.length,
                  itemBuilder: (context, idx) {
                    final m = _messages[idx];
                    return _buildMessageBubble(m);
                  },
                ),
              ),
              // Display TypingIndicator when _isWaiting is true
              if (_isWaiting)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMd,
                    vertical: AppTheme.spaceSm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      TypingIndicator(),
                      SizedBox(width: AppTheme.spaceSm),
                      Text(
                        'Generating response...', // Text for user interaction
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

              // Futuristic Input Section
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: AppTheme.glassGradient),
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.surfaceElevated.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                padding: EdgeInsets.all(AppTheme.spaceMd),
                child: Row(
                  children: [
                    _buildGlassButton(
                      icon: Icons.add_box_outlined,
                      onPressed: () => _notImplemented('Attach file'),
                    ),
                    SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppTheme.surfaceGradient,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXl,
                          ),
                          border: Border.all(
                            color: AppTheme.surfaceElevated,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMd,
                          vertical: AppTheme.spaceSm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                                style: AppTheme.bodyLarge.copyWith(
                                  color: AppTheme.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Type a message...',
                                  hintStyle: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.textTertiary,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: AppTheme.spaceSm,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: AppTheme.spaceSm),
                            // Replaced _isWaiting indicator with a placeholder for consistency, the actual typing indicator is now above
                            _isWaiting
                                ? const SizedBox(width: 32)
                                : _buildSendButton(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_Message message) {
    final isUser = message.fromUser;

    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.spaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) SizedBox(width: AppTheme.spaceSm),
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isUser
                      ? AppTheme.accentGradient
                      : AppTheme.surfaceGradient,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: EdgeInsets.all(AppTheme.spaceMd),
              child: _buildMessageContent(message.text, isUser),
            ),
          ),
          if (isUser) SizedBox(width: AppTheme.spaceSm),
        ],
      ),
    );
  }

  Widget _buildMessageContent(String text, bool isUser) {
    if (isUser) {
      return Text(
        text,
        style: AppTheme.bodyLarge.copyWith(color: Colors.white, height: 1.5),
        softWrap: true,
      );
    }

    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        h1: AppTheme.headlineSmall.copyWith(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.bold,
          height: 1.6,
        ),
        h2: AppTheme.headlineMedium.copyWith(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
        h3: AppTheme.bodyLarge.copyWith(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        p: AppTheme.bodyLarge.copyWith(
          color: AppTheme.textPrimary,
          height: 1.6,
        ),
        em: AppTheme.bodyLarge.copyWith(
          color: AppTheme.textPrimary,
          fontStyle: FontStyle.italic,
          height: 1.6,
        ),
        strong: AppTheme.bodyLarge.copyWith(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.bold,
          height: 1.6,
        ),
        code: AppTheme.bodyMedium.copyWith(
          color: AppTheme.textSecondary,
          backgroundColor: AppTheme.surfaceCard.withValues(alpha: 0.5),
          fontFamily: 'monospace',
        ),
        blockquote: AppTheme.bodyLarge.copyWith(
          color: AppTheme.textSecondary,
          height: 1.6,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: AppTheme.primaryBlue, width: 3),
          ),
        ),
        listBullet: AppTheme.bodyLarge.copyWith(
          color: AppTheme.textPrimary,
          height: 1.6,
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppTheme.surfaceElevated.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: AppTheme.glassGradient),
        border: Border.all(
          color: AppTheme.surfaceElevated.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: IconButton(
        icon: Icon(icon, color: AppTheme.textSecondary),
        onPressed: onPressed,
        iconSize: 22,
      ),
    );
  }

  Widget _buildSendButton() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.accentGradient,
        ),
        boxShadow: AppTheme.accentGlow,
      ),
      child: IconButton(
        icon: Icon(Icons.arrow_upward, color: Colors.white),
        onPressed: _send,
        iconSize: 20,
      ),
    );
  }
}

class _Message {
  final String text;
  final bool fromUser;
  _Message({required this.text, required this.fromUser});
}
