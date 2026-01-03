import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  // Keys removed — requests go through backend

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
      final resp = await ApiService.send(
        'openai',
        'chat',
        'Say "Groq is working!"',
      );
      setState(() => _groqStatus = '✅ Working!\nResponse: $resp');
    } catch (e) {
      setState(() => _groqStatus = '❌ Exception: $e');
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
      final resp = await ApiService.send(
        'openai',
        'chat',
        'Say "OpenRouter is working!"',
      );
      setState(() => _openRouterStatus = '✅ Working!\nResponse: $resp');
    } catch (e) {
      setState(() => _openRouterStatus = '❌ Exception: $e');
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
      final resp = await ApiService.send(
        'openai',
        'chat',
        'Say "DeepSeek is working!"',
      );
      setState(() => _deepSeekStatus = '✅ Working!\nResponse: $resp');
    } catch (e) {
      setState(() => _deepSeekStatus = '❌ Exception: $e');
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
