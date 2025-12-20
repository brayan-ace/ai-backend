import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/theme.dart';
import '../utils/ai_constants.dart';
import '../widgets/ai_message_bubble.dart';
import '../widgets/typing_indicator.dart'; // Added import

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  // API keys with fallback support
  static const String groqApiKey =
      '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';
  static const String openRouterApiKey =
      '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';
  static const String deepSeekApiKey = 'sk-8d17e5b0c355485da07af11f552e37f9';

  final List<_Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _isWaiting = false;

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
    // Try Groq first
    var response = await _callGroq(groqApiKey, prompt);
    if (response != null &&
        !response.contains('ERROR') &&
        !response.contains('⚠️')) {
      return response;
    }

    // If Groq fails, try OpenRouter
    response = await _callOpenRouter(openRouterApiKey, prompt);
    if (response != null &&
        !response.contains('ERROR') &&
        !response.contains('⚠️')) {
      return response;
    }

    // If OpenRouter fails, try DeepSeek
    response = await _callDeepSeek(deepSeekApiKey, prompt);
    if (response != null &&
        !response.contains('ERROR') &&
        !response.contains('⚠️')) {
      return response;
    }

    // All APIs failed
    return '⚠️ All AI services are currently unavailable. Please try again later.';
  }

  Future<String?> _callGroq(String apiKey, String prompt) async {
    try {
      final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'system', 'content': AiConstants.systemPrompt},
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          if (message != null) {
            var out = message['content'] as String?;
            if (out != null) return out.trim();
          }
        }
        return '[[GROQ: no text found]]';
      } else if (resp.statusCode == 429) {
        return '⚠️ API quota exceeded. Please wait a few minutes and try again.';
      } else {
        return '[[GROQ ERROR: ${resp.statusCode}]] ${resp.body}';
      }
    } catch (e) {
      return '[[GROQ EXCEPTION]] $e';
    }
  }

  Future<String?> _callOpenRouter(String apiKey, String prompt) async {
    try {
      final uri = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'meta-llama/llama-3.1-8b-instruct:free',
          'messages': [
            {'role': 'system', 'content': AiConstants.systemPrompt},
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          if (message != null) {
            var out = message['content'] as String?;
            if (out != null) return out.trim();
          }
        }
        return '[[OPENROUTER: no text found]]';
      } else {
        return '[[OPENROUTER ERROR: ${resp.statusCode}]]';
      }
    } catch (e) {
      return '[[OPENROUTER EXCEPTION]] $e';
    }
  }

  Future<String?> _callDeepSeek(String apiKey, String prompt) async {
    try {
      final uri = Uri.parse('https://api.deepseek.com/v1/chat/completions');

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'deepseek-chat',
          'messages': [
            {'role': 'system', 'content': AiConstants.systemPrompt},
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          if (message != null) {
            var out = message['content'] as String?;
            if (out != null) return out.trim();
          }
        }
        return '[[DEEPSEEK: no text found]]';
      } else {
        return '[[DEEPSEEK ERROR: ${resp.statusCode}]]';
      }
    } catch (e) {
      return '[[DEEPSEEK EXCEPTION]] $e';
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
              child: IconButton(
                icon: Icon(Icons.more_vert, color: AppTheme.textPrimary),
                onPressed: () => _notImplemented('More options'),
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
                    return AiMessageBubble(
                      text: m.text,
                      fromUser: m.fromUser,
                      gradientColors: m.fromUser
                          ? AppTheme.accentGradient
                          : AppTheme.surfaceGradient,
                    );
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
