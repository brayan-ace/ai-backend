import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/study_plan_service.dart';
import '../services/gemini_services.dart';
import '../services/web_search_service.dart';
import '../utils/theme.dart';
import '../utils/ai_constants.dart';
import '../widgets/ai_message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/quiz_artifact_viewer.dart';

class QuizArtifact {
  final String id;
  final String title;
  final String questionType;
  final int numQuestions;
  final bool includeAnswers;
  final String gradeLevel;
  final List<QuizQuestion> questions;
  final DateTime timestamp;

  QuizArtifact({
    required this.id,
    required this.title,
    required this.questionType,
    required this.numQuestions,
    required this.includeAnswers,
    required this.gradeLevel,
    required this.questions,
    required this.timestamp,
  });

  // Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'questionType': questionType,
      'numQuestions': numQuestions,
      'includeAnswers': includeAnswers,
      'gradeLevel': gradeLevel,
      'questions': questions.map((q) => q.toFirestore()).toList(),
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  // Create from Firestore map
  factory QuizArtifact.fromFirestore(Map<String, dynamic> data) {
    return QuizArtifact(
      id: data['id'],
      title: data['title'],
      questionType: data['questionType'],
      numQuestions: data['numQuestions'],
      includeAnswers: data['includeAnswers'],
      gradeLevel: data['gradeLevel'],
      questions: (data['questions'] as List)
          .map((q) => QuizQuestion.fromFirestore(q))
          .toList(),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}

class QuizQuestion {
  final String question;
  final List<String>? options; // For MCQ
  final String? correctAnswer;
  final String? explanation;
  String? userAnswer;

  QuizQuestion({
    required this.question,
    this.options,
    this.correctAnswer,
    this.explanation,
    this.userAnswer,
  });

  // Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
    };
  }

  // Create from Firestore map
  factory QuizQuestion.fromFirestore(Map<String, dynamic> data) {
    return QuizQuestion(
      question: data['question'],
      options: data['options'] != null
          ? List<String>.from(data['options'])
          : null,
      correctAnswer: data['correctAnswer'],
      explanation: data['explanation'],
    );
  }
}

class ChatMessage {
  String text;
  final bool isUser;
  final DateTime timestamp;
  final String? imagePath;
  final bool isTyping;
  bool isStreaming;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imagePath,
    this.isTyping = false,
    this.isStreaming = false,
  });
}

class StudyPlanChatScreen extends StatefulWidget {
  final String planId;
  final String planTitle;
  final String planContext;

  const StudyPlanChatScreen({
    super.key,
    required this.planId,
    required this.planTitle,
    required this.planContext,
  });

  @override
  State<StudyPlanChatScreen> createState() => _StudyPlanChatScreenState();
}

class _StudyPlanChatScreenState extends State<StudyPlanChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _contextEditCtrl = TextEditingController();
  bool _loading = false;
  bool _domainFilterEnabled = false;
  String _domainFilter = '';

  final StudyPlanService _service = StudyPlanService();
  final GeminiService _gemini = GeminiService();

  // Speech recognition
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;

  // Response mode: 'detailed' or 'straight'
  String _responseMode = 'detailed';
  bool _showResponseModeChip = false;

  // Web search integration
  final WebSearchService _webSearchService = WebSearchService();
  bool _webSearchEnabled = false;
  bool _isSearchingWeb = false;

  // Image handling
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  String? _selectedFileName;

  // Model selection (default to Fortune for study plans)
  String _selectedModel = 'Fortune';

  // Quiz generation
  String? _userGradeLevel;
  final List<QuizArtifact> _quizArtifacts = [];
  bool _isGeneratingQuiz = false;

  @override
  void initState() {
    super.initState();
    _contextEditCtrl.text = widget.planContext;
    _speech = stt.SpeechToText();
    _initializeSpeech();
    _loadChatHistory();
    _loadPlanSettings();
    _loadQuizArtifacts(); // Load saved quizzes
    // Add welcome message
    _messages.insert(
      0,
      ChatMessage(
        text:
            'Welcome! I\'m your ${widget.planContext.toLowerCase()}. How can I help you with ${widget.planTitle}?',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _loadPlanSettings() async {
    final plans = await _service.getPlans();
    final plan = plans.firstWhere(
      (p) => p['id'] == widget.planId,
      orElse: () => {},
    );
    if (plan.isNotEmpty) {
      setState(() {
        _domainFilter = plan['domainFilter'] as String? ?? '';
        _domainFilterEnabled = _domainFilter.isNotEmpty;
      });
    }
  }

  Future<void> _loadChatHistory() async {
    final chats = await _service.getPlanChats(widget.planId);
    if (!mounted) return;

    setState(() {
      for (final chat in chats.reversed) {
        _messages.add(
          ChatMessage(
            text: chat['user'] ?? '',
            isUser: true,
            timestamp: DateTime.now(),
          ),
        );
        _messages.add(
          ChatMessage(
            text: chat['ai'] ?? '',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      }
    });
  }

  Future<void> _send() async {
    final t = _controller.text.trim();
    if (t.isEmpty) return; // Remove _loading check to allow multiple messages

    final hasImage = _selectedImage != null;
    final imageFile = _selectedImage;

    // INSTANT FEEDBACK: Show user message immediately
    setState(() {
      _messages.insert(
        0,
        ChatMessage(
          text: t,
          isUser: true,
          timestamp: DateTime.now(),
          imagePath: hasImage ? imageFile?.path : null,
        ),
      );
      _controller.clear(); // Clear input immediately
      _selectedImage = null;
      _selectedFileName = null;
    });

    // Add typing indicator immediately
    setState(() {
      _messages.insert(
        0,
        ChatMessage(
          text: '',
          isUser: false,
          timestamp: DateTime.now(),
          isTyping: true,
        ),
      );
    });

    // Check domain filter (skip if image attached)
    if (_domainFilterEnabled && _domainFilter.isNotEmpty && !hasImage) {
      final filterPrompt =
          'User asked about: "$t". Is this related to $_domainFilter? Answer only "yes" or "no".';
      final filterCheck = await _gemini.generateContent(filterPrompt);

      if (filterCheck != null && !filterCheck.toLowerCase().contains('yes')) {
        if (!mounted) return;
        setState(() {
          // Remove typing indicator
          if (_messages.isNotEmpty && _messages.first.isTyping) {
            _messages.removeAt(0);
          }
          _messages.insert(
            0,
            ChatMessage(
              text:
                  'I can only help with questions related to $_domainFilter. Please ask a question within this domain.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
        return;
      }
    }

    String? response;

    // If image is attached, use Gemini Vision API
    if (hasImage && imageFile != null) {
      try {
        print('========================================');
        print('[STUDY PLAN] Processing image for Gemini Vision API');
        print('Image path: ${imageFile.path}');
        print('Image file exists: ${await imageFile.exists()}');

        // Convert image to base64
        final bytes = await imageFile.readAsBytes();
        print('Image bytes read: ${bytes.length} bytes');

        final base64Image = base64Encode(bytes);
        print('Base64 encoded successfully: ${base64Image.length} characters');
        print(
          'Base64 preview (first 50 chars): ${base64Image.substring(0, base64Image.length > 50 ? 50 : base64Image.length)}...',
        );

        // Determine mime type
        String mimeType = 'image/jpeg';
        if (imageFile.path.toLowerCase().endsWith('.png')) {
          mimeType = 'image/png';
        } else if (imageFile.path.toLowerCase().endsWith('.gif')) {
          mimeType = 'image/gif';
        } else if (imageFile.path.toLowerCase().endsWith('.webp')) {
          mimeType = 'image/webp';
        }
        print('Detected mime type: $mimeType');

        // Add context to the prompt for study plans
        final contextualPrompt =
            '${widget.planContext}\n\nUser question about the image: $t';
        print(
          'Prompt: ${contextualPrompt.substring(0, contextualPrompt.length > 100 ? 100 : contextualPrompt.length)}...',
        );
        print('Calling Gemini Vision API...');
        print('========================================');

        response = await _gemini.generateContentWithImage(
          prompt: contextualPrompt,
          base64Image: base64Image,
          mimeType: mimeType,
        );

        print(
          'Response received: ${response != null ? response.substring(0, response.length > 100 ? 100 : response.length) : ''}...',
        );
      } catch (e, stackTrace) {
        print('ERROR processing image: $e');
        print('Stack trace: $stackTrace');
        response = '⚠️ Error processing image: $e';
      }
    } else {
      // Handle web search if enabled
      if (_webSearchEnabled) {
        setState(() => _isSearchingWeb = true);
        try {
          final searchResults = await _webSearchService.search(query: t);
          setState(() => _isSearchingWeb = false);

          // Build conversation history (last 20 messages for better context)
          final all = _messages.skip(1).toList().reversed.toList();
          const int maxItems = 20; // Increased from 10 to 20 for better memory
          final recent = all.length > maxItems
              ? all.sublist(all.length - maxItems)
              : all;
          final sb = StringBuffer();
          for (final m in recent) {
            sb.writeln(m.isUser ? 'User: ${m.text}' : 'AI: ${m.text}');
          }

          final modePrompt = _responseMode == 'detailed'
              ? AiConstants.systemPrompt
              : 'Provide a direct, concise answer without extra details or examples.';

          final enhancedPrompt =
              '''$modePrompt

${widget.planContext}

Conversation:
${sb.toString().trim()}

Web Search Results:
$searchResults

Based on the above web search results and conversation context, please answer: $t''';

          response = await _gemini.generateContentWithContext(
            t,
            enhancedPrompt,
          );
        } catch (e) {
          setState(() => _isSearchingWeb = false);
          response = '⚠️ Web search error: $e\n\nTrying AI database...';

          // Fallback to normal AI
          final all = _messages.skip(1).toList().reversed.toList();
          const int maxItems = 20; // Increased from 10 to 20 for better memory
          final recent = all.length > maxItems
              ? all.sublist(all.length - maxItems)
              : all;
          final sb = StringBuffer();
          for (final m in recent) {
            sb.writeln(m.isUser ? 'User: ${m.text}' : 'AI: ${m.text}');
          }

          final modePrompt = _responseMode == 'detailed'
              ? AiConstants.systemPrompt
              : 'Provide a direct, concise answer without extra details or examples.';

          final systemContext =
              '$modePrompt\n\n${widget.planContext}\n\nConversation:\n${sb.toString().trim()}';
          response = await _gemini.generateContentWithContext(t, systemContext);
        }
      } else {
        // No image, use regular text API with conversation history
        // Build recent conversation history (exclude the newly inserted user message at index 0)
        final all = _messages
            .skip(1)
            .toList()
            .reversed
            .toList(); // oldest -> newest, without current user
        const int maxItems = 20; // Increased from 10 to 20 for better memory
        final recent = all.length > maxItems
            ? all.sublist(all.length - maxItems)
            : all;
        final sb = StringBuffer();
        for (final m in recent) {
          sb.writeln(m.isUser ? 'User: ${m.text}' : 'AI: ${m.text}');
        }

        // Use response mode to determine system prompt
        final modePrompt = _responseMode == 'detailed'
            ? AiConstants.systemPrompt
            : 'Provide a direct, concise answer without extra details or examples.';

        final systemContext =
            '$modePrompt\n\n${widget.planContext}\n\nConversation:\n${sb.toString().trim()}';

        // Get AI response with custom context and recent history
        response = await _gemini.generateContentWithContext(t, systemContext);

        // Check if should suggest web search
        if (response != null && _shouldSuggestWebSearch(response, t)) {
          if (!mounted) return;

          setState(() {
            // Remove typing indicator first
            if (_messages.isNotEmpty && _messages.first.isTyping) {
              _messages.removeAt(0);
            }
            _messages.insert(
              0,
              ChatMessage(
                text: response!,
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });

          // Ask user if they want web search
          final wantWebSearch = await _showWebSearchDialog();
          if (wantWebSearch == true) {
            setState(() {
              _messages.insert(
                0,
                ChatMessage(
                  text: '🔍 Searching the web...',
                  isUser: false,
                  timestamp: DateTime.now(),
                ),
              );
              _isSearchingWeb = true;
            });

            try {
              final searchResults = await _webSearchService.search(query: t);
              setState(() => _isSearchingWeb = false);

              final enhancedPrompt =
                  '''$modePrompt

${widget.planContext}

Conversation:
${sb.toString().trim()}

Web Search Results:
$searchResults

Based on the above web search results, please answer: $t''';

              response = await _gemini.generateContentWithContext(
                t,
                enhancedPrompt,
              );

              // Remove search indicator
              setState(() {
                if (_messages.isNotEmpty &&
                    _messages.first.text == '🔍 Searching the web...') {
                  _messages.removeAt(0);
                }
              });
            } catch (e) {
              setState(() {
                _isSearchingWeb = false;
                // Remove search indicator
                if (_messages.isNotEmpty &&
                    _messages.first.text == '🔍 Searching the web...') {
                  _messages.removeAt(0);
                }
              });
              response = '⚠️ Web search failed: $e';
            }
          } else {
            // User declined (response already added)
            return;
          }
        }
      }
    }

    if (!mounted) return;

    // Remove typing indicator
    setState(() {
      if (_messages.isNotEmpty && _messages.first.isTyping) {
        _messages.removeAt(0);
      }
    });

    if (response != null) {
      // Stream the response character by character
      await _streamResponse(response, t);
    } else {
      setState(() {
        _messages.insert(
          0,
          ChatMessage(
            text: 'Error: Could not get response',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    }
  }

  Future<void> _streamResponse(String fullResponse, String userMessage) async {
    // Add empty streaming message
    final streamingMessage = ChatMessage(
      text: '',
      isUser: false,
      timestamp: DateTime.now(),
      isStreaming: true,
    );

    setState(() {
      _messages.insert(0, streamingMessage);
    });

    // Stream response word by word for smooth effect
    final words = fullResponse.split(' ');
    final buffer = StringBuffer();

    for (int i = 0; i < words.length; i++) {
      if (!mounted) return;

      buffer.write(words[i]);
      if (i < words.length - 1) buffer.write(' ');

      setState(() {
        streamingMessage.text = buffer.toString();
      });

      // Delay between words (adjust for speed)
      await Future.delayed(Duration(milliseconds: 30));
    }

    // Mark streaming as complete
    if (!mounted) return;
    setState(() {
      streamingMessage.isStreaming = false;
    });

    // Save to history
    _service.saveChatMessage(widget.planId, userMessage, fullResponse);
  }

  Widget _buildQuizOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? AppTheme.accentGradient
                      .map((c) => c.withOpacity(0.2))
                      .toList()
                : AppTheme.glassGradient,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentBlue
                : AppTheme.surfaceElevated.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spaceXs),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accentBlue.withOpacity(0.2)
                    : AppTheme.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppTheme.accentBlue : AppTheme.textTertiary,
                size: 28,
              ),
            ),
            SizedBox(height: AppTheme.spaceXs),
            Text(
              title,
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showGradeLevelDialog() async {
    final gradeLevels = [
      'Grade 7',
      'Grade 8',
      'Grade 9',
      'Grade 10',
      'Grade 11',
      'Grade 12',
      'University',
      'Adult Learner',
      'Other',
    ];

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: 450),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: AppTheme.surfaceGradient),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: AppTheme.surfaceElevated.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.2),
                blurRadius: 30,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppTheme.primaryGradient),
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.glowShadow,
                  ),
                  child: Icon(Icons.school, color: Colors.white, size: 32),
                ),
                SizedBox(height: AppTheme.spaceMd),
                Text(
                  'Select Your Grade Level',
                  style: AppTheme.headlineMedium.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: AppTheme.spaceXs),
                Text(
                  'This helps generate appropriate questions',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),
                Divider(color: AppTheme.surfaceElevated),
                SizedBox(height: AppTheme.spaceSm),

                // Grade level options
                ...gradeLevels.map(
                  (grade) => Padding(
                    padding: EdgeInsets.only(bottom: AppTheme.spaceXs),
                    child: InkWell(
                      onTap: () => Navigator.pop(context, grade),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      child: Container(
                        padding: EdgeInsets.all(AppTheme.spaceMd),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppTheme.glassGradient,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          border: Border.all(
                            color: AppTheme.surfaceElevated.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_forward_ios,
                              color: AppTheme.primaryBlue,
                              size: 16,
                            ),
                            SizedBox(width: AppTheme.spaceSm),
                            Text(
                              grade,
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generateQuizWithWebSearch({
    required String questionType,
    required int numQuestions,
    required bool includeAnswers,
  }) async {
    // Show loading state
    setState(() => _isGeneratingQuiz = true);

    // Add loading message to chat
    final loadingMessage = ChatMessage(
      text: '🎯 Generating your quiz...',
      isUser: false,
      timestamp: DateTime.now(),
      isTyping: true,
    );
    setState(() => _messages.insert(0, loadingMessage));

    try {
      // Extract topics from conversation
      final topics = _extractTopicsFromConversation();
      print('Extracted topics: $topics');

      // Build conversation context
      final conversationContext = _buildConversationContext();

      // Perform web search for quality questions
      String searchResults = '';
      try {
        final searchQuery =
            '$_userGradeLevel ${topics.join(' ')} quiz questions practice';
        print('Performing web search: "$searchQuery"');
        searchResults = await _webSearchService.search(query: searchQuery);
        print(
          '✓ Web search completed - ${searchResults.length} characters of results',
        );
        if (searchResults.isNotEmpty) {
          print(
            'Search preview: ${searchResults.substring(0, searchResults.length > 150 ? 150 : searchResults.length)}...',
          );
        }
      } catch (e) {
        print('✗ Web search failed: $e');
        print('Continuing without web search results');
        // Continue without web search
      }

      // Build comprehensive AI prompt - SEPARATE prompts for MCQ vs Full Text
      final aiPrompt = questionType == 'MCQ'
          ? '''
Create $numQuestions multiple choice quiz questions about: ${topics.join(', ')}
Grade Level: $_userGradeLevel

Context:
$conversationContext

${searchResults.isNotEmpty ? 'Reference:\n$searchResults\n\n' : ''}

FORMAT - Use this EXACT format:

**Question 1:** What is photosynthesis?
A) Process of breathing
B) Process of making food
C) Process of digestion
D) Process of excretion${includeAnswers ? '\n**Correct Answer:** B\n**Explanation:** Photosynthesis is how plants make food using sunlight.' : ''}

**Question 2:** Where does photosynthesis occur?
A) Roots
B) Stem  
C) Leaves
D) Flowers${includeAnswers ? '\n**Correct Answer:** C\n**Explanation:** Photosynthesis happens in the leaves where chlorophyll is present.' : ''}

Now create $numQuestions questions following this EXACT format with **Question 1:**, **Question 2:**, etc.
'''
          : '''
Create $numQuestions open-ended quiz questions about: ${topics.join(', ')}
Grade Level: $_userGradeLevel

Context:
$conversationContext

${searchResults.isNotEmpty ? 'Reference:\n$searchResults\n\n' : ''}

FORMAT - Use this EXACT format:

**Question 1:** Explain the process of photosynthesis in detail.${includeAnswers ? '\n**Answer:** Photosynthesis is the process by which plants convert light energy into chemical energy...\n**Explanation:** This process is vital for life on Earth.' : ''}

**Question 2:** Describe the water cycle and its importance.${includeAnswers ? '\n**Answer:** The water cycle involves evaporation, condensation, precipitation...\n**Explanation:** It regulates Earth\'s water distribution.' : ''}

Now create $numQuestions questions following this EXACT format with **Question 1:**, **Question 2:**, etc.
''';

      print('Calling Gemini API for quiz generation...');
      print('Prompt length: ${aiPrompt.length} characters');

      // Generate quiz with AI
      final quizResponse = await _gemini.generateContentWithContext(
        'Generate quiz',
        aiPrompt,
      );

      print('Received response from Gemini');
      print('Response length: ${quizResponse?.length ?? 0} characters');
      print(
        'Response preview: ${quizResponse?.substring(0, quizResponse.length > 200 ? 200 : quizResponse.length)}...',
      );

      if (quizResponse != null && quizResponse.isNotEmpty && mounted) {
        print('Parsing quiz response...');

        // Parse questions with requested count limit
        final questions = _parseQuizResponse(
          quizResponse,
          questionType,
          numQuestions,
        );
        print('Parsed ${questions.length} questions');

        if (questions.isEmpty) {
          // Don't throw - show user-friendly message instead
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '❌ Could not parse quiz. Please try again with a simpler topic.',
                ),
                backgroundColor: AppTheme.error,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return; // Exit early without creating artifact
        }

        // Warn if question count doesn't match but continue anyway
        if (questions.length != numQuestions) {
          print(
            '⚠️ WARNING: Requested $numQuestions questions but got ${questions.length} (continuing anyway)',
          );
        }

        // Create artifact
        final artifact = QuizArtifact(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Quiz: ${topics.isNotEmpty ? topics.first : widget.planTitle}',
          questionType: questionType,
          numQuestions: numQuestions,
          includeAnswers: includeAnswers,
          gradeLevel: _userGradeLevel!,
          questions: questions,
          timestamp: DateTime.now(),
        );

        // Remove loading message
        setState(() {
          _messages.removeWhere((m) => m.text == '🎯 Generating your quiz...');
          _quizArtifacts.add(artifact);
        });

        // Save to Firebase
        await _saveQuizArtifact(artifact);

        // Add artifact preview to chat
        await _addQuizArtifactToChat(artifact);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Quiz generated! ${questions.length}/${numQuestions} questions',
              ),
              backgroundColor: AppTheme.primaryBlue,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('AI returned empty response');
      }
    } catch (e) {
      print('Error generating quiz: $e');

      // Remove loading message
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.text == '🎯 Generating your quiz...');
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate quiz: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      // Always remove loading state
      if (mounted) {
        setState(() => _isGeneratingQuiz = false);
      }
    }
  }

  List<String> _extractTopicsFromConversation() {
    final topics = <String>{};
    final stopWords = {
      'what',
      'how',
      'why',
      'when',
      'where',
      'who',
      'which',
      'the',
      'is',
      'are',
      'was',
      'were',
      'can',
      'could',
      'will',
      'would',
      'should',
    };

    // Look at LAST 5 user messages (most recent conversation)
    final userMessages = _messages
        .where((m) => m.isUser && !m.isTyping)
        .take(5);

    for (final msg in userMessages) {
      // Extract capitalized words and longer meaningful words
      final words = msg.text.split(RegExp(r'\s+'));
      for (final word in words) {
        final cleanWord = word.replaceAll(RegExp(r'[^a-zA-Z]'), '');
        // Add if: longer than 4 chars, not a stop word, or is capitalized (proper noun)
        if (cleanWord.length > 4 &&
            !stopWords.contains(cleanWord.toLowerCase())) {
          topics.add(cleanWord);
        } else if (cleanWord.length > 2 &&
            RegExp(r'^[A-Z]').hasMatch(cleanWord)) {
          topics.add(cleanWord); // Add capitalized words (proper nouns)
        }
      }
    }

    // Fallback to plan title if no topics found
    if (topics.isEmpty) {
      final titleWords = widget.planTitle.split(' ');
      topics.addAll(titleWords.where((w) => w.length > 3));
    }

    print('Extracted topics: ${topics.take(5).join(", ")}');
    return topics.take(5).toList();
  }

  String _buildConversationContext() {
    final buffer = StringBuffer();
    final recentMessages = _messages.reversed.take(20).toList();

    for (final msg in recentMessages) {
      if (!msg.isTyping && !msg.isStreaming) {
        buffer.writeln(msg.isUser ? 'Student: ${msg.text}' : 'AI: ${msg.text}');
      }
    }

    return buffer.toString();
  }

  List<QuizQuestion> _parseQuizResponse(
    String response,
    String questionType,
    int requestedCount,
  ) {
    final questions = <QuizQuestion>[];
    print('\n=== PARSING QUIZ RESPONSE ===');
    print('Response length: ${response.length}');
    print('Question type: $questionType');
    print('Requested questions: $requestedCount');
    print('\n--- RESPONSE PREVIEW (first 500 chars) ---');
    print(response.substring(0, response.length > 500 ? 500 : response.length));
    print('--- END PREVIEW ---\n');

    // Try multiple patterns to match different AI response formats
    // More lenient to catch various question formats
    List<RegExp> questionPatterns = [
      // Pattern 1: **Question 1:** or **Question 1** (most common)
      RegExp(r'^\s*\*\*Question\s+(\d+):?\*\*\s*(.+?)$', multiLine: true),
      // Pattern 2: Question 1: or Question 1. (without bold)
      RegExp(r'^\s*Question\s+(\d+)[:.]\s*(.+?)$', multiLine: true),
      // Pattern 3: 1. Question format (numbered list) - more lenient
      RegExp(r'^\s*(\d+)\.\s+([A-Z].{10,}?)$', multiLine: true),
      // Pattern 4: ### Question 1 (markdown heading)
      RegExp(r'^\s*#{1,3}\s*Question\s+(\d+):?\s*(.+?)$', multiLine: true),
      // Pattern 5: Q1: or Q1. format
      RegExp(r'^\s*Q(\d+)[:.]\s*(.+?)$', multiLine: true),
      // Pattern 6: Just number with ) at start
      RegExp(r'^\s*(\d+)\)\s+([A-Z].{10,}?)$', multiLine: true),
    ];

    List<Match> matches = [];

    for (int i = 0; i < questionPatterns.length; i++) {
      matches = questionPatterns[i].allMatches(response).toList();
      if (matches.isNotEmpty) {
        print('✓ Matched with pattern ${i + 1}');
        break;
      }
    }

    print('Found ${matches.length} question matches');

    if (matches.isEmpty) {
      print('\n❌ NO QUESTIONS MATCHED');
      print('Expected format: **Question 1:** Your question here?');
      print(
        'Actual format: ${response.substring(0, response.length > 100 ? 100 : response.length)}',
      );
      print('\nTrying to parse anyway with lenient patterns...');

      // Try super lenient pattern as last resort
      final fallbackPattern = RegExp(
        r'(\d+)\s+([A-Z].+?)\n\s*[A-D]\)',
        multiLine: true,
      );
      matches = fallbackPattern.allMatches(response).toList();
      if (matches.isNotEmpty) {
        print('✓ Found ${matches.length} questions with fallback pattern');
      } else {
        print('\nFull response dump:');
        print(response);
        print('--- END DUMP ---');
      }
    }

    for (final match in matches) {
      // Stop if we've reached the requested number of questions
      if (questions.length >= requestedCount) {
        print('\n✓ Reached requested count ($requestedCount) - stopping parse');
        break;
      }

      final questionNum = match.group(1);
      final questionText = match.group(2)?.trim() ?? '';
      print('Processing Question $questionNum');

      if (questionText.isEmpty) continue;

      if (questionType == 'MCQ') {
        // Extract options A), B), C), D)
        final optionPattern = RegExp(r'([A-D])\)\s*([^\n]+)', multiLine: true);
        final optionsMap = <String, String>{}; // Use map to ensure unique A-D

        // Find the section containing this question
        final currentPos = response.indexOf(match.group(0)!);

        // Find the next question to determine the boundary
        // Match only at start of line to avoid matching in explanation text
        final nextQuestionPattern = RegExp(
          r'^\s*(\*\*Question\s+\d+|Question\s+\d+|\d+\.\s)',
          multiLine: true,
        );
        final remainingText = response.substring(
          currentPos + match.group(0)!.length,
        );
        final nextMatch = nextQuestionPattern.firstMatch(remainingText);

        final endIndex = nextMatch != null
            ? currentPos + match.group(0)!.length + nextMatch.start
            : response.length;

        final questionSection = response.substring(currentPos, endIndex);
        final optionMatches = optionPattern.allMatches(questionSection);

        // Extract only first occurrence of each A, B, C, D
        for (final optMatch in optionMatches) {
          final letter = optMatch.group(1)!;
          final optionText = optMatch.group(2)?.trim() ?? '';
          if (optionText.isNotEmpty && !optionsMap.containsKey(letter)) {
            optionsMap[letter] = optionText;
          }
        }

        // Convert to list in A, B, C, D order
        final options = <String>[];
        for (final letter in ['A', 'B', 'C', 'D']) {
          if (optionsMap.containsKey(letter)) {
            options.add(optionsMap[letter]!);
          }
        }

        print('Extracted ${options.length} options');
        print('Question section for answer parsing:');
        print(questionSection);

        // Extract answer if present (search in the question section)
        String? correctAnswer;
        String? explanation;

        // Try multiple answer formats - more lenient
        List<RegExp> answerPatterns = [
          // Standard: **Correct Answer:** B or **Correct Answer:** B)
          RegExp(
            r'\*\*(?:Correct\s+)?Answer:?\*\*\s*([A-D])',
            multiLine: true,
            caseSensitive: false,
          ),
          // Answer: B format
          RegExp(r'Answer:\s*([A-D])', multiLine: true, caseSensitive: false),
          // Correct: B format
          RegExp(r'Correct:\s*([A-D])', multiLine: true, caseSensitive: false),
        ];

        for (var pattern in answerPatterns) {
          final answerMatch = pattern.firstMatch(questionSection);
          if (answerMatch != null) {
            correctAnswer = answerMatch.group(1)?.toUpperCase();
            print('✓ Found correct answer: $correctAnswer');
            break;
          }
        }

        if (correctAnswer == null) {
          print('⚠️ WARNING: No correct answer found in section!');
        }

        final explanationPattern = RegExp(
          r'\*\*Explanation:?\*\*\s*([^\n]+(?:\n(?!\*\*)[^\n]+)*)',
          multiLine: true,
        );
        final explanationMatch = explanationPattern.firstMatch(questionSection);
        if (explanationMatch != null) {
          explanation = explanationMatch.group(1)?.trim();
          print(
            'Found explanation: ${explanation?.substring(0, explanation.length > 50 ? 50 : explanation.length)}...',
          );
        }

        // Only add if we have exactly 4 options
        if (options.length == 4) {
          questions.add(
            QuizQuestion(
              question: questionText.split('\n').first.trim(),
              options: options,
              correctAnswer: correctAnswer,
              explanation: explanation,
            ),
          );
          print('✓ Added MCQ question ${questions.length}');
        } else {
          print('⚠️ Skipped - has ${options.length} options (need 4)');
        }
      } else {
        // Full text question
        String? answer;
        String? explanation;

        // Find the section containing this question
        final currentPos = response.indexOf(match.group(0)!);
        // Match only at start of line to avoid matching in explanation text
        final nextQuestionPattern = RegExp(
          r'^\s*(\*\*Question\s+\d+|Question\s+\d+|\d+\.\s)',
          multiLine: true,
        );
        final remainingText = response.substring(
          currentPos + match.group(0)!.length,
        );
        final nextMatch = nextQuestionPattern.firstMatch(remainingText);

        final endIndex = nextMatch != null
            ? currentPos + match.group(0)!.length + nextMatch.start
            : response.length;

        final questionSection = response.substring(currentPos, endIndex);

        final answerMatch = RegExp(
          r'\*\*Answer:?\*\*\s*([^\n]+(?:\n(?!\*\*)[^\n]+)*)',
          multiLine: true,
        ).firstMatch(questionSection);
        if (answerMatch != null) {
          answer = answerMatch.group(1)?.trim();
        }

        final explanationMatch = RegExp(
          r'\*\*Explanation:?\*\*\s*([^\n]+(?:\n(?!\*\*)[^\n]+)*)',
          multiLine: true,
        ).firstMatch(questionSection);
        if (explanationMatch != null) {
          explanation = explanationMatch.group(1)?.trim();
        }

        questions.add(
          QuizQuestion(
            question: questionText.trim(),
            correctAnswer: answer,
            explanation: explanation,
          ),
        );
        print('✓ Added Full Text question ${questions.length}');
      }
    }

    print('\n=== PARSING COMPLETE ===');
    print('Successfully parsed: ${questions.length} questions');

    if (questions.isEmpty) {
      print('\n⚠️ WARNING: No questions were parsed!');
      print(
        'This usually means the AI response format doesn\'t match expected patterns.',
      );
      print(
        'Response starts with: ${response.substring(0, response.length > 200 ? 200 : response.length)}',
      );
    }

    return questions;
  }

  Future<void> _addQuizArtifactToChat(QuizArtifact artifact) async {
    // Add a special message that represents the quiz artifact
    setState(() {
      _messages.insert(
        0,
        ChatMessage(
          text:
              '🎯 Quiz Generated: ${artifact.title}\n'
              '${artifact.questions.length} ${artifact.questionType} questions • ${artifact.gradeLevel}\n'
              'Tap to view and take the quiz',
          isUser: false,
          timestamp: artifact.timestamp,
        ),
      );
    });
  }

  // Save quiz artifact to Firebase
  Future<void> _saveQuizArtifact(QuizArtifact artifact) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not authenticated - skipping quiz save');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('study_plans')
          .doc(widget.planId)
          .collection('quizzes')
          .doc(artifact.id)
          .set(artifact.toFirestore());

      print('✅ Quiz saved to Firebase: ${artifact.id}');
    } catch (e) {
      print('Error saving quiz to Firebase: $e');
    }
  }

  // Load quiz artifacts from Firebase
  Future<void> _loadQuizArtifacts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not authenticated - skipping quiz load');
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('study_plans')
          .doc(widget.planId)
          .collection('quizzes')
          .orderBy('timestamp', descending: true)
          .get();

      if (snapshot.docs.isNotEmpty && mounted) {
        setState(() {
          _quizArtifacts.clear();
          for (final doc in snapshot.docs) {
            try {
              final artifact = QuizArtifact.fromFirestore(doc.data());
              _quizArtifacts.add(artifact);

              // Add to chat messages
              _messages.insert(
                0,
                ChatMessage(
                  text:
                      '🎯 Quiz Generated: ${artifact.title}\n'
                      '${artifact.numQuestions} ${artifact.questionType} questions • ${artifact.gradeLevel}\n'
                      'Tap to view and take the quiz',
                  isUser: false,
                  timestamp: artifact.timestamp,
                ),
              );
            } catch (e) {
              print('Error parsing quiz ${doc.id}: $e');
            }
          }
        });
        print('✅ Loaded ${_quizArtifacts.length} quizzes from Firebase');
      }
    } catch (e) {
      print('Error loading quizzes from Firebase: $e');
    }
  }

  bool _shouldSuggestWebSearch(String response, String query) {
    final lowerResponse = response.toLowerCase();

    // Check if AI mentions lack of information
    if (lowerResponse.contains('don\'t have') ||
        lowerResponse.contains('cannot provide') ||
        lowerResponse.contains('do not have information') ||
        lowerResponse.contains('my knowledge was last updated') ||
        lowerResponse.contains('as of my last update') ||
        lowerResponse.contains('i don\'t have access')) {
      return true;
    }

    // Check if query suggests need for current information
    return _webSearchService.shouldSuggestWebSearch(query);
  }

  Future<bool?> _showWebSearchDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.3)),
          ),
          title: Row(
            children: [
              Icon(Icons.travel_explore, color: AppTheme.primaryBlue),
              SizedBox(width: AppTheme.spaceSm),
              Text(
                'Search the Web?',
                style: AppTheme.headlineMedium.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'I may not have the latest information. Would you like me to search the web for current data?',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'No, thanks',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              child: Text('Yes, search web'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showQuizDialog() async {
    String questionType = 'MCQ';
    int numQuestions = 6;
    bool includeAnswers = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: AppTheme.surfaceGradient),
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(
                color: AppTheme.surfaceElevated.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentBlue.withOpacity(0.2),
                  blurRadius: 30,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spaceLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(AppTheme.spaceSm),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: AppTheme.accentGradient,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                            boxShadow: AppTheme.accentGlow,
                          ),
                          child: Icon(
                            Icons.quiz,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        SizedBox(width: AppTheme.spaceMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Generate Quiz',
                                style: AppTheme.headlineMedium.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Create personalized practice questions',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppTheme.spaceLg),
                    Divider(color: AppTheme.surfaceElevated),
                    SizedBox(height: AppTheme.spaceLg),

                    // Question Type
                    Text(
                      'Question Type',
                      style: AppTheme.labelLarge.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: AppTheme.spaceSm),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuizOptionCard(
                            icon: Icons.radio_button_checked,
                            title: 'MCQ',
                            subtitle: 'Multiple choice',
                            isSelected: questionType == 'MCQ',
                            onTap: () =>
                                setDialogState(() => questionType = 'MCQ'),
                          ),
                        ),
                        SizedBox(width: AppTheme.spaceSm),
                        Expanded(
                          child: _buildQuizOptionCard(
                            icon: Icons.text_fields,
                            title: 'Full Text',
                            subtitle: 'Open-ended',
                            isSelected: questionType == 'Full Text',
                            onTap: () => setDialogState(
                              () => questionType = 'Full Text',
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppTheme.spaceLg),

                    // Number of Questions
                    Text(
                      'Number of Questions',
                      style: AppTheme.labelLarge.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: AppTheme.spaceSm),
                    Container(
                      padding: EdgeInsets.all(AppTheme.spaceMd),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppTheme.glassGradient,
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: AppTheme.surfaceElevated.withOpacity(0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Select: $numQuestions questions',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppTheme.spaceSm,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: AppTheme.accentGradient,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSm,
                                  ),
                                ),
                                child: Text(
                                  numQuestions.toString(),
                                  style: AppTheme.labelLarge.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: numQuestions.toDouble(),
                            min: 1,
                            max: 20,
                            divisions: 19,
                            activeColor: AppTheme.primaryBlue,
                            inactiveColor: AppTheme.surfaceElevated.withOpacity(
                              0.5,
                            ),
                            onChanged: (v) =>
                                setDialogState(() => numQuestions = v.toInt()),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppTheme.spaceLg),

                    // Include Answers Toggle
                    Container(
                      padding: EdgeInsets.all(AppTheme.spaceMd),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppTheme.glassGradient,
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: AppTheme.surfaceElevated.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(AppTheme.spaceXs),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm,
                              ),
                            ),
                            child: Icon(
                              Icons.check_circle_outline,
                              color: includeAnswers
                                  ? AppTheme.primaryBlue
                                  : AppTheme.textTertiary,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: AppTheme.spaceSm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Include Answers',
                                  style: AppTheme.bodyLarge.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Show correct answers with explanations',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: includeAnswers,
                            onChanged: (v) =>
                                setDialogState(() => includeAnswers = v),
                            activeColor: AppTheme.primaryBlue,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppTheme.spaceLg),
                    Divider(color: AppTheme.surfaceElevated),
                    SizedBox(height: AppTheme.spaceMd),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
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
                              'Cancel',
                              style: AppTheme.labelLarge.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: AppTheme.spaceSm),
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppTheme.accentGradient,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd,
                              ),
                              boxShadow: AppTheme.accentGlow,
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context, {
                                  'questionType': questionType,
                                  'numQuestions': numQuestions,
                                  'includeAnswers': includeAnswers,
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: EdgeInsets.symmetric(
                                  vertical: AppTheme.spaceMd,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.auto_awesome, size: 20),
                                  SizedBox(width: AppTheme.spaceXs),
                                  Text(
                                    'Generate Quiz',
                                    style: AppTheme.labelLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (result != null) {
      // Check if this is the first quiz - ask for grade level
      if (_userGradeLevel == null) {
        final gradeLevel = await _showGradeLevelDialog();
        if (gradeLevel == null) return; // User cancelled
        setState(() => _userGradeLevel = gradeLevel);
      }

      // Generate quiz with selected options
      await _generateQuizWithWebSearch(
        questionType: result['questionType'],
        numQuestions: result['numQuestions'],
        includeAnswers: result['includeAnswers'],
      );
    }
  }

  Future<void> _showEditDescriptionDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Description'),
        content: TextField(
          controller: _contextEditCtrl,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Edit the AI role and context...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newContext = _contextEditCtrl.text.trim();
              if (newContext.isNotEmpty) {
                await _service.updatePlan(
                  id: widget.planId,
                  context: newContext,
                );
                if (!mounted) return;
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilterDialog() async {
    String tempDomain = _domainFilter;
    bool tempEnabled = _domainFilterEnabled;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Domain Filter'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text('Enable Domain Filter'),
                value: tempEnabled,
                onChanged: (v) {
                  setDialogState(() => tempEnabled = v ?? false);
                },
              ),
              if (tempEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Domain (e.g., Biology, Mathematics)',
                      border: OutlineInputBorder(),
                    ),
                    controller: TextEditingController(text: tempDomain),
                    onChanged: (v) => tempDomain = v,
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'When enabled, the AI will only answer questions related to the specified domain.',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _service.updatePlan(
                  id: widget.planId,
                  domainFilter: tempEnabled ? tempDomain : '',
                );
                setState(() {
                  _domainFilter = tempDomain;
                  _domainFilterEnabled = tempEnabled;
                });
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // Speech Recognition Methods
  Future<void> _initializeSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' && _isListening) {
            _startListening();
          }
        },
        onError: (error) {
          if (_isListening) {
            setState(() => _isListening = false);
          }
        },
      );
      setState(() {});
    } catch (e) {
      _speechAvailable = false;
    }
  }

  void _toggleListening() {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    } else {
      _startListening();
    }
  }

  void _startListening() {
    if (!_speechAvailable) return;
    _speech.listen(
      onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
        });
      },
      listenFor: const Duration(minutes: 10),
      pauseFor: const Duration(minutes: 2),
      partialResults: true,
      cancelOnError: false,
      listenMode: stt.ListenMode.dictation,
    );
    setState(() => _isListening = true);
  }

  void _showResponseModeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          side: BorderSide(color: AppTheme.surfaceElevated, width: 1),
        ),
        title: Text(
          'Options',
          style: AppTheme.headlineMedium.copyWith(color: AppTheme.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Response Mode Section
              Text(
                'Response Mode',
                style: AppTheme.labelLarge.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              SizedBox(height: AppTheme.spaceXs),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppTheme.accentGradient),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white),
                ),
                title: Text(
                  'Detailed Analysis',
                  style: AppTheme.labelLarge.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Comprehensive explanations',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                selected: _responseMode == 'detailed',
                selectedTileColor: AppTheme.primaryBlue.withOpacity(0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                onTap: () {
                  setState(() => _responseMode = 'detailed');
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✓ Detailed Analysis activated'),
                      backgroundColor: AppTheme.primaryBlue,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              SizedBox(height: AppTheme.spaceXs),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppTheme.accentGradient),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white),
                ),
                title: Text(
                  'Straight to the Point',
                  style: AppTheme.labelLarge.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Direct answers',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                selected: _responseMode == 'straight',
                selectedTileColor: AppTheme.primaryBlue.withOpacity(0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                onTap: () {
                  setState(() => _responseMode = 'straight');
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('⚡ Straight to the Point activated'),
                      backgroundColor: AppTheme.accentBlue,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),

              SizedBox(height: AppTheme.spaceLg),
              Divider(color: AppTheme.surfaceElevated),
              SizedBox(height: AppTheme.spaceSm),

              // Web Search Section
              Text(
                'Search Options',
                style: AppTheme.labelLarge.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              SizedBox(height: AppTheme.spaceXs),
              StatefulBuilder(
                builder: (context, setDialogState) => ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(AppTheme.spaceSm),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF00D9FF), Color(0xFF0099FF)],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Icon(Icons.travel_explore, color: Colors.white),
                  ),
                  title: Text(
                    'Web Search',
                    style: AppTheme.labelLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    _webSearchEnabled
                        ? 'Real-time data enabled'
                        : 'Using AI database',
                    style: AppTheme.bodySmall.copyWith(
                      color: _webSearchEnabled
                          ? AppTheme.primaryBlue
                          : AppTheme.textSecondary,
                    ),
                  ),
                  trailing: Switch(
                    value: _webSearchEnabled,
                    onChanged: (value) {
                      setState(() => _webSearchEnabled = value);
                      setDialogState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? '\ud83c\udf10 Web search enabled'
                                : '\ud83d\udcda Using AI database',
                          ),
                          backgroundColor: value
                              ? AppTheme.primaryBlue
                              : AppTheme.surfaceElevated,
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    activeColor: AppTheme.primaryBlue,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),

              SizedBox(height: AppTheme.spaceLg),
              Divider(color: AppTheme.surfaceElevated),
              SizedBox(height: AppTheme.spaceSm),

              // Attach Media Section
              Text(
                'Attach Media',
                style: AppTheme.labelLarge.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              SizedBox(height: AppTheme.spaceXs),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.accentBlueLight, AppTheme.accentBlue],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white),
                ),
                title: Text(
                  'Take Photo',
                  style: AppTheme.labelLarge.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Use camera to capture',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              SizedBox(height: AppTheme.spaceXs),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryBlue, AppTheme.primaryBlueDark],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.white),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: AppTheme.labelLarge.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Select existing image',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _selectedFileName = image.name;
        });
        // Image preview is now shown directly in the input field
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildSendButton() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.accentGradient,
        ),
        shape: BoxShape.circle,
        boxShadow: AppTheme.accentGlow,
      ),
      child: IconButton(
        onPressed: _send,
        icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _showInputOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: AppTheme.surfaceGradient),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusXl),
                  topRight: Radius.circular(AppTheme.radiusXl),
                ),
                border: Border.all(
                  color: AppTheme.surfaceElevated.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(AppTheme.spaceLg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.textTertiary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(height: AppTheme.spaceLg),

                      // Title
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(AppTheme.spaceSm),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppTheme.accentGradient,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm,
                              ),
                            ),
                            child: Icon(
                              Icons.add_circle_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: AppTheme.spaceSm),
                          Text(
                            'Study Options',
                            style: AppTheme.headlineSmall.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppTheme.spaceLg),

                      // Settings Section
                      _buildSectionHeader('AI Settings'),
                      SizedBox(height: AppTheme.spaceSm),

                      // Response Mode
                      _buildSettingCard(
                        icon: _responseMode == 'detailed'
                            ? Icons.article
                            : Icons.flash_on,
                        title: 'Response Mode',
                        subtitle: _responseMode == 'detailed'
                            ? 'Detailed explanations'
                            : 'Quick & concise',
                        trailing: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _responseMode == 'detailed'
                                  ? AppTheme.primaryGradient
                                  : AppTheme.accentGradient,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _responseMode == 'detailed'
                                    ? 'Detailed'
                                    : 'Quick',
                                style: AppTheme.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.swap_horiz,
                                size: 14,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        onTap: () {
                          setModalState(() {
                            setState(() {
                              _responseMode = _responseMode == 'detailed'
                                  ? 'straight'
                                  : 'detailed';
                              _showResponseModeChip = true;
                            });
                          });
                        },
                      ),
                      SizedBox(height: AppTheme.spaceSm),

                      // Web Search Toggle
                      _buildSettingCard(
                        icon: Icons.search,
                        title: 'Web Search',
                        subtitle: _webSearchEnabled
                            ? 'Search the web for answers'
                            : 'Use AI knowledge only',
                        trailing: Switch(
                          value: _webSearchEnabled,
                          onChanged: (value) {
                            setModalState(() {
                              setState(() {
                                _webSearchEnabled = value;
                              });
                            });
                          },
                          activeColor: AppTheme.primaryBlue,
                          activeTrackColor: AppTheme.primaryBlue.withOpacity(
                            0.3,
                          ),
                        ),
                        onTap: () {
                          setModalState(() {
                            setState(() {
                              _webSearchEnabled = !_webSearchEnabled;
                            });
                          });
                        },
                      ),

                      SizedBox(height: AppTheme.spaceLg),

                      // Attachments Section
                      _buildSectionHeader('Add Attachments'),
                      SizedBox(height: AppTheme.spaceSm),

                      // Options
                      _buildBottomSheetOption(
                        icon: Icons.mic,
                        title: 'Audio Input',
                        subtitle: 'Speak your question',
                        gradient: AppTheme.accentGradient,
                        onTap: () {
                          Navigator.pop(context);
                          _toggleListening();
                        },
                      ),
                      SizedBox(height: AppTheme.spaceSm),
                      _buildBottomSheetOption(
                        icon: Icons.image_outlined,
                        title: 'Photo Library',
                        subtitle: 'Choose an image',
                        gradient: AppTheme.primaryGradient,
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                      SizedBox(height: AppTheme.spaceSm),
                      _buildBottomSheetOption(
                        icon: Icons.camera_alt_outlined,
                        title: 'Camera',
                        subtitle: 'Take a photo',
                        gradient: AppTheme.primaryGradient,
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: AppTheme.accentGradient),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: AppTheme.spaceXs),
        Text(
          title,
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: AppTheme.glassGradient),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppTheme.surfaceElevated.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spaceXs),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
            ),
            SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheetOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: AppTheme.glassGradient),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppTheme.surfaceElevated.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spaceSm),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(
                icon,
                color: gradient == AppTheme.glassGradient
                    ? AppTheme.textPrimary
                    : Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.textTertiary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showModelSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: AppTheme.surfaceGradient),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppTheme.radiusXl),
              topRight: Radius.circular(AppTheme.radiusXl),
            ),
            border: Border.all(
              color: AppTheme.surfaceElevated.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spaceLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textTertiary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: AppTheme.spaceMd),

                  // Title
                  Text(
                    'Select AI Model',
                    style: AppTheme.headlineSmall.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppTheme.spaceLg),

                  // Model Options
                  _buildModelOption(
                    name: 'Ace',
                    description: 'Fast & efficient for everyday tasks',
                    isSelected: _selectedModel == 'Ace',
                    gradient: AppTheme.primaryGradient,
                    onTap: () {
                      setState(() => _selectedModel = 'Ace');
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(height: AppTheme.spaceSm),
                  _buildModelOption(
                    name: 'Fortune',
                    description: 'Advanced reasoning for complex studies',
                    isSelected: _selectedModel == 'Fortune',
                    gradient: AppTheme.accentGradient,
                    onTap: () {
                      setState(() => _selectedModel = 'Fortune');
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(height: AppTheme.spaceSm),
                  _buildModelOption(
                    name: 'Sirri AI',
                    description: 'Balanced performance & accuracy',
                    isSelected: _selectedModel == 'Sirri AI',
                    gradient: [AppTheme.primaryBlue, AppTheme.accentBlue],
                    onTap: () {
                      setState(() => _selectedModel = 'Sirri AI');
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModelOption({
    required String name,
    required String description,
    required bool isSelected,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? gradient.map((c) => c.withOpacity(0.2)).toList()
                : AppTheme.glassGradient,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected
                ? gradient[0]
                : AppTheme.surfaceElevated.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spaceSm),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: gradient[0].withOpacity(0.4),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Icon(Icons.school_outlined, color: Colors.white, size: 24),
            ),
            SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    description,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
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
          title: InkWell(
            onTap: _showModelSelector,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spaceSm,
                vertical: AppTheme.spaceXs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: AppTheme.accentGradient,
                    ).createShader(bounds),
                    child: Text(
                      _selectedModel,
                      style: AppTheme.headlineMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: AppTheme.accentGradient,
                    ).createShader(bounds),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          centerTitle: true,
          actions: [
            // Quiz button
            IconButton(
              icon: const Icon(Icons.quiz),
              tooltip: 'Generate Quiz',
              onPressed: _loading ? null : _showQuizDialog,
            ),
            // Filter button
            IconButton(
              icon: Icon(
                Icons.filter_list,
                color: _domainFilterEnabled ? Colors.amber : null,
              ),
              tooltip: 'Domain Filter',
              onPressed: _showFilterDialog,
            ),
            // Edit description button
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Description',
              onPressed: _showEditDescriptionDialog,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final msg = _messages[i];

                  // Show typing indicator for typing messages
                  if (msg.isTyping) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: AppTheme.spaceSm),
                      child: Row(children: [TypingIndicator()]),
                    );
                  }

                  // Show streaming text with inline typing indicator
                  if (msg.isStreaming) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: AppTheme.spaceSm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AiMessageBubble(
                              text: msg.text,
                              fromUser: msg.isUser,
                              imagePath: msg.imagePath,
                              gradientColors: AppTheme.surfaceGradient,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(left: 4, top: 16),
                            child: TypingIndicator(),
                          ),
                        ],
                      ),
                    );
                  }

                  // Check if this is the quiz generation loading message
                  final isQuizGenerating =
                      msg.text == '🎯 Generating your quiz...';
                  if (isQuizGenerating) {
                    return Container(
                      margin: EdgeInsets.only(
                        right: 48,
                        bottom: AppTheme.spaceSm,
                      ),
                      padding: EdgeInsets.all(AppTheme.spaceMd),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppTheme.accentGradient,
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        boxShadow: AppTheme.accentGlow,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: AppTheme.spaceSm),
                          Text(
                            'Generating your quiz',
                            style: AppTheme.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: AppTheme.spaceXs),
                          _AnimatedDots(),
                        ],
                      ),
                    );
                  }

                  // Check if this is a quiz artifact message
                  final isQuizArtifact = msg.text.startsWith(
                    '🎯 Quiz Generated:',
                  );

                  if (isQuizArtifact) {
                    // Find the corresponding artifact
                    final artifactIndex = _quizArtifacts.indexWhere(
                      (a) => msg.text.contains(a.title),
                    );

                    if (artifactIndex != -1) {
                      final artifact = _quizArtifacts[artifactIndex];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  QuizArtifactViewer(artifact: artifact),
                            ),
                          );
                        },
                        child: Container(
                          margin: EdgeInsets.only(
                            right: 48,
                            bottom: AppTheme.spaceSm,
                          ),
                          padding: EdgeInsets.all(AppTheme.spaceMd),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.accentBlue.withOpacity(0.2),
                                AppTheme.accentBlueLight.withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusLg,
                            ),
                            border: Border.all(
                              color: AppTheme.accentBlue,
                              width: 2,
                            ),
                            boxShadow: AppTheme.accentGlow,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(AppTheme.spaceSm),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: AppTheme.accentGradient,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.quiz,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              SizedBox(width: AppTheme.spaceMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      artifact.title,
                                      style: AppTheme.labelLarge.copyWith(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '${artifact.numQuestions} ${artifact.questionType} • ${artifact.gradeLevel}',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Tap to view and take the quiz',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.accentBlue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: AppTheme.accentBlue,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  }

                  return AiMessageBubble(
                    text: msg.text,
                    fromUser: msg.isUser,
                    imagePath: msg.imagePath,
                    gradientColors: msg.isUser
                        ? AppTheme.primaryGradient
                        : AppTheme.surfaceGradient,
                  );
                },
              ),
            ),
            // Modern Input Section (Claude-style)
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
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMd,
                vertical: AppTheme.spaceMd,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Response mode chip (if active)
                  if (_showResponseModeChip)
                    Padding(
                      padding: EdgeInsets.only(bottom: AppTheme.spaceSm),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceSm,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _responseMode == 'detailed'
                                ? AppTheme.primaryGradient
                                : AppTheme.accentGradient,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _responseMode == 'detailed'
                                  ? Icons.article
                                  : Icons.flash_on,
                              size: 14,
                              color: _responseMode == 'detailed'
                                  ? Colors.black
                                  : Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              _responseMode == 'detailed'
                                  ? 'Detailed'
                                  : 'Quick',
                              style: AppTheme.bodySmall.copyWith(
                                color: _responseMode == 'detailed'
                                    ? Colors.black
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                setState(() => _showResponseModeChip = false);
                              },
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: _responseMode == 'detailed'
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Image Preview (if selected)
                  if (_selectedImage != null)
                    Container(
                      margin: EdgeInsets.only(bottom: AppTheme.spaceSm),
                      padding: EdgeInsets.all(AppTheme.spaceSm),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm,
                            ),
                            child: Image.file(
                              _selectedImage!,
                              height: 60,
                              width: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          SizedBox(width: AppTheme.spaceSm),
                          Expanded(
                            child: Text(
                              _selectedFileName ?? 'Image selected',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: AppTheme.textTertiary,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedImage = null;
                                _selectedFileName = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                  // Main Input Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Plus Button (Left)
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: AppTheme.glassGradient,
                          ),
                          border: Border.all(
                            color: AppTheme.surfaceElevated.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.add,
                            color: AppTheme.textPrimary,
                            size: 24,
                          ),
                          onPressed: _showInputOptionsBottomSheet,
                        ),
                      ),

                      SizedBox(width: AppTheme.spaceSm),

                      // Text Input Field (Center)
                      Expanded(
                        child: Container(
                          constraints: BoxConstraints(
                            minHeight: 48,
                            maxHeight: 120,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: AppTheme.surfaceGradient,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppTheme.surfaceElevated,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  textInputAction: TextInputAction.newline,
                                  maxLines: null,
                                  keyboardType: TextInputType.multiline,
                                  style: AppTheme.bodyLarge.copyWith(
                                    color: AppTheme.textPrimary,
                                  ),
                                  onChanged: (value) {
                                    setState(() {});
                                  },
                                  decoration: InputDecoration(
                                    hintText:
                                        'Ask about ${widget.planTitle}...',
                                    hintStyle: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.textTertiary,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: AppTheme.spaceMd,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),

                              // Vertical divider line / Send Button (no loading state)
                              if (_controller.text.trim().isEmpty)
                                Container(
                                  margin: EdgeInsets.only(
                                    right: AppTheme.spaceMd,
                                    bottom: 16,
                                  ),
                                  width: 2,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: AppTheme.accentGradient,
                                    ),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                )
                              else
                                Padding(
                                  padding: EdgeInsets.only(right: 6, bottom: 6),
                                  child: _buildSendButton(),
                                ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(width: AppTheme.spaceSm),

                      // Microphone Button (Right)
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isListening
                                ? AppTheme.accentGradient
                                : AppTheme.glassGradient,
                          ),
                          border: Border.all(
                            color: AppTheme.surfaceElevated.withOpacity(0.5),
                            width: 1,
                          ),
                          boxShadow: _isListening ? AppTheme.accentGlow : [],
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening
                                ? Colors.white
                                : AppTheme.textPrimary,
                            size: 24,
                          ),
                          onPressed: _toggleListening,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _contextEditCtrl.dispose();
    super.dispose();
  }
}

// Animated dots widget for loading feedback
class _AnimatedDots extends StatefulWidget {
  @override
  _AnimatedDotsState createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final opacity = ((_controller.value - delay) % 1.0);
            final scale = opacity < 0.5 ? opacity * 2 : (1 - opacity) * 2;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: 0.5 + (scale * 0.5),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5 + (opacity * 0.5)),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
