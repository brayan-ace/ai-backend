import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import '../utils/theme.dart';
import '../utils/ai_constants.dart';
import '../widgets/ai_message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../services/gemini_services.dart';
import '../services/chat_storage_service.dart';
import '../services/web_search_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OnlineAiScreen extends StatefulWidget {
  const OnlineAiScreen({super.key});

  @override
  State<OnlineAiScreen> createState() => _OnlineAiScreenState();
}

class _OnlineAiScreenState extends State<OnlineAiScreen> {
  // API keys with fallback support
  static const String groqApiKey =
      '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';
  static const String openRouterApiKey =
      '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';
  static const String deepSeekApiKey = 'sk-8d17e5b0c355485da07af11f552e37f9';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final List<_Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  String _searchQuery = '';

  // Firebase chat storage
  final ChatStorageService _chatStorage = ChatStorageService();
  String? _currentChatId;
  bool _isSavingEnabled = false;

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

  // Model selection
  String _selectedModel = 'Sirri';

  // Image/File handling
  final ImagePicker _imagePicker = ImagePicker();
  final GeminiService _geminiService = GeminiService();
  File? _selectedImage;
  String? _selectedFileName;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _Message(
        text: 'Welcome — type a message and press send to chat with Sirri AI.',
        fromUser: false,
      ),
    );
    _speech = stt.SpeechToText();
    _initializeSpeech();
    _checkAuthAndEnableSaving();
  }

  /// Check if user is authenticated to enable chat saving
  void _checkAuthAndEnableSaving() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _isSavingEnabled = user != null;
    });
  }

  Future<void> _initializeSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        print('Speech status: $status');
        if (status == 'done' && _isListening) {
          // Auto-restart listening if it stops while user wants to continue
          Future.delayed(Duration(milliseconds: 100), () {
            if (_isListening && mounted) {
              _startListening();
            }
          });
        } else if (status == 'notListening' && _isListening) {
          // Keep the UI showing listening state
          print('Not listening but should be - attempting restart');
        }
      },
      onError: (error) {
        print('Speech error: $error');
        if (_isListening) {
          setState(() => _isListening = false);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Speech recognition error: ${error.errorMsg}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
    setState(() {});
  }

  void _showResponseModeDialog() {
    showDialog(
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
              Icon(Icons.tune, color: AppTheme.primaryBlue),
              SizedBox(width: AppTheme.spaceSm),
              Text(
                'Options',
                style: AppTheme.headlineMedium.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
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
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppTheme.primaryGradient,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(Icons.article, color: Colors.black, size: 20),
                  ),
                  title: Text(
                    'Detailed Analysis',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Comprehensive explanations',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  selected: _responseMode == 'detailed',
                  selectedTileColor: AppTheme.primaryBlue.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  onTap: () {
                    setState(() => _responseMode = 'detailed');
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✓ Detailed Analysis mode activated'),
                        backgroundColor: AppTheme.primaryBlue,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                SizedBox(height: AppTheme.spaceXs),
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: AppTheme.accentGradient),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(Icons.flash_on, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    'Straight to the Point',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Concise answers',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  selected: _responseMode == 'straight',
                  selectedTileColor: AppTheme.accentBlue.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  onTap: () {
                    setState(() => _responseMode = 'straight');
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('⚡ Straight to the Point mode activated'),
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
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF00D9FF), Color(0xFF0099FF)],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(
                      Icons.travel_explore,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Web Search',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    _webSearchEnabled
                        ? 'Enabled - real-time data'
                        : 'Disabled - AI database',
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? '🌐 Web search enabled'
                                : '📚 Using AI database',
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
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.accentBlueLight, AppTheme.accentBlue],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Take Photo',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
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
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                SizedBox(height: AppTheme.spaceXs),
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryBlue,
                          AppTheme.primaryBlueDark,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(
                      Icons.photo_library,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Choose from Gallery',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
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
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
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
                                colors: AppTheme.primaryGradient,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm,
                              ),
                            ),
                            child: Icon(
                              Icons.add_circle_outline,
                              color: Colors.black,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: AppTheme.spaceSm),
                          Text(
                            'Message Options',
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
                        subtitle: 'Speak your message',
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
                      SizedBox(height: AppTheme.spaceSm),
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
            gradient: LinearGradient(colors: AppTheme.primaryGradient),
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
                    description: 'Advanced reasoning & complex problems',
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

  void _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Speech recognition not available'),
          backgroundColor: AppTheme.surfaceElevated,
        ),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      _startListening();
    }
  }

  void _startListening() async {
    if (!_isListening || !_speechAvailable) return;

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
        });
      },
      listenFor: Duration(minutes: 10), // Listen for up to 10 minutes
      pauseFor: Duration(
        minutes: 2,
      ), // Wait 2 minutes of silence before stopping
      partialResults: true, // Show results as user speaks
      cancelOnError: false, // Don't cancel on errors
      listenMode: stt.ListenMode.dictation, // Better for longer speech
      onSoundLevelChange: (level) {
        // Keep session alive when sound is detected
      },
    );
  }

  @override
  void dispose() {
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

    // Add typing indicator immediately
    setState(() {
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

    // If image is attached, use Gemini Vision API
    if (hasImage && imageFile != null) {
      try {
        print('========================================');
        print('Processing image for Gemini Vision API');
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
        setState(() => _isSearchingWeb = true);
        try {
          final searchResults = await _webSearchService.search(query: text);
          final enhancedPrompt = _webSearchService.createEnhancedPrompt(
            text,
            searchResults,
          );
          setState(() => _isSearchingWeb = false);
          response = await _callWithFallback(enhancedPrompt);
        } catch (e) {
          setState(() => _isSearchingWeb = false);
          response = '⚠️ Web search error: $e\n\nTrying AI database...';
          response = await _callWithFallback(text);
        }
      } else {
        // Try AI database first
        response = await _callWithFallback(text);

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
              _isSearchingWeb = true;
            });

            try {
              final searchResults = await _webSearchService.search(query: text);
              final enhancedPrompt = _webSearchService.createEnhancedPrompt(
                text,
                searchResults,
              );
              setState(() => _isSearchingWeb = false);
              response = await _callWithFallback(enhancedPrompt);

              // Remove search indicator
              setState(() {
                if (_messages.isNotEmpty &&
                    _messages.last.text == '🔍 Searching the web...') {
                  _messages.removeLast();
                }
              });
            } catch (e) {
              setState(() {
                _isSearchingWeb = false;
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

      // Build conversation history
      final conversationMessages = <Map<String, String>>[
        {
          'role': 'system',
          'content': _responseMode == 'straight'
              ? 'You are Sirri AI. Provide CONCISE, DIRECT answers without DETAILED explanations. Get straight to the point. Use markdown and LaTeX for math (\$formula\$ for inline, \$\$formula\$\$ for display). No lengthy examples unless specifically asked'
              : AiConstants.systemPrompt,
        },
      ];

      // Add conversation history (last 20 messages for context)
      final historyMessages = _messages.length > 20
          ? _messages.sublist(_messages.length - 20)
          : _messages;

      for (final msg in historyMessages) {
        conversationMessages.add({
          'role': msg.fromUser ? 'user' : 'assistant',
          'content': msg.text,
        });
      }

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': conversationMessages,
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

      // Build conversation history
      final conversationMessages = <Map<String, String>>[
        {
          'role': 'system',
          'content': _responseMode == 'straight'
              ? 'You are Sirri AI. Provide CONCISE, DIRECT answers without extra explanations. Get straight to the point. Use markdown and LaTeX for math (\$formula\$ for inline, \$\$formula\$\$ for display). No lengthy examples unless specifically asked.'
              : AiConstants.systemPrompt,
        },
      ];

      // Add conversation history (last 20 messages for context)
      final historyMessages = _messages.length > 20
          ? _messages.sublist(_messages.length - 20)
          : _messages;

      for (final msg in historyMessages) {
        conversationMessages.add({
          'role': msg.fromUser ? 'user' : 'assistant',
          'content': msg.text,
        });
      }

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'meta-llama/llama-3.1-8b-instruct:free',
          'messages': conversationMessages,
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

      // Build conversation history
      final conversationMessages = <Map<String, String>>[
        {
          'role': 'system',
          'content': _responseMode == 'straight'
              ? 'You are Sirri AI. Provide CONCISE, DIRECT answers without extra explanations. Get straight to the point. Use markdown and LaTeX for math (\$formula\$ for inline, \$\$formula\$\$ for display). No lengthy examples unless specifically asked.'
              : AiConstants.systemPrompt,
        },
      ];

      // Add conversation history (last 20 messages for context)
      final historyMessages = _messages.length > 20
          ? _messages.sublist(_messages.length - 20)
          : _messages;

      for (final msg in historyMessages) {
        conversationMessages.add({
          'role': msg.fromUser ? 'user' : 'assistant',
          'content': msg.text,
        });
      }

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'deepseek-chat',
          'messages': conversationMessages,
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

  /// Load a chat from history
  Future<void> _loadChat(String chatId, String title) async {
    try {
      setState(() {
        _messages.clear();
        _currentChatId = chatId;
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
          _messages.add(
            _Message(
              text:
                  'Welcome — type a message and press send to chat with Sirri AI.',
              fromUser: false,
            ),
          );
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

  void _notImplemented(String what) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$what not implemented yet')));
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppTheme.surfaceGradient,
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppTheme.radiusXl),
              topRight: Radius.circular(AppTheme.radiusXl),
            ),
            border: Border(
              top: BorderSide(
                color: AppTheme.primaryBlue.withOpacity(0.3),
                width: 1,
              ),
            ),
            boxShadow: AppTheme.elevatedShadow,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: AppTheme.spaceSm),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),
                _buildMenuItem(
                  ctx,
                  icon: Icons.history,
                  title: 'Previous Chats',
                  gradient: AppTheme.accentGradient,
                  onTap: () {
                    Navigator.pop(ctx);
                    _notImplemented('Previous chats');
                  },
                ),
                _buildMenuItem(
                  ctx,
                  icon: Icons.add_circle_outline,
                  title: 'New Chat',
                  gradient: AppTheme.primaryGradient,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _messages.clear();
                      _currentChatId = null; // Start a new chat
                      _messages.add(
                        _Message(
                          text: 'New chat started! How can I help you?',
                          fromUser: false,
                        ),
                      );
                    });
                  },
                ),
                _buildMenuItem(
                  ctx,
                  icon: Icons.settings,
                  title: 'Settings',
                  gradient: AppTheme.surfaceGradient,
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/settings');
                  },
                ),
                SizedBox(height: AppTheme.spaceLg),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      child: InkWell(
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
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
              SizedBox(width: AppTheme.spaceMd),
              Text(
                title,
                style: AppTheme.labelLarge.copyWith(
                  color: AppTheme.textPrimary,
                ),
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
                            _messages.add(
                              _Message(
                                text: 'New chat started! How can I help you?',
                                fromUser: false,
                              ),
                            );
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

                          // Filter chats based on search query
                          final filteredChats = _searchQuery.isEmpty
                              ? allChats
                              : allChats.where((chat) {
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
                                    _searchQuery.isEmpty
                                        ? Icons.chat_bubble_outline
                                        : Icons.search_off,
                                    size: 48,
                                    color: AppTheme.textTertiary,
                                  ),
                                  SizedBox(height: AppTheme.spaceSm),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'No chats yet'
                                        : 'No chats found',
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                  if (_searchQuery.isEmpty)
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
                                      padding: EdgeInsets.all(AppTheme.spaceSm),
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
                                            style: AppTheme.bodySmall.copyWith(
                                              color: AppTheme.textTertiary,
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
              child: IconButton(
                icon: Icon(Icons.more_vert, color: AppTheme.textPrimary),
                onPressed: _openMenu,
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
                  itemBuilder: (context, i) {
                    final m = _messages[i];

                    // Show typing indicator for typing messages
                    if (m.isTyping) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: AppTheme.spaceSm),
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
                      );
                    }

                    // Show streaming text with inline typing indicator
                    if (m.isStreaming) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: AppTheme.spaceSm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AiMessageBubble(
                                text: m.text,
                                fromUser: m.fromUser,
                                imagePath: m.imagePath,
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

                    return AiMessageBubble(
                      text: m.text,
                      fromUser: m.fromUser,
                      imagePath: m.imagePath,
                      gradientColors: m.fromUser
                          ? AppTheme.primaryGradient
                          : AppTheme.surfaceGradient,
                    );
                  },
                ),
              ),

              // Recording UI (shows when listening)
              if (_isListening)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppTheme.accentGradient),
                    boxShadow: AppTheme.accentGlow,
                  ),
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(AppTheme.spaceSm),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.mic, color: Colors.white, size: 20),
                      ),
                      SizedBox(width: AppTheme.spaceSm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Listening...',
                              style: AppTheme.bodyLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_controller.text.isNotEmpty)
                              Text(
                                _controller.text,
                                style: AppTheme.bodySmall.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.stop, color: Colors.white),
                        onPressed: _toggleListening,
                      ),
                    ],
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
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
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
                                      hintText: 'Chat with Sirri AI...',
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
                                        colors: AppTheme.primaryGradient,
                                      ),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: EdgeInsets.only(
                                      right: 6,
                                      bottom: 6,
                                    ),
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
