import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/theme.dart';
import 'study_plan_chat_screen.dart';

// Premium color palette matching bot_creation_screen
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
      backgroundColor: PremiumColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              PremiumColors.accentGradient2,
              PremiumColors.accentGradient1,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            'Preparing your Study Bot',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: true,
      ),
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
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isError) ...[
                    // Premium animated progress indicator
                    _buildPremiumProgressIndicator(),
                    SizedBox(height: 40),

                    // Premium progress steps with glassmorphism
                    _buildPremiumStepsIndicator(),
                    SizedBox(height: 40),

                    // Current status with premium styling
                    _buildStatusMessage(),
                    SizedBox(height: 30),

                    // Animated loading dots
                    _buildLoadingDots(),
                  ] else ...[
                    // Premium error state
                    _buildErrorState(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Premium progress indicator with gradient and animation
  Widget _buildPremiumProgressIndicator() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            PremiumColors.accentGradient2.withOpacity(0.15),
            PremiumColors.accentGradient1.withOpacity(0.1),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: PremiumColors.accentGradient2.withOpacity(0.2),
            blurRadius: 30,
            spreadRadius: 10,
          ),
          BoxShadow(
            color: PremiumColors.accentGradient1.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 5,
          ),
        ],
        border: Border.all(
          color: PremiumColors.accentGradient1.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated circular progress
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(
              Color.lerp(
                PremiumColors.accentGradient2,
                PremiumColors.accentGradient1,
                0.5,
              )!,
            ),
            strokeWidth: 3,
            backgroundColor: PremiumColors.accentGradient1.withOpacity(0.1),
          ),

          // Center icon with gradient
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  PremiumColors.accentGradient2,
                  PremiumColors.accentGradient1,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: PremiumColors.accentGradient2.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(Icons.school_outlined, color: Colors.white, size: 40),
          ),
        ],
      ),
    );
  }

  // Premium steps indicator with glassmorphism effect
  Widget _buildPremiumStepsIndicator() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PremiumColors.cardBg.withOpacity(0.8),
            PremiumColors.darkBg2.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: PremiumColors.accentGradient1.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < _steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i < _steps.length - 1 ? 16 : 0),
              child: Row(
                children: [
                  // Step indicator circle
                  Container(
                    width: 40,
                    height: 40,
                    margin: EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: i <= _currentStep
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                PremiumColors.accentGradient2,
                                PremiumColors.accentGradient1,
                              ],
                            )
                          : LinearGradient(
                              colors: [
                                PremiumColors.cardBg,
                                PremiumColors.darkBg2,
                              ],
                            ),
                      border: Border.all(
                        color: i <= _currentStep
                            ? PremiumColors.accentGradient1
                            : PremiumColors.accentGradient1.withOpacity(0.2),
                        width: 2,
                      ),
                      boxShadow: i == _currentStep
                          ? [
                              BoxShadow(
                                color: PremiumColors.accentGradient2
                                    .withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: i < _currentStep
                          ? Icon(Icons.check, size: 20, color: Colors.white)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: i == _currentStep
                                    ? Colors.white
                                    : PremiumColors.accentGradient1.withOpacity(
                                        0.5,
                                      ),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),

                  // Step text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _steps[i],
                          style: TextStyle(
                            fontSize: i == _currentStep ? 15 : 14,
                            fontWeight: i == _currentStep
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: i == _currentStep
                                ? Colors.white
                                : Colors.white.withOpacity(0.7),
                          ),
                        ),
                        if (i == _currentStep)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Container(
                              height: 2,
                              width: 30,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    PremiumColors.accentGradient2,
                                    PremiumColors.accentGradient1,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Premium status message
  Widget _buildStatusMessage() {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: Container(
        key: ValueKey<String>(_statusMessage),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PremiumColors.accentGradient1.withOpacity(0.1),
              PremiumColors.accentGradient2.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: PremiumColors.accentGradient1.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          _statusMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            background: Paint()
              ..shader = LinearGradient(
                colors: [
                  PremiumColors.accentGradient2,
                  PremiumColors.accentGradient1,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(Rect.fromLTWH(0, 0, 200, 70)),
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Animated loading dots
  Widget _buildLoadingDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 600),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  PremiumColors.accentGradient2,
                  PremiumColors.accentGradient1,
                ],
              ),
              opacity: (_currentStep / _steps.length) * (0.3 + (index * 0.2)),
              boxShadow: [
                BoxShadow(
                  color: PremiumColors.accentGradient2.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // Premium error state
  Widget _buildErrorState() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Colors.red.withOpacity(0.15),
                Colors.red.withOpacity(0.05),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
            border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
          ),
          child: Center(
            child: Icon(
              Icons.error_outline,
              color: Colors.red.shade400,
              size: 60,
            ),
          ),
        ),
        SizedBox(height: 32),

        Text(
          'Oops! Something went wrong',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 16),

        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PremiumColors.cardBg.withOpacity(0.6),
                PremiumColors.darkBg2.withOpacity(0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.2), width: 1),
          ),
          child: Text(
            _errorMessage,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 32),

        // Retry button with premium styling
        GestureDetector(
          onTap: () {
            setState(() {
              _isError = false;
              _errorMessage = '';
              _currentStep = 0;
              _statusMessage = _steps.first;
            });
            _startProcessing();
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  PremiumColors.accentGradient2,
                  PremiumColors.accentGradient1,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: PremiumColors.accentGradient2.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
