import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../utils/theme.dart';

class SpeechToTextScreen extends StatefulWidget {
  const SpeechToTextScreen({super.key});

  @override
  State<SpeechToTextScreen> createState() => _SpeechToTextScreenState();
}

class _SpeechToTextScreenState extends State<SpeechToTextScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = 'Press the button and start speaking';
  bool _isAvailable = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (val) => print('onStatus: $val'),
      onError: (val) => print('onError: $val'),
    );
    setState(() {
      _isAvailable = available;
      if (!available) {
        _text = 'Speech recognition not available';
      }
    });
  }

  void _listen() async {
    if (!_isAvailable) {
      setState(() {
        _text = 'Speech recognition not available. Please check permissions.';
      });
      return;
    }

    if (!_isListening) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) => setState(() {
          _text = val.recognizedWords;
        }),
      );
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
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
            'Speech to Text',
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
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status indicator
                Container(
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isListening
                          ? AppTheme.accentGradient
                          : AppTheme.surfaceGradient,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: _isListening
                        ? AppTheme.accentGlow
                        : AppTheme.cardShadow,
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 64,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: AppTheme.spaceLg),

                // Status text
                Text(
                  _isListening ? 'Listening...' : 'Tap to speak',
                  style: AppTheme.bodyLarge.copyWith(
                    color: _isListening
                        ? AppTheme.accentBlueLight
                        : AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                SizedBox(height: AppTheme.space2xl),

                // Recognized text display
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppTheme.spaceLg),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppTheme.surfaceGradient),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(
                      color: AppTheme.surfaceElevated,
                      width: 1,
                    ),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  constraints: BoxConstraints(minHeight: 200),
                  child: SingleChildScrollView(
                    child: Text(
                      _text,
                      style: AppTheme.bodyLarge.copyWith(
                        fontSize: 20,
                        color: AppTheme.textPrimary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                SizedBox(height: AppTheme.spaceLg),

                // Availability status
                if (!_isAvailable)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMd,
                      vertical: AppTheme.spaceSm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 16),
                        SizedBox(width: AppTheme.spaceXs),
                        Text(
                          'Microphone not available',
                          style: AppTheme.bodySmall.copyWith(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isListening
                ? AppTheme.accentGradient
                : AppTheme.primaryGradient,
          ),
          shape: BoxShape.circle,
          boxShadow: _isListening ? AppTheme.accentGlow : AppTheme.glowShadow,
        ),
        child: FloatingActionButton(
          onPressed: _listen,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Icon(
            _isListening ? Icons.stop : Icons.mic,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}
