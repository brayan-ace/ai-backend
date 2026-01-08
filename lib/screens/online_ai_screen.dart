import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/theme.dart';
import '../utils/greeting_utils.dart';
import '../widgets/ai_message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/greeting_icon.dart';
import '../widgets/voice_input_dialog.dart';
import '../services/gemini_services.dart';
import '../services/api_service.dart';
import '../services/web_search_service.dart';
import '../services/chat_storage_service.dart';
import '../utils/ai_constants.dart';
import 'notes_screen.dart';
import 'chat_history_screen.dart';

class OnlineAiScreen extends StatefulWidget {
  const OnlineAiScreen({Key? key}) : super(key: key);

  @override
  _OnlineAiScreenState createState() => _OnlineAiScreenState();
}

class _OnlineAiScreenState extends State<OnlineAiScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  late final Stream<User?> _authStateStream;
  late final StreamSubscription<User?> _authSub;
  late AnimationController _greetingAnimationController;
  late Animation<double> _greetingFadeAnimation;

  bool _webSearchEnabled = false;
  String _responseMode = 'straight';
  bool _showGreeting = true;

  File? _selectedImage;
  String? _selectedFileName;

  final List<_Message> _messages = [];
  String _currentStatusMessage = '';

  bool _isSavingEnabled = false;
  String? _currentChatId;

  late final GeminiService _geminiService;
  late final WebSearchService _webSearchService;
  late final ChatStorageService _chatStorage;

  String _selectedModel = 'Groq';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiService();
    _webSearchService = WebSearchService();
    _chatStorage = ChatStorageService();

    // Initialize animation controller
    _greetingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _greetingFadeAnimation = CurvedAnimation(
      parent: _greetingAnimationController,
      curve: Curves.easeInOut,
    );
    _greetingAnimationController.forward();

    // Initialize saving enabled based on auth state
    _isSavingEnabled = FirebaseAuth.instance.currentUser != null;
    _authStateStream = FirebaseAuth.instance.authStateChanges();
    _authSub = _authStateStream.listen((user) {
      setState(() {
        _isSavingEnabled = user != null;
        if (user == null) {
          // Clear current chat when signed out
          _currentChatId = null;
        }
      });
    });
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

  void _showInputOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundDeep,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusLg),
                  topRight: Radius.circular(AppTheme.radiusLg),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle bar
                      Container(
                        margin: EdgeInsets.only(top: 12),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.textTertiary.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(height: 28),

                      // Header with close button and title
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            // Close button
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: AppTheme.textPrimary,
                                size: 24,
                              ),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                            Expanded(
                              child: Text(
                                'Add to chat',
                                textAlign: TextAlign.center,
                                style: AppTheme.headlineMedium.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            // Spacer to balance close button
                            SizedBox(width: 40),
                          ],
                        ),
                      ),
                      SizedBox(height: 32),

                      // Attachment Options - Horizontal Cards
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            // Camera Card
                            Expanded(
                              child: _buildAttachmentCard(
                                icon: Icons.camera_alt_outlined,
                                label: 'Camera',
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickImage(ImageSource.camera);
                                },
                              ),
                            ),
                            SizedBox(width: 16),
                            // Photos Card
                            Expanded(
                              child: _buildAttachmentCard(
                                icon: Icons.image_outlined,
                                label: 'Photos',
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickImage(ImageSource.gallery);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 28),

                      // Divider
                      Divider(
                        color: AppTheme.surfaceElevated.withOpacity(0.3),
                        height: 1,
                        thickness: 1,
                      ),

                      // Web Search Toggle
                      InkWell(
                        onTap: () {
                          setModalState(() {
                            setState(() {
                              _webSearchEnabled = !_webSearchEnabled;
                            });
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.language,
                                color: AppTheme.textPrimary,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Web search',
                                style: AppTheme.bodyLarge.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Spacer(),
                              Switch(
                                value: _webSearchEnabled,
                                onChanged: (value) {
                                  setModalState(() {
                                    setState(() {
                                      _webSearchEnabled = value;
                                    });
                                  });
                                },
                                activeColor: AppTheme.primaryBlue,
                                activeTrackColor: AppTheme.primaryBlue
                                    .withOpacity(0.5),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Divider
                      Divider(
                        color: AppTheme.surfaceElevated.withOpacity(0.3),
                        height: 1,
                        thickness: 1,
                      ),

                      // Use Style Selector
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _showStyleSelector();
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                color: AppTheme.textPrimary,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Use style',
                                style: AppTheme.bodyLarge.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Spacer(),
                              Text(
                                _responseMode == 'detailed'
                                    ? 'Detailed'
                                    : 'Quick',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right,
                                color: AppTheme.textSecondary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 32),
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

  // New helper method for attachment cards
  Widget _buildAttachmentCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.surfaceElevated.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.textPrimary, size: 36),
            SizedBox(height: 14),
            Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // New method for style selector bottom sheet
  void _showStyleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundDeep,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppTheme.radiusLg),
              topRight: Radius.circular(AppTheme.radiusLg),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle bar
                Container(
                  margin: EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 20),

                // Title
                Text(
                  'Use style',
                  style: AppTheme.headlineMedium.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 24),

                // Detailed Option
                InkWell(
                  onTap: () {
                    setState(() => _responseMode = 'detailed');
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    color: _responseMode == 'detailed'
                        ? AppTheme.primaryBlue.withOpacity(0.1)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        Icon(
                          Icons.article_outlined,
                          color: _responseMode == 'detailed'
                              ? AppTheme.primaryBlue
                              : AppTheme.textPrimary,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Detailed',
                                style: AppTheme.bodyLarge.copyWith(
                                  color: _responseMode == 'detailed'
                                      ? AppTheme.primaryBlue
                                      : AppTheme.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Complete explanations and context',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_responseMode == 'detailed')
                          Icon(
                            Icons.check_circle,
                            color: AppTheme.primaryBlue,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                ),

                // Quick Option
                InkWell(
                  onTap: () {
                    setState(() => _responseMode = 'straight');
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    color: _responseMode == 'straight'
                        ? AppTheme.primaryBlue.withOpacity(0.1)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        Icon(
                          Icons.flash_on_outlined,
                          color: _responseMode == 'straight'
                              ? AppTheme.primaryBlue
                              : AppTheme.textPrimary,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quick',
                                style: AppTheme.bodyLarge.copyWith(
                                  color: _responseMode == 'straight'
                                      ? AppTheme.primaryBlue
                                      : AppTheme.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Fast and concise answers',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_responseMode == 'straight')
                          Icon(
                            Icons.check_circle,
                            color: AppTheme.primaryBlue,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
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
                    name: 'Claude Sonnet',
                    description: 'Fast & intelligent for everyday tasks',
                    isSelected: _selectedModel == 'Claude Sonnet',
                    gradient: AppTheme.primaryGradient,
                    onTap: () {
                      setState(() => _selectedModel = 'Claude Sonnet');
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(height: AppTheme.spaceSm),
                  _buildModelOption(
                    name: 'Gemini',
                    description: 'Google Gemini — conversational text model',
                    isSelected: _selectedModel == 'Gemini',
                    gradient: AppTheme.accentGradient,
                    onTap: () {
                      setState(() => _selectedModel = 'Gemini');
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(height: AppTheme.spaceSm),
                  _buildModelOption(
                    name: 'Groq',
                    description: 'Ultra-fast reasoning with LLaMA 3.3',
                    isSelected: _selectedModel == 'Groq',
                    gradient: [AppTheme.primaryBlue, AppTheme.accentBlue],
                    onTap: () {
                      setState(() => _selectedModel = 'Groq');
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
              child: Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 24,
              ),
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

  void _toggleListening() async {
    // Show the new floating voice input dialog
    final transcribedText = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => const VoiceInputDialog(),
    );

    // If user provided speech input, insert it into the text field
    if (transcribedText != null && transcribedText.isNotEmpty) {
      setState(() {
        _controller.text = transcribedText;
      });
      // Optionally auto-send the message
      // _send();
    }
  }

  @override
  @override
  void dispose() {
    _greetingAnimationController.dispose();
    _authSub.cancel();
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final hasImage = _selectedImage != null;
    final imageFile = _selectedImage;
    final imageName = _selectedFileName;

    // Hide greeting on first message with animation
    if (_showGreeting) {
      _greetingAnimationController.reverse().then((_) {
        setState(() {
          _showGreeting = false;
        });
      });
    }

    // INSTANT FEEDBACK: Show user message immediately
    setState(() {
      _messages.add(
        _Message(
          text: text,
          fromUser: true,
          imagePath: hasImage ? imageFile?.path : null,
        ),
      );
      _controller.clear(); // Clear input immediately
      _selectedImage = null;
      _selectedFileName = null;
    });

    // Add typing indicator with status message
    setState(() {
      _currentStatusMessage = hasImage
          ? 'Analyzing image...'
          : 'Generating response...';
      _messages.add(_Message(text: '', fromUser: false, isTyping: true));
    });

    // Create new chat if this is the first user message and user is authenticated
    if (_isSavingEnabled && _currentChatId == null) {
      try {
        _currentChatId = await _chatStorage.createChat(title: text);
      } catch (e) {
        print('Error creating chat: $e');
      }
    }

    // Save user message to Firebase
    if (_isSavingEnabled && _currentChatId != null) {
      try {
        await _chatStorage.saveMessage(
          chatId: _currentChatId!,
          text: hasImage ? '$text\n📎 Image: $imageName' : text,
          fromUser: true,
        );
      } catch (e) {
        print('Error saving user message: $e');
      }
    }

    String? response;

    // If this is an identity question, handle consent flow via backend local responses
    bool handledLocally = false;
    final identityRegex = RegExp(
      r'\bwho\s+are\s+you\b|\bwhat\s+are\s+you\b|\btell\s+me\s+about\s+yourself\b',
      caseSensitive: false,
    );
    if (identityRegex.hasMatch(text)) {
      try {
        final raw = await ApiService.sendRaw('chat', {
          'message': text,
          'action': 'identity',
        });
        final reply = raw['reply'] ?? raw['response'] ?? raw.toString();
        setState(() {
          _messages.add(_Message(text: reply.toString(), fromUser: false));
        });

        // If backend indicated identityOffered, prompt user for consent via dialog
        if (raw['identityOffered'] == true) {
          final consent = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Show founder?'),
              content: Text('Would you like to know my founder or my builder?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('No'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('Yes'),
                ),
              ],
            ),
          );

          if (consent == true) {
            final raw2 = await ApiService.sendRaw('chat', {
              'message': 'reveal',
              'action': 'reveal_founder',
              'confirm': true,
            });
            final reply2 = raw2['reply'] ?? raw2['response'] ?? raw2.toString();
            setState(() {
              _messages.add(_Message(text: reply2.toString(), fromUser: false));
            });
          }
        }

        handledLocally = true;
      } catch (e) {
        print('Identity flow error: $e');
      }
    }

    if (handledLocally) {
      // Remove typing indicator
      setState(() {
        if (_messages.isNotEmpty && _messages.last.isTyping)
          _messages.removeLast();
      });
      return;
    }

    // If image is attached, use Gemini Vision API
    if (hasImage && imageFile != null) {
      try {
        print('========================================');
        print('Processing image for Gemini Vision API');
        print('Image path: ${imageFile.path}');
        print('Image file exists: ${await imageFile.exists()}');

        // Read and compress image to reduce size
        var bytes = await imageFile.readAsBytes();
        print('Image bytes read: ${bytes.length} bytes');

        // Compress image if it's too large (limit to ~300KB to stay under request size limit with base64 encoding overhead)
        if (bytes.length > 300000) {
          print(
            'Image size ${bytes.length} bytes exceeds limit, compressing...',
          );
          try {
            // Aggressive compression for large images
            bytes = await _compressImage(bytes, quality: 50);
            print('Compressed to: ${bytes.length} bytes');
          } catch (e) {
            print('Compression failed: $e, using original image');
          }
        }

        final base64Image = base64Encode(bytes);
        print('Base64 encoded successfully: ${base64Image.length} characters');
        print(
          'Base64 preview (first 50 chars): ${base64Image.substring(0, base64Image.length > 50 ? 50 : base64Image.length)}...',
        );

        // Determine mime type from file extension
        String mimeType = 'image/jpeg';
        if (imageFile.path.toLowerCase().endsWith('.png')) {
          mimeType = 'image/png';
        } else if (imageFile.path.toLowerCase().endsWith('.gif')) {
          mimeType = 'image/gif';
        } else if (imageFile.path.toLowerCase().endsWith('.webp')) {
          mimeType = 'image/webp';
        }
        print('Detected mime type: $mimeType');
        print('Calling Gemini Vision API...');
        print('========================================');

        response = await _geminiService.generateContentWithImage(
          prompt: text,
          base64Image: base64Image,
          mimeType: mimeType,
        );

        print(
          'Response received: ${response?.substring(0, response.length > 100 ? 100 : response.length)}...',
        );
      } catch (e, stackTrace) {
        print('ERROR processing image: $e');
        print('Stack trace: $stackTrace');
        response = '⚠️ Error processing image: $e';
      }
    } else {
      // Handle web search if enabled
      if (_webSearchEnabled) {
        setState(() {
          _currentStatusMessage = 'Searching the web...';
          // Update last message to show web search status
          if (_messages.isNotEmpty && _messages.last.isTyping) {
            _messages.removeLast();
            _messages.add(_Message(text: '', fromUser: false, isTyping: true));
          }
        });
        try {
          final searchResults = await _webSearchService.search(query: text);
          setState(
            () => _currentStatusMessage = 'Processing search results...',
          );
          final enhancedPrompt = _webSearchService.createEnhancedPrompt(
            text,
            searchResults,
          );
          setState(() {
            _currentStatusMessage = 'Generating response...';
          });
          final instructions = _extractInstructionsFromText(text);
          // For web search, use minimal messages (only user's current question + search context)
          // Don't send full conversation history to avoid confusing the model
          response = await _callWithSearchResults(
            enhancedPrompt,
            instructions: instructions,
          );
        } catch (e) {
          setState(() {
            _currentStatusMessage = 'Generating response...';
          });
          response = '⚠️ Web search error: $e\n\nTrying AI database...';
          final instructions = _extractInstructionsFromText(text);
          response = await _callWithFallback(text, instructions: instructions);
        }
      } else {
        // Try AI database first
        final instructions = _extractInstructionsFromText(text);
        response = await _callWithFallback(text, instructions: instructions);

        // Check if response suggests lack of information
        if (response != null && _shouldSuggestWebSearch(response, text)) {
          setState(() {
            // Remove typing indicator
            if (_messages.isNotEmpty && _messages.last.text == '●●●') {
              _messages.removeLast();
            }
            _messages.add(_Message(text: response!, fromUser: false));
          });

          // Ask user if they want web search
          final wantWebSearch = await _showWebSearchDialog();
          if (wantWebSearch == true) {
            setState(() {
              _messages.add(
                _Message(text: '🔍 Searching the web...', fromUser: false),
              );
            });

            try {
              final searchResults = await _webSearchService.search(query: text);
              final enhancedPrompt = _webSearchService.createEnhancedPrompt(
                text,
                searchResults,
              );

              final instructions = _extractInstructionsFromText(text);
              response = await _callWithFallback(
                enhancedPrompt,
                instructions: instructions,
              );

              // Remove search indicator
              setState(() {
                if (_messages.isNotEmpty &&
                    _messages.last.text == '🔍 Searching the web...') {
                  _messages.removeLast();
                }
              });
            } catch (e) {
              setState(() {
                // Remove search indicator
                if (_messages.isNotEmpty &&
                    _messages.last.text == '🔍 Searching the web...') {
                  _messages.removeLast();
                }
              });
              response = '⚠️ Web search failed: $e';
            }
          } else {
            // User declined, use existing response (already added)
            // Save AI response to Firebase
            if (_isSavingEnabled && _currentChatId != null) {
              try {
                await _chatStorage.saveMessage(
                  chatId: _currentChatId!,
                  text: response,
                  fromUser: false,
                );
              } catch (e) {
                print('Error saving AI response: $e');
              }
            }
            return;
          }
        }
      }
    }

    // Remove typing indicator
    setState(() {
      if (_messages.isNotEmpty && _messages.last.isTyping) {
        _messages.removeLast();
      }
    });

    // Stream the response
    if (response != null) {
      await _streamResponse(response);

      // Save AI response to Firebase
      if (_isSavingEnabled && _currentChatId != null) {
        try {
          await _chatStorage.saveMessage(
            chatId: _currentChatId!,
            text: response,
            fromUser: false,
          );
        } catch (e) {
          print('Error saving AI response: $e');
        }
      }
    } else {
      setState(() {
        _messages.add(_Message(text: 'No response', fromUser: false));
      });
    }
  }

  Future<void> _streamResponse(String fullResponse) async {
    // Add empty streaming message
    final streamingMessage = _Message(
      text: '',
      fromUser: false,
      isStreaming: true,
    );

    setState(() {
      _messages.add(streamingMessage);
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

  // Extract structured instructions from free-text (e.g., 'in 2 lines', 'short', 'brief', '2 sentences')
  Map<String, dynamic>? _extractInstructionsFromText(String text) {
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    final linesMatch = RegExp(
      r'in\s*(\d+)\s*lines?|^(\d+)\s*lines?',
      caseSensitive: false,
    ).firstMatch(lower);
    final sentencesMatch = RegExp(
      r'in\s*(\d+)\s*sentences?|^(\d+)\s*sentences?',
      caseSensitive: false,
    ).firstMatch(lower);
    final short =
        lower.contains('short') ||
        lower.contains('brief') ||
        lower.contains('simple');

    final Map<String, dynamic> out = {};
    if (linesMatch != null)
      out['lines'] = int.tryParse(
        linesMatch.group(1) ?? linesMatch.group(2) ?? '',
      );
    if (sentencesMatch != null)
      out['sentences'] = int.tryParse(
        sentencesMatch.group(1) ?? sentencesMatch.group(2) ?? '',
      );
    if (short) out['short'] = true;

    return out.isEmpty ? null : out;
  }

  Future<String?> _callWithFallback(
    String prompt, {
    Map<String, dynamic>? instructions,
  }) async {
    // Try Groq first
    try {
      // Build full conversation messages from local chat history.
      // Do NOT include a client-side system prompt here; backend will enforce system instructions.
      // Filter out unwanted assistant intro messages to avoid repetition.
      final List<Map<String, String>> convo = [];
      for (final m in _messages) {
        final role = m.fromUser ? 'user' : 'assistant';
        final content = m.text ?? '';

        // Skip default assistant intros to prevent repetition
        if (!role.contains('assistant') || !_isDefaultIntroMessage(content)) {
          convo.add({'role': role, 'content': content});
        }
      }

      final resp = await _geminiService.generateContent(
        prompt,
        responseMode: _responseMode,
        instructions: instructions,
        messages: convo,
        model: _selectedModel,
      );

      return resp;
    } catch (e) {
      return '⚠️ All AI services are currently unavailable. ($e)';
    }
  }

  /// Call with search results: minimal message array (only current question + search context)
  /// Prevents model from being confused by previous conversation when answering based on fresh search results
  Future<String?> _callWithSearchResults(
    String enhancedPrompt, {
    Map<String, dynamic>? instructions,
  }) async {
    try {
      // For web search results, use ONLY the enhanced prompt (with search context)
      // Do NOT include conversation history; let the model focus on the search results
      final List<Map<String, String>> searchMessages = [
        {'role': 'user', 'content': enhancedPrompt},
      ];

      final resp = await _geminiService.generateContent(
        enhancedPrompt,
        responseMode: _responseMode,
        instructions: instructions,
        messages: searchMessages,
        model: _selectedModel,
      );

      return resp;
    } catch (e) {
      return '⚠️ All AI services are currently unavailable. ($e)';
    }
  }

  bool _isDefaultIntroMessage(String text) {
    if (text.isEmpty) return false;
    // Check if message is a default intro (contains these patterns)
    final lower = text.toLowerCase();
    return (lower.contains('assistant introduction') ||
        lower.contains('ai assistant') && lower.contains('here to help') ||
        lower.contains('no fixed name') ||
        lower.contains('ai helper'));
  }

  /// Load a chat from history
  Future<void> _loadChat(String chatId, String title) async {
    try {
      setState(() {
        _messages.clear();
        _currentChatId = chatId;
        _showGreeting = false; // Hide greeting when loading a chat
      });

      // Load messages from Firebase
      final messagesStream = _chatStorage.getMessages(chatId);
      final messages = await messagesStream.first;

      setState(() {
        for (final msg in messages) {
          _messages.add(_Message(text: msg['text'], fromUser: msg['fromUser']));
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loaded: $title'),
          backgroundColor: AppTheme.primaryBlue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading chat: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Format timestamp for display
  String _formatTimestamp(dynamic timestamp) {
    try {
      final dt = timestamp.toDate() as DateTime;
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
      return '${(diff.inDays / 365).floor()}y ago';
    } catch (e) {
      return 'Recently';
    }
  }

  /// Show chat options menu
  void _showChatOptions(String chatId, String title, bool isStarred) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.surfaceElevated,
                AppTheme.backgroundGradientEnd,
              ],
            ),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXl),
            ),
          ),
          padding: EdgeInsets.all(AppTheme.spaceMd),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Text(
                  title,
                  style: AppTheme.headlineSmall.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppTheme.spaceLg),
                // Options
                _buildOptionTile(
                  icon: isStarred ? Icons.star : Icons.star_border,
                  title: isStarred ? 'Unstar Chat' : 'Star Chat',
                  color: Colors.amber,
                  onTap: () {
                    Navigator.pop(context);
                    _toggleStar(chatId, !isStarred);
                  },
                ),
                _buildOptionTile(
                  icon: Icons.edit,
                  title: 'Rename Chat',
                  color: AppTheme.primaryBlue,
                  onTap: () {
                    Navigator.pop(context);
                    _showRenameDialog(chatId, title);
                  },
                ),
                _buildOptionTile(
                  icon: Icons.delete,
                  title: 'Delete Chat',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmDialog(title).then((confirm) {
                      if (confirm == true) {
                        _deleteChat(chatId, title);
                      }
                    });
                  },
                ),
                _buildOptionTile(
                  icon: Icons.share,
                  title: 'Share Chat',
                  color: AppTheme.primaryBlue,
                  onTap: () {
                    Navigator.pop(context);
                    _shareChatLink(chatId, title);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build option tile for bottom sheet
  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: AppTheme.spaceSm,
        ),
        margin: EdgeInsets.only(bottom: AppTheme.spaceXs),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: AppTheme.glassGradient),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spaceSm),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: AppTheme.spaceMd),
            Text(
              title,
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
            ),
            Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  /// Toggle star status
  Future<void> _toggleStar(String chatId, bool newStarred) async {
    try {
      await _chatStorage.toggleStar(chatId, newStarred);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStarred ? '⭐ Chat starred' : 'Chat unstarred'),
          backgroundColor: newStarred ? Colors.amber : AppTheme.primaryBlue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Show rename dialog
  Future<void> _showRenameDialog(String chatId, String currentTitle) async {
    final controller = TextEditingController(text: currentTitle);
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: Text(
            'Rename Chat',
            style: AppTheme.headlineSmall.copyWith(color: AppTheme.textPrimary),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter new name',
              hintStyle: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textTertiary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(color: AppTheme.primaryBlue),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(color: AppTheme.surfaceElevated),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newTitle = controller.text.trim();
                if (newTitle.isNotEmpty) {
                  Navigator.pop(context);
                  try {
                    await _chatStorage.updateChatTitle(chatId, newTitle);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✓ Chat renamed'),
                        backgroundColor: AppTheme.primaryBlue,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error renaming: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
              ),
              child: Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  /// Show delete confirmation dialog
  Future<bool?> _showDeleteConfirmDialog(String title) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: AppTheme.spaceSm),
              Text(
                'Delete Chat?',
                style: AppTheme.headlineSmall.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "$title"? This action cannot be undone.',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  /// Delete a chat
  Future<void> _deleteChat(String chatId, String title) async {
    try {
      await _chatStorage.deleteChat(chatId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ "$title" deleted'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // If the deleted chat is the current one, clear it
      if (_currentChatId == chatId) {
        setState(() {
          _currentChatId = null;
          _messages.clear();
          _showGreeting = true;
          _greetingAnimationController.forward();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareChatLink(String chatId, String title) async {
    try {
      // Generate shareable link with chat ID
      final shareText =
          '''
Check out this chat on MyAI: "$title"

Open the app and search for chat ID: $chatId

🤖 MyAI - Your AI Conversation Hub
'''
              .trim();

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: shareText));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chat link copied!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Share the chat ID: $chatId',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primaryBlue,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing chat: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated.withOpacity(0.95),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border(
              top: BorderSide(
                color: AppTheme.primaryBlue.withOpacity(0.15),
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Padding(
                  padding: EdgeInsets.only(top: 12, bottom: 20),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textTertiary.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        'Chat Options',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: AppTheme.textTertiary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                Divider(
                  color: AppTheme.surfaceElevated.withOpacity(0.5),
                  height: 20,
                  thickness: 0.5,
                ),

                // Menu Items
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      // Rename
                      _buildMenuItemAdvanced(
                        ctx,
                        icon: Icons.edit_outlined,
                        title: 'Rename',
                        subtitle: 'Change chat title',
                        gradient: AppTheme.primaryGradient,
                        onTap: () {
                          Navigator.pop(ctx);
                          if (_currentChatId != null) {
                            // Get current chat title
                            _chatStorage.getChats().first.then((chats) {
                              final currentChat = chats.firstWhere(
                                (chat) => chat['id'] == _currentChatId,
                                orElse: () => {'title': 'Current Chat'},
                              );
                              _showRenameDialog(
                                _currentChatId!,
                                currentChat['title'] ?? 'Current Chat',
                              );
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Start a conversation first to rename',
                                ),
                                backgroundColor: AppTheme.surfaceElevated,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                      SizedBox(height: 8),

                      // Personalize (Coming Soon)
                      _buildMenuItemAdvanced(
                        ctx,
                        icon: Icons.person_outline,
                        title: 'Personalize',
                        subtitle: 'Customize chat preferences',
                        gradient: AppTheme.primaryGradient,
                        onTap: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Coming Soon',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: AppTheme.primaryBlue,
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 8),

                      // Star
                      _buildMenuItemAdvanced(
                        ctx,
                        icon: Icons.star_outline,
                        title: 'Star',
                        subtitle: 'Mark as important',
                        gradient: [Colors.amber, Colors.orange],
                        onTap: () {
                          Navigator.pop(ctx);
                          if (_currentChatId != null) {
                            // Check current star status
                            _chatStorage.getChats().first.then((chats) {
                              final currentChat = chats.firstWhere(
                                (chat) => chat['id'] == _currentChatId,
                                orElse: () => {'isStarred': false},
                              );
                              final isStarred =
                                  currentChat['isStarred'] ?? false;
                              _toggleStar(_currentChatId!, !isStarred);
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Start a conversation first to star',
                                ),
                                backgroundColor: AppTheme.surfaceElevated,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                      SizedBox(height: 8),

                      // New Chat
                      _buildMenuItemAdvanced(
                        ctx,
                        icon: Icons.add_circle_outline,
                        title: 'New Chat',
                        subtitle: 'Start fresh conversation',
                        gradient: AppTheme.accentGradient,
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _messages.clear();
                            _currentChatId = null;
                            _showGreeting = true;
                            _greetingAnimationController.forward();
                          });
                        },
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItemAdvanced(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated.withOpacity(0.3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              // Icon with gradient background
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: gradient[0].withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              SizedBox(width: 14),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
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
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(AppTheme.spaceMd),
                child: Row(
                  children: [
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: AppTheme.primaryGradient,
                        ).createShader(bounds),
                        child: Text(
                          'Chats',
                          style: AppTheme.displayMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Container(
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
                        icon: Icon(Icons.add, color: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _messages.clear();
                            _currentChatId = null; // Start a new chat
                            _showGreeting = true;
                            _greetingAnimationController.forward();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppTheme.surfaceGradient),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(
                      color: AppTheme.surfaceElevated,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search chats...',
                      hintStyle: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppTheme.primaryBlue,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: AppTheme.textTertiary,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMd,
                        vertical: AppTheme.spaceSm,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: AppTheme.spaceMd),

              // Create Study Plan button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/study');
                  },
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: Container(
                    padding: EdgeInsets.all(AppTheme.spaceMd),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: AppTheme.accentGradient,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      boxShadow: AppTheme.accentGlow,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.school, color: Colors.white, size: 24),
                        SizedBox(width: AppTheme.spaceSm),
                        Text(
                          'Create Study Plan',
                          style: AppTheme.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: AppTheme.spaceMd),

              // Chats label
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
                child: Text(
                  'RECENT CHATS',
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.textTertiary,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              SizedBox(height: AppTheme.spaceSm),

              // Chat list
              Expanded(
                child: !_isSavingEnabled
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.login,
                              size: 48,
                              color: AppTheme.textTertiary,
                            ),
                            SizedBox(height: AppTheme.spaceSm),
                            Text(
                              'Sign in to save chats',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textTertiary,
                              ),
                            ),
                            SizedBox(height: AppTheme.spaceMd),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/auth');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                              ),
                              child: Text('Sign In'),
                            ),
                          ],
                        ),
                      )
                    : StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _chatStorage.getChats(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryBlue,
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: Colors.red,
                                  ),
                                  SizedBox(height: AppTheme.spaceSm),
                                  Text(
                                    'Error loading chats',
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final allChats = snapshot.data ?? [];

                          // Filter chats based on search query (title + content)
                          if (_searchQuery.isEmpty) {
                            // No search: show all chats
                            final displayChats = allChats;
                            if (displayChats.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 48,
                                      color: AppTheme.textTertiary,
                                    ),
                                    SizedBox(height: AppTheme.spaceSm),
                                    Text(
                                      'No chats yet',
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: AppTheme.textTertiary,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: AppTheme.spaceSm,
                                      ),
                                      child: Text(
                                        'Start chatting to create your first conversation',
                                        style: AppTheme.bodySmall.copyWith(
                                          color: AppTheme.textTertiary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: displayChats.length,
                              itemBuilder: (context, index) {
                                final chat = displayChats[index];
                                final isStarred = chat['isStarred'] ?? false;
                                final chatId = chat['id'];
                                final chatTitle = chat['title'];
                                final timeStr = _formatTimestamp(
                                  chat['timestamp'],
                                );

                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppTheme.spaceSm,
                                    vertical: 2,
                                  ),
                                  child: Dismissible(
                                    key: Key(chatId),
                                    direction: DismissDirection.endToStart,
                                    confirmDismiss: (direction) async {
                                      return await _showDeleteConfirmDialog(
                                        chatTitle,
                                      );
                                    },
                                    onDismissed: (direction) {
                                      _deleteChat(chatId, chatTitle);
                                    },
                                    background: Container(
                                      margin: EdgeInsets.symmetric(
                                        vertical: AppTheme.spaceSm,
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: AppTheme.spaceMd,
                                        vertical: AppTheme.spaceSm,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.red.withOpacity(0.1),
                                            Colors.red,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusSm,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.pop(context);
                                        _loadChat(chatId, chatTitle);
                                      },
                                      onLongPress: () {
                                        _showChatOptions(
                                          chatId,
                                          chatTitle,
                                          isStarred,
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSm,
                                      ),
                                      child: Container(
                                        padding: EdgeInsets.all(
                                          AppTheme.spaceSm,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: AppTheme.glassGradient,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusSm,
                                          ),
                                          border: isStarred
                                              ? Border.all(
                                                  color: Colors.amber,
                                                  width: 1.5,
                                                )
                                              : Border.all(
                                                  color: AppTheme
                                                      .surfaceElevated
                                                      .withOpacity(0.5),
                                                  width: 1,
                                                ),
                                        ),
                                        child: Row(
                                          children: [
                                            if (isStarred)
                                              Padding(
                                                padding: EdgeInsets.only(
                                                  right: AppTheme.spaceSm,
                                                ),
                                                child: Icon(
                                                  Icons.star,
                                                  color: Colors.amber,
                                                  size: 18,
                                                ),
                                              ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    chatTitle,
                                                    style: AppTheme.bodyLarge
                                                        .copyWith(
                                                          color: AppTheme
                                                              .textPrimary,
                                                        ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    '${chat['messageCount']} messages',
                                                    style: AppTheme.bodySmall
                                                        .copyWith(
                                                          color: AppTheme
                                                              .textTertiary,
                                                        ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              timeStr,
                                              style: AppTheme.bodySmall
                                                  .copyWith(
                                                    color:
                                                        AppTheme.textTertiary,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          } else {
                            // Search mode: filter by title
                            final filteredChats = allChats.where((chat) {
                              return chat['title']
                                  .toString()
                                  .toLowerCase()
                                  .contains(_searchQuery.toLowerCase());
                            }).toList();

                            if (filteredChats.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 48,
                                      color: AppTheme.textTertiary,
                                    ),
                                    SizedBox(height: AppTheme.spaceSm),
                                    Text(
                                      'No chats found',
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: AppTheme.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: filteredChats.length,
                              itemBuilder: (context, index) {
                                final chat = filteredChats[index];
                                final timestamp = chat['updatedAt'];
                                final timeStr = timestamp != null
                                    ? _formatTimestamp(timestamp)
                                    : 'Just now';
                                final isStarred = chat['isStarred'] ?? false;
                                final chatId = chat['id'];
                                final chatTitle = chat['title'];

                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppTheme.spaceSm,
                                    vertical: 2,
                                  ),
                                  child: Dismissible(
                                    key: Key(chatId),
                                    direction: DismissDirection.endToStart,
                                    confirmDismiss: (direction) async {
                                      return await _showDeleteConfirmDialog(
                                        chatTitle,
                                      );
                                    },
                                    onDismissed: (direction) {
                                      _deleteChat(chatId, chatTitle);
                                    },
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: EdgeInsets.only(
                                        right: AppTheme.spaceMd,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.red.withOpacity(0.1),
                                            Colors.red,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusSm,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.pop(context);
                                        _loadChat(chatId, chatTitle);
                                      },
                                      onLongPress: () {
                                        _showChatOptions(
                                          chatId,
                                          chatTitle,
                                          isStarred,
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSm,
                                      ),
                                      child: Container(
                                        padding: EdgeInsets.all(
                                          AppTheme.spaceSm,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: AppTheme.glassGradient,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusSm,
                                          ),
                                          border: isStarred
                                              ? Border.all(
                                                  color: Colors.amber,
                                                  width: 1.5,
                                                )
                                              : null,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(
                                                AppTheme.spaceSm,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors:
                                                      AppTheme.primaryGradient,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppTheme.radiusSm,
                                                    ),
                                              ),
                                              child: Icon(
                                                Icons.chat_bubble_outline,
                                                color: Colors.black,
                                                size: 16,
                                              ),
                                            ),
                                            SizedBox(width: AppTheme.spaceSm),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      if (isStarred)
                                                        Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                                right: 4,
                                                              ),
                                                          child: Icon(
                                                            Icons.star,
                                                            color: Colors.amber,
                                                            size: 14,
                                                          ),
                                                        ),
                                                      Expanded(
                                                        child: Text(
                                                          chatTitle,
                                                          style: AppTheme
                                                              .bodyLarge
                                                              .copyWith(
                                                                color: AppTheme
                                                                    .textPrimary,
                                                              ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    '${chat['messageCount']} messages',
                                                    style: AppTheme.bodySmall
                                                        .copyWith(
                                                          color: AppTheme
                                                              .textTertiary,
                                                        ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              timeStr,
                                              style: AppTheme.bodySmall
                                                  .copyWith(
                                                    color:
                                                        AppTheme.textTertiary,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                        },
                      ),
              ),

              // Footer with settings
              Padding(
                padding: EdgeInsets.all(AppTheme.spaceMd),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/settings');
                  },
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceSm,
                      vertical: AppTheme.spaceSm,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.settings,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                        SizedBox(width: AppTheme.spaceSm),
                        Text(
                          'Settings',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
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
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        drawerEnableOpenDragGesture: true,
        drawer: _buildDrawer(),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Container(
            margin: EdgeInsets.only(left: AppTheme.spaceSm),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: AppTheme.glassGradient),
            ),
            child: IconButton(
              icon: Icon(Icons.menu, color: AppTheme.textPrimary),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: AppTheme.glassGradient),
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.surfaceElevated.withOpacity(0.15),
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
                      colors: AppTheme.primaryGradient,
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
                      colors: AppTheme.primaryGradient,
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
                      _responseMode == 'detailed'
                          ? Icons.menu_book
                          : Icons.article,
                      color: AppTheme.textPrimary,
                    ),
                    tooltip: _responseMode == 'detailed'
                        ? 'Detailed mode'
                        : 'Concise mode',
                    onPressed: () => setState(
                      () => _responseMode = _responseMode == 'detailed'
                          ? 'concise'
                          : 'detailed',
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: AppTheme.textPrimary),
                    onPressed: _openMenu,
                  ),
                ],
              ),
            ),
          ],
        ),
        body: GestureDetector(
          onHorizontalDragEnd: (details) {
            // Swipe left -> Notes (velocity.dx < 0)
            if (details.primaryVelocity! < -300) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotesScreen()),
              );
            }
            // Swipe right -> Chat History (velocity.dx > 0)
            else if (details.primaryVelocity! > 300) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatHistoryScreen()),
              );
            }
          },
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: _showGreeting && _messages.isEmpty
                      ? _buildGreetingUI()
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceLg,
                            vertical: AppTheme.spaceLg,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) {
                            final m = _messages[i];

                            // Show typing indicator for typing messages
                            if (m.isTyping) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: AppTheme.spaceSm,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    TypingIndicator(
                                      message: _currentStatusMessage.isNotEmpty
                                          ? _currentStatusMessage
                                          : 'Generating response...',
                                    ),
                                  ],
                                ),
                              );
                            }

                            // Show streaming text with inline typing indicator
                            if (m.isStreaming) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: AppTheme.spaceSm,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: AiMessageBubble(
                                        text: m.text,
                                        fromUser: m.fromUser,
                                        imagePath: m.imagePath,
                                        gradientColors:
                                            AppTheme.surfaceGradient,
                                        detailedByDefault:
                                            _responseMode == 'detailed',
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: 4,
                                        top: 16,
                                      ),
                                      child: TypingIndicator(),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return AiMessageBubble(
                              text: m.text,
                              fromUser: m.fromUser,
                              imagePath: m.imagePath,
                              gradientColors: m.fromUser
                                  ? AppTheme.primaryGradient
                                  : AppTheme.surfaceGradient,
                              detailedByDefault: _responseMode == 'detailed',
                            );
                          },
                        ),
                ),

                // Modern Input Section (Claude-style unified container)
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundDeep,
                    border: Border(
                      top: BorderSide(
                        color: AppTheme.surfaceElevated.withOpacity(0.15),
                        width: 0.5,
                      ),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    12 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Image Preview (if selected)
                      if (_selectedImage != null)
                        Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.surfaceElevated.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _selectedImage!,
                                  height: 60,
                                  width: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              SizedBox(width: 12),
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

                      // Unified Input Container (Claude-style)
                      Container(
                        constraints: BoxConstraints(
                          minHeight: 52,
                          maxHeight: 140,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: AppTheme.surfaceElevated.withOpacity(0.5),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Plus Button
                            Container(
                              margin: EdgeInsets.only(left: 4, bottom: 4),
                              child: IconButton(
                                icon: Icon(
                                  Icons.add_circle_outline,
                                  color: AppTheme.textPrimary,
                                  size: 26,
                                ),
                                onPressed: _showInputOptionsBottomSheet,
                                padding: EdgeInsets.all(8),
                                constraints: BoxConstraints(),
                              ),
                            ),

                            // Text Input Field
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                textInputAction: TextInputAction.newline,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                style: AppTheme.bodyLarge.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                ),
                                onChanged: (value) {
                                  setState(() {});
                                },
                                decoration: InputDecoration(
                                  hintText: 'Chat with $_selectedModel...',
                                  hintStyle: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.textTertiary,
                                    fontSize: 16,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),

                            // 3-line indicator or Send Button
                            if (_controller.text.trim().isEmpty)
                              Container(
                                margin: EdgeInsets.only(right: 16, bottom: 16),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // Three vertical bars of varying heights
                                    Container(
                                      width: 3,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: AppTheme.textTertiary,
                                        borderRadius: BorderRadius.circular(
                                          1.5,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 3),
                                    Container(
                                      width: 3,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: AppTheme.textTertiary,
                                        borderRadius: BorderRadius.circular(
                                          1.5,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 3),
                                    Container(
                                      width: 3,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: AppTheme.textTertiary,
                                        borderRadius: BorderRadius.circular(
                                          1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Padding(
                                padding: EdgeInsets.only(right: 4, bottom: 4),
                                child: _buildSendButton(),
                              ),

                            // Microphone Button
                            Container(
                              margin: EdgeInsets.only(right: 4, bottom: 4),
                              child: IconButton(
                                icon: Icon(
                                  Icons.mic_none,
                                  color: AppTheme.textPrimary,
                                  size: 24,
                                ),
                                onPressed: _toggleListening,
                                padding: EdgeInsets.all(8),
                                constraints: BoxConstraints(),
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
          ), // Close SafeArea
        ), // Close GestureDetector
      ), // Close Scaffold
    ); // Close Container
  }

  // helper removed; UI uses specific buttons in this screen.

  Widget _buildGreetingUI() {
    return FadeTransition(
      opacity: _greetingFadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Greeting Icon
            GreetingIcon(timeOfDay: GreetingUtils.getTimeOfDay(), size: 80),
            SizedBox(height: AppTheme.spaceLg),

            // Greeting Text
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.space2xl),
              child: Text(
                GreetingUtils.getGreeting(),
                textAlign: TextAlign.center,
                style: AppTheme.displaySmall.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 32,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
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
          colors: AppTheme.primaryGradient,
        ),
        boxShadow: AppTheme.glowShadow,
      ),
      child: IconButton(
        icon: Icon(Icons.arrow_upward, color: Colors.black),
        onPressed: _send,
        iconSize: 20,
      ),
    );
  }

  /// Compress image bytes to reduce request size
  /// Aggressively resizes and reduces quality to keep under 200KB
  Future<Uint8List> _compressImage(
    Uint8List imageBytes, {
    int quality = 50,
  }) async {
    // Check file size and return as-is if already small
    if (imageBytes.length <= 150000) {
      return imageBytes;
    }

    try {
      // Decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        print('Failed to decode image, returning original');
        return imageBytes;
      }

      print('Original image: ${image.width}x${image.height}');

      // Resize more aggressively (max 800px width for smaller file size)
      var compressed = image;
      if (image.width > 800) {
        int newHeight = (image.height * 800 / image.width).toInt();
        compressed = img.copyResize(image, width: 800, height: newHeight);
        print('Resized to: ${compressed.width}x${compressed.height}');
      }

      // Encode as JPEG with quality setting
      final encoded = img.encodeJpg(compressed, quality: quality);
      print('Compressed image size: ${encoded.length} bytes');

      // If still too large, reduce quality further or recurse
      if (encoded.length > 150000 && quality > 20) {
        print(
          'Still too large, reducing quality from $quality to ${quality - 10}...',
        );
        return _compressImage(imageBytes, quality: quality - 10);
      }

      return Uint8List.fromList(encoded);
    } catch (e) {
      print('Image compression failed: $e, returning original');
      return imageBytes;
    }
  }
}

class _Message {
  String text;
  final bool fromUser;
  final String? imagePath;
  final bool isTyping;
  bool isStreaming;
  _Message({
    required this.text,
    required this.fromUser,
    this.imagePath,
    this.isTyping = false,
    this.isStreaming = false,
  });
}
