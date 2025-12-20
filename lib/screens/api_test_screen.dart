import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/theme.dart';

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  static const String groqApiKey =
      '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';
  static const String openRouterApiKey =
      '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';
  static const String deepSeekApiKey = 'sk-8d17e5b0c355485da07af11f552e37f9';

  String _groqStatus = 'Not tested';
  String _openRouterStatus = 'Not tested';
  String _deepSeekStatus = 'Not tested';
  bool _testing = false;

  Future<void> _testGroq() async {
    setState(() {
      _testing = true;
      _groqStatus = 'Testing...';
    });

    try {
      final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $groqApiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'user',
              'content': 'Say "Groq is working!" in one sentence.',
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String?;
          setState(() {
            _groqStatus = '✅ Working!\nResponse: ${content ?? "Success"}';
          });
        } else {
          setState(() {
            _groqStatus = '⚠️ Connected but no response';
          });
        }
      } else {
        setState(() {
          _groqStatus = '❌ Error: ${response.statusCode}\n${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _groqStatus = '❌ Exception: $e';
      });
    } finally {
      setState(() => _testing = false);
    }
  }

  Future<void> _testOpenRouter() async {
    setState(() {
      _testing = true;
      _openRouterStatus = 'Testing...';
    });

    try {
      final uri = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $openRouterApiKey',
        },
        body: jsonEncode({
          'model': 'meta-llama/llama-3.1-8b-instruct:free',
          'messages': [
            {
              'role': 'user',
              'content': 'Say "OpenRouter is working!" in one sentence.',
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String?;
          setState(() {
            _openRouterStatus = '✅ Working!\nResponse: ${content ?? "Success"}';
          });
        } else {
          setState(() {
            _openRouterStatus = '⚠️ Connected but no response';
          });
        }
      } else {
        setState(() {
          _openRouterStatus =
              '❌ Error: ${response.statusCode}\n${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _openRouterStatus = '❌ Exception: $e';
      });
    } finally {
      setState(() => _testing = false);
    }
  }

  Future<void> _testDeepSeek() async {
    setState(() {
      _testing = true;
      _deepSeekStatus = 'Testing...';
    });

    try {
      final uri = Uri.parse('https://api.deepseek.com/v1/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $deepSeekApiKey',
        },
        body: jsonEncode({
          'model': 'deepseek-chat',
          'messages': [
            {
              'role': 'user',
              'content': 'Say "DeepSeek is working!" in one sentence.',
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String?;
          setState(() {
            _deepSeekStatus = '✅ Working!\nResponse: ${content ?? "Success"}';
          });
        } else {
          setState(() {
            _deepSeekStatus = '⚠️ Connected but no response';
          });
        }
      } else {
        setState(() {
          _deepSeekStatus = '❌ Error: ${response.statusCode}\n${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _deepSeekStatus = '❌ Exception: $e';
      });
    } finally {
      setState(() => _testing = false);
    }
  }

  Future<void> _testAll() async {
    await _testGroq();
    await Future.delayed(Duration(seconds: 1));
    await _testOpenRouter();
    await Future.delayed(Duration(seconds: 1));
    await _testDeepSeek();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGradientStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: AppTheme.primaryGradient,
          ).createShader(bounds),
          child: Text(
            'API Test',
            style: AppTheme.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.backgroundGradientStart,
              AppTheme.backgroundGradientEnd,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppTheme.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Test All Button
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: AppTheme.primaryGradient),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  boxShadow: AppTheme.glowShadow,
                ),
                child: ElevatedButton(
                  onPressed: _testing ? null : _testAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.all(AppTheme.spaceMd),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: Text(
                    _testing ? 'Testing...' : 'Test All APIs',
                    style: AppTheme.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              SizedBox(height: AppTheme.spaceLg),

              // Groq API Card
              _buildApiCard(
                title: 'Groq API',
                subtitle: 'LLaMA 3.3 70B (Primary)',
                status: _groqStatus,
                onTest: _testGroq,
                gradientColors: AppTheme.primaryGradient,
              ),

              SizedBox(height: AppTheme.spaceMd),

              // OpenRouter API Card
              _buildApiCard(
                title: 'OpenRouter API',
                subtitle: 'LLaMA 3.1 8B (Fallback #1)',
                status: _openRouterStatus,
                onTest: _testOpenRouter,
                gradientColors: AppTheme.accentGradient,
              ),

              SizedBox(height: AppTheme.spaceMd),

              // DeepSeek API Card
              _buildApiCard(
                title: 'DeepSeek API',
                subtitle: 'DeepSeek Chat (Fallback #2)',
                status: _deepSeekStatus,
                onTest: _testDeepSeek,
                gradientColors: [AppTheme.accentBlue, AppTheme.accentBlueLight],
              ),

              SizedBox(height: AppTheme.spaceLg),

              // Info Card
              Container(
                padding: EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: AppTheme.surfaceGradient),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.surfaceElevated, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppTheme.primaryBlue,
                          size: 20,
                        ),
                        SizedBox(width: AppTheme.spaceXs),
                        Text(
                          'How it works',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppTheme.spaceSm),
                    Text(
                      'The app automatically tries APIs in this order:\n'
                      '1. Groq (fastest, most powerful)\n'
                      '2. OpenRouter (if Groq fails)\n'
                      '3. DeepSeek (if both fail)\n\n'
                      'This ensures your app keeps working even if one service is down.',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.5,
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

  Widget _buildApiCard({
    required String title,
    required String subtitle,
    required String status,
    required VoidCallback onTest,
    required List<Color> gradientColors,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppTheme.surfaceGradient),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfaceElevated, width: 1),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusMd),
                topRight: Radius.circular(AppTheme.radiusMd),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: AppTheme.spaceXs),
                Text(
                  subtitle,
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Status
          Padding(
            padding: EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Status:',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppTheme.spaceXs),
                Container(
                  padding: EdgeInsets.all(AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text(
                    status,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: AppTheme.spaceSm),
                ElevatedButton(
                  onPressed: _testing ? null : onTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceElevated,
                    padding: EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                  child: Text(
                    'Test This API',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
