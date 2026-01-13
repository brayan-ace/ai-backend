import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
import 'notes_screen.dart';
import 'chat_history_screen.dart';

class OnlineAiScreen extends StatefulWidget {
  const OnlineAiScreen({super.key});

  @override
  State<OnlineAiScreen> createState() => _OnlineAiScreenState();
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
  String _responseMode = 'normal';
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

  late ScrollController _messageScrollController;
  bool _showScrollButton = false;
  static const double _scrollThreshold = 100.0;

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiService();
    _webSearchService = WebSearchService();
    _chatStorage = ChatStorageService();

    _messageScrollController = ScrollController();
    _messageScrollController.addListener(_onScrollListener);

    _greetingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _greetingFadeAnimation = CurvedAnimation(
      parent: _greetingAnimationController,
      curve: Curves.easeInOut,
    );
    _greetingAnimationController.forward();

    _isSavingEnabled = FirebaseAuth.instance.currentUser != null;
    _authStateStream = FirebaseAuth.instance.authStateChanges();
    _authSub = _authStateStream.listen((user) {
      setState(() {
        _isSavingEnabled = user != null;
        if (user == null) {
          _currentChatId = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _greetingAnimationController.dispose();
    _authSub.cancel();
    _controller.dispose();
    _searchController.dispose();
    _messageScrollController.removeListener(_onScrollListener);
    _messageScrollController.dispose();
    super.dispose();
  }

  void _onScrollListener() {
    if (!mounted) return;

    final scrollHeight = _messageScrollController.position.maxScrollExtent;
    final scrollTop = _messageScrollController.position.pixels;
    final clientHeight = _messageScrollController.position.viewportDimension;

    final isAtBottom =
        (scrollTop + clientHeight >= scrollHeight - _scrollThreshold);

    if (!isAtBottom && !_showScrollButton) {
      setState(() => _showScrollButton = true);
    } else if (isAtBottom && _showScrollButton) {
      setState(() => _showScrollButton = false);
    }
  }

  Future<void> _scrollToLatestMessage() async {
    if (!mounted || _messageScrollController.positions.isEmpty) return;

    try {
      final maxScroll = _messageScrollController.position.maxScrollExtent;
      await _messageScrollController.animateTo(
        maxScroll,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } catch (e) {
      debugPrint('[Scroll Button] Error scrolling: $e');
    }
  }

  Widget _buildScrollButton() {
    if (!_showScrollButton) return const SizedBox.shrink();

    return Positioned(
      bottom: MediaQuery.of(context).viewInsets.bottom + 72,
      right: 20,
      child: GestureDetector(
        onTap: _scrollToLatestMessage,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryBlue,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(Icons.expand_more, color: Colors.white, size: 20),
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
                      Container(
                        margin: EdgeInsets.only(top: 12),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.textTertiary.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(height: 28),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
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
                            SizedBox(width: 40),
                          ],
                        ),
                      ),
                      SizedBox(height: 32),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
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
                      Divider(
                        color: AppTheme.surfaceElevated.withValues(alpha: 0.3),
                        height: 1,
                        thickness: 1,
                      ),
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
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(
                        color: AppTheme.surfaceElevated.withValues(alpha: 0.3),
                        height: 1,
                        thickness: 1,
                      ),
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
                                    : 'Normal',
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
            color: AppTheme.surfaceElevated.withValues(alpha: 0.5),
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
                Container(
                  margin: EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Use style',
                  style: AppTheme.headlineMedium.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 24),
                InkWell(
                  onTap: () {
                    setState(() => _responseMode = 'normal');
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    color: _responseMode == 'normal'
                        ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        Icon(
                          Icons.flash_on_outlined,
                          color: _responseMode == 'normal'
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
                                'Normal',
                                style: AppTheme.bodyLarge.copyWith(
                                  color: _responseMode == 'normal'
                                      ? AppTheme.primaryBlue
                                      : AppTheme.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Natural and conversational responses',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_responseMode == 'normal')
                          Icon(
                            Icons.check_circle,
                            color: AppTheme.primaryBlue,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() => _responseMode = 'detailed');
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    color: _responseMode == 'detailed'
                        ? AppTheme.primaryBlue.withValues(alpha: 0.1)
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
            color: AppTheme.backgroundDeep,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppTheme.radiusLg),
              topRight: Radius.circular(AppTheme.radiusLg),
            ),
          ),
          child: SafeArea(child: Text('Model selector - placeholder')),
        );
      },
    );
  }

  void _toggleListening() async {
    final transcribedText = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => const VoiceInputDialog(),
    );

    if (transcribedText != null && transcribedText.isNotEmpty) {
      setState(() {
        _controller.text = transcribedText;
      });
    }
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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _selectedModel,
            style: AppTheme.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _messageScrollController,
                      padding: EdgeInsets.all(AppTheme.spaceLg),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        if (m.isTyping) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: AppTheme.spaceSm),
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
                        return _buildMessageBubble(m);
                      },
                    ),
                    _buildScrollButton(),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.backgroundDeep,
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.surfaceElevated.withValues(alpha: 0.15),
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
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: AppTheme.surfaceElevated.withValues(
                              alpha: 0.5,
                            ),
                            width: 1,
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMd,
                        ),
                        child: TextField(
                          controller: _controller,
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textTertiary,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: AppTheme.spaceSm),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: AppTheme.primaryGradient,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.send, color: Colors.white),
                        onPressed: _send,
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
                      ? AppTheme.primaryGradient
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
      // User messages: plain text with wrapping
      return Text(
        text,
        style: AppTheme.bodyLarge.copyWith(color: Colors.white, height: 1.5),
        softWrap: true,
      );
    }

    // AI messages: use markdown for rich formatting
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
      onTapLink: (text, href, title) {
        if (href != null) {
          debugPrint('Link tapped: $href');
        }
      },
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_Message(text: text, fromUser: true));
      _controller.clear();
      _messages.add(_Message(text: '', fromUser: false, isTyping: true));
    });

    try {
      final response = await ApiService.sendRaw('chat', {
        'message': text,
        'mode': _responseMode,
        'model': _selectedModel.toLowerCase(),
      });

      final reply = response['reply'] ?? response['response'] ?? 'No response';

      setState(() {
        if (_messages.isNotEmpty && _messages.last.isTyping) {
          _messages.removeLast();
        }
        _messages.add(_Message(text: reply.toString(), fromUser: false));
      });
    } catch (e) {
      setState(() {
        if (_messages.isNotEmpty && _messages.last.isTyping) {
          _messages.removeLast();
        }
        _messages.add(
          _Message(text: 'Error: ${e.toString()}', fromUser: false),
        );
      });
    }
  }

  Future<Uint8List> _compressImage(
    Uint8List imageBytes, {
    int quality = 50,
  }) async {
    if (imageBytes.length <= 150000) {
      return imageBytes;
    }

    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        return imageBytes;
      }

      var compressed = image;
      if (image.width > 800) {
        int newHeight = (image.height * 800 / image.width).toInt();
        compressed = img.copyResize(image, width: 800, height: newHeight);
      }

      final encoded = img.encodeJpg(compressed, quality: quality);

      if (encoded.length > 150000 && quality > 20) {
        return _compressImage(imageBytes, quality: quality - 10);
      }

      return Uint8List.fromList(encoded);
    } catch (e) {
      return imageBytes;
    }
  }
}

class _Message {
  String text;
  final bool fromUser;
  final String? imagePath;
  final bool isTyping;

  _Message({
    required this.text,
    required this.fromUser,
    this.imagePath,
    this.isTyping = false,
  });
}
