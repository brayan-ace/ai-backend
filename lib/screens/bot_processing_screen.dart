import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/theme.dart';
import 'study_plan_chat_screen.dart';

class BotProcessingScreen extends StatefulWidget {
  final String name;
  final String description;
  final String topic;
  final String gradeLevel;
  final String userId;

  const BotProcessingScreen({
    Key? key,
    required this.name,
    required this.description,
    required this.topic,
    required this.gradeLevel,
    required this.userId,
  }) : super(key: key);

  @override
  State<BotProcessingScreen> createState() => _BotProcessingScreenState();
}

class _BotProcessingScreenState extends State<BotProcessingScreen> {
  final List<String> _steps = [
    'Analyzing your study plan...',
    'Searching for resources...',
    'Preparing your Study Bot...',
    'Finalizing your custom instructions...',
  ];

  int _currentStep = 0;
  String _statusMessage = '';
  bool _isError = false;
  String _errorMessage = '';
  Timer? _timer;

  // Backend URL - adjust via --dart-define or change default
  static const String _backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://ai-backend-vf75.onrender.com',
  );

  @override
  void initState() {
    super.initState();
    _statusMessage = _steps.first;
    print(
      '[BotProcessingScreen] initState: name=${widget.name}, userId=${widget.userId}',
    );
    _startProcessing();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startProcessing() {
    print('[BotProcessingScreen] _startProcessing called');
    // Show progress messages over 10 seconds (4 steps)
    final stepDuration = Duration(seconds: 10 ~/ _steps.length);

    _timer = Timer.periodic(stepDuration, (timer) {
      if (mounted) {
        setState(() {
          _currentStep = timer.tick - 1;
          if (_currentStep < _steps.length) {
            _statusMessage = _steps[_currentStep];
          }
        });
      }

      if (timer.tick >= _steps.length) {
        timer.cancel();
      }
    });

    // Start network request concurrently; ensure screen visible at least 10s
    final processingFuture = _callCreateStudyBot();
    Future.wait([processingFuture, Future.delayed(Duration(seconds: 10))]).then(
      (results) {
        final bot = results[0];
        print('[BotProcessingScreen] AI call finished, bot=$bot');
        if (bot == null) {
          if (mounted) setState(() => _isError = true);
          return;
        }

        // Navigate to chat screen, pass properties
        if (mounted) {
          print('[BotProcessingScreen] Navigating to StudyPlanChatScreen');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => StudyPlanChatScreen(
                botId: bot['bot_id'],
                planName: bot['name'],
                planDescription: bot['description'] ?? '',
                botName: bot['name'],
                educationLevel: bot['grade_level'] ?? '',
                systemInstructions:
                    bot['system_instructions'] as Map<String, dynamic>?,
              ),
            ),
          );
        }
      },
    );
  }

  Future<Map<String, dynamic>?> _callCreateStudyBot() async {
    try {
      print(
        '[BotProcessingScreen] Calling backend at $_backendUrl/api/create-study-bot',
      );
      final uri = Uri.parse('$_backendUrl/api/create-study-bot');
      final payload = {
        'user_id': widget.userId,
        'name': widget.name,
        'description': widget.description,
        'topic': widget.topic,
        'grade_level': widget.gradeLevel,
      };

      print('[BotProcessingScreen] Payload: $payload');
      print('[BotProcessingScreen] Backend URL: $_backendUrl');
      print('[BotProcessingScreen] Full URI: $uri');

      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(
            Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('API call timed out after 30 seconds');
            },
          );

      print(
        '[BotProcessingScreen] Received response: ${resp.statusCode} ${resp.body.substring(0, resp.body.length > 200 ? 200 : resp.body.length)}',
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final bot = body['bot'] as Map<String, dynamic>?;
        print(
          '[BotProcessingScreen] Bot created successfully: ${bot?['bot_id']}',
        );
        return bot;
      }

      final errorMsg =
          'Server error (${resp.statusCode}). Response: ${resp.body}';
      print('[BotProcessingScreen] $errorMsg');
      setState(() {
        _isError = true;
        _errorMessage = errorMsg;
      });
      return null;
    } catch (err, stackTrace) {
      final errorMsg = 'Network error: $err';
      print('[BotProcessingScreen] $errorMsg');
      print('[BotProcessingScreen] Stack: $stackTrace');
      setState(() {
        _isError = true;
        _errorMessage = errorMsg;
      });
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Preparing your Study Bot',
          style: AppTheme.headlineSmall.copyWith(color: AppTheme.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isError) ...[
                  // Animated progress indicator with gradient
                  Container(
                    width: 120,
                    height: 120,
                    padding: EdgeInsets.all(AppTheme.spaceMd),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryBlue.withOpacity(0.1),
                          AppTheme.primaryBlue.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Stack(
                      children: [
                        // Circular progress with animated gradient
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(
                            AppTheme.primaryBlue,
                          ),
                          strokeWidth: 4,
                        ),
                        // Center icon
                        Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppTheme.accentGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Icon(
                              Icons.school_outlined,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppTheme.spaceXl),
                  // Progress steps indicator
                  Column(
                    children: [
                      for (int i = 0; i < _steps.length; i++)
                        Padding(
                          padding: EdgeInsets.only(bottom: AppTheme.spaceSm),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                margin: EdgeInsets.only(
                                  right: AppTheme.spaceMd,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i <= _currentStep
                                      ? AppTheme.primaryBlue
                                      : AppTheme.surfaceElevated,
                                  border: Border.all(
                                    color: i <= _currentStep
                                        ? AppTheme.primaryBlue
                                        : AppTheme.surfaceElevated,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: i <= _currentStep
                                      ? Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.white,
                                        )
                                      : Text(
                                          '${i + 1}',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _steps[i],
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: i == _currentStep
                                        ? AppTheme.textPrimary
                                        : AppTheme.textSecondary,
                                    fontWeight: i == _currentStep
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: AppTheme.spaceXl),
                  // Current status with animation
                  AnimatedSwitcher(
                    duration: Duration(milliseconds: 300),
                    child: Text(
                      _statusMessage,
                      key: ValueKey<String>(_statusMessage),
                      textAlign: TextAlign.center,
                      style: AppTheme.headlineMedium.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: AppTheme.spaceLg),
                  // Loading animation dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      return Container(
                        width: 8,
                        height: 8,
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryBlue,
                        ),
                      );
                    }),
                  ),
                ] else ...[
                  // Error state with better styling
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.withOpacity(0.1),
                          Colors.red.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 56,
                      ),
                    ),
                  ),
                  SizedBox(height: AppTheme.spaceXl),
                  Text(
                    'Oops! Something went wrong',
                    style: AppTheme.headlineMedium.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppTheme.spaceMd),
                  Text(
                    _errorMessage,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppTheme.spaceXl),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isError = false;
                        _errorMessage = '';
                        _currentStep = 0;
                        _statusMessage = _steps.first;
                      });
                      _startProcessing();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceXl,
                        vertical: AppTheme.spaceMd,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, color: Colors.white, size: 20),
                        SizedBox(width: AppTheme.spaceSm),
                        Text(
                          'Retry',
                          style: AppTheme.labelMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
