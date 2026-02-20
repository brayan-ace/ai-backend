import 'dart:convert';
import 'dart:io';
import 'dart:async';
// 'dart:typed_data' is available via 'package:flutter/services.dart'
import 'package:image/image.dart' as img;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme.dart';
import '../utils/greeting_utils.dart';
import '../utils/app_localizations.dart';
import '../widgets/ai_message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/voice_input_dialog.dart';
import '../widgets/streak_indicator.dart';
import '../widgets/streak_details_modal.dart';
import '../services/gemini_services.dart';
import '../services/api_service.dart';
import '../services/web_search_service.dart';
import '../services/settings_service.dart';
import '../utils/ai_constants.dart';
import '../services/chat_storage_service.dart';
import '../services/user_profile_service.dart';
import 'notes_screen.dart';
import 'chat_history_screen.dart';
import 'bot_creation_screen.dart';
import '../services/onboarding_service.dart';
import '../utils/onboarding_config.dart';

class OnlineAiScreen extends StatefulWidget {
  const OnlineAiScreen({Key? key}) : super(key: key);

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
  bool _wasWebSearchAutoEnabledThisRequest = false;
  String _responseMode = 'normal';
  bool _showGreeting = true;
  bool _isFullScreen = false;
  bool _skipDeleteConfirmation = false;

  File? _selectedImage;
  String? _selectedFileName;

  final List<_Message> _messages = [];
  String _currentStatusMessage = '';

  bool _isSavingEnabled = false;
  String? _currentChatId;

  late GeminiService _geminiService;
  late WebSearchService _webSearchService;
  late ChatStorageService _chatStorage;
  late SettingsService _settingsService;

  String _selectedModel = 'Groq Pro';
  String _searchQuery = '';

  late ScrollController _messageScrollController;
  bool _showScrollButton = false;
  static const double _scrollThreshold = 100.0;

  // Onboarding state

  bool _onboardingInitialized = false;

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiService();
    _webSearchService = WebSearchService();
    _chatStorage = ChatStorageService();
    _settingsService = SettingsService.instance;

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

    // Defer non-critical loading to after UI appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWebSearchCapability();
      _initializeOnboarding();
      _loadDeleteConfirmationPreference();
    });
  }

  Future<void> _loadWebSearchCapability() async {
    try {
      await _settingsService.init();
      final webSearchEnabled = await _settingsService.getWebSearchCapability();
      if (mounted) {
        setState(() {
          _webSearchEnabled = webSearchEnabled;
          print('[OnlineAI] Web search loaded: $webSearchEnabled');
        });
      }
    } catch (e) {
      print('Error loading web search capability: $e');
      // Default to false if there's an error
      if (mounted) {
        setState(() => _webSearchEnabled = false);
      }
    }
  }

  Future<void> _refreshWebSearchCapability() async {
    try {
      final webSearchEnabled = await _settingsService.getWebSearchCapability();
      if (mounted) {
        setState(() {
          _webSearchEnabled = webSearchEnabled;
          print('[OnlineAI] Web search refreshed: $webSearchEnabled');
        });
      }
    } catch (e) {
      print('Error refreshing web search capability: $e');
    }
  }

  Future<void> _loadDeleteConfirmationPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skipConfirmation =
          prefs.getBool('skip_delete_confirmation') ?? false;
      if (mounted) {
        setState(() {
          _skipDeleteConfirmation = skipConfirmation;
        });
      }
    } catch (e) {
      print('Error loading delete confirmation preference: $e');
    }
  }

  Future<void> _initializeOnboarding() async {
    if (_onboardingInitialized) return;

    try {
      final shouldShow = await OnboardingService.shouldShowOnboarding();
      if (shouldShow && mounted) {
        setState(() {
          //_showOnboarding = true;
          _onboardingInitialized = true;
        });
      }
    } catch (e) {
      // If onboarding check fails, don't show it to avoid blocking the app
      print('Onboarding initialization failed: $e');
    }
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

  /// Convert display model name to backend API name
  String _getBackendModelName(String displayName) {
    if (displayName == 'Sonnet 3.5') {
      return 'claude-sonnet';
    } else if (displayName == 'Gemini 2.0') {
      return 'gemini';
    } else if (displayName == 'Groq Pro') {
      return 'groq';
    }
    return displayName.toLowerCase();
  }

  /// Helper: log AI message details and add to UI state
  void _logAndAddAiMessage(String text) {
    final hasNewlines = text.contains('\n');
    print('📥 [Frontend Received] len=${text.length} hasNewlines=$hasNewlines');
    final preview = text.runes.length > 800
        ? String.fromCharCodes(text.runes.take(800)) + '...'
        : text;
    print('📥 [Frontend Preview] $preview');
    setState(() {
      _messages.add(_Message(text: text, fromUser: false));
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
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', isError: true);
    }
  }

  void _showInputOptionsBottomSheet() {
    // Refresh web search capability before showing modal
    _refreshWebSearchCapability();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.backgroundDeep
                    : Color(0xFFFFFFFF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusLg),
                  topRight: Radius.circular(AppTheme.radiusLg),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: EdgeInsets.only(top: 12),
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.textTertiary.withValues(alpha: 0.4)
                                : Color(0xFFD1D5DB),
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
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppTheme.textPrimary
                                      : Color(0xFF1F2937),
                                  size: 24,
                                ),
                                onPressed: () => Navigator.pop(context),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                              ),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  ).t('chatScreen.addToChat'),
                                  textAlign: TextAlign.center,
                                  style: AppTheme.headlineMedium.copyWith(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppTheme.textPrimary
                                        : Color(0xFF000000),
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
                                  label: AppLocalizations.of(
                                    context,
                                  ).t('chatScreen.camera'),
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
                                  label: AppLocalizations.of(
                                    context,
                                  ).t('chatScreen.photos'),
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
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.surfaceElevated.withValues(alpha: 0.3)
                              : Color(0xFFE5E7EB),
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
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppTheme.textPrimary
                                      : Color(0xFF1F2937),
                                  size: 24,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  ).t('chatScreen.webSearch'),
                                  style: AppTheme.bodyLarge.copyWith(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppTheme.textPrimary
                                        : Color(0xFF000000),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                Spacer(),
                                Switch(
                                  value: _webSearchEnabled,
                                  onChanged: (value) async {
                                    print(
                                      '[OnlineAI] Toggling WebSearch to: $value',
                                    );
                                    setModalState(() {
                                      setState(() {
                                        _webSearchEnabled = value;
                                      });
                                    });
                                    // Save to SettingsService
                                    await _settingsService
                                        .setWebSearchCapability(value);
                                    print(
                                      '[OnlineAI] WebSearch saved successfully: $value',
                                    );
                                  },
                                  activeThumbColor: AppTheme.primaryBlue,
                                  activeTrackColor: AppTheme.primaryBlue
                                      .withValues(alpha: 0.5),
                                ),
                              ],
                            ),
                          ),
                        ),

                        Divider(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.surfaceElevated.withValues(alpha: 0.3)
                              : Color(0xFFE5E7EB),
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
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppTheme.textPrimary
                                      : Color(0xFF1F2937),
                                  size: 24,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  ).t('chatScreen.useStyle'),
                                  style: AppTheme.bodyLarge.copyWith(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppTheme.textPrimary
                                        : Color(0xFF000000),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                Spacer(),
                                Text(
                                  _responseMode == 'detailed'
                                      ? AppLocalizations.of(
                                          context,
                                        ).t('chatScreen.detailed')
                                      : AppLocalizations.of(
                                          context,
                                        ).t('chatScreen.normal'),
                                  style: AppTheme.bodyMedium.copyWith(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppTheme.textSecondary
                                        : Color(0xFF6B7280),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.chevron_right,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppTheme.textSecondary
                                      : Color(0xFF6B7280),
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
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.surfaceCard
              : Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.surfaceElevated.withValues(alpha: 0.5)
                : Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.textPrimary
                  : Color(0xFF1F2937),
              size: 36,
            ),
            SizedBox(height: 14),
            Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.textPrimary
                    : Color(0xFF000000),
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
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.backgroundDeep
                : Color(0xFFFFFFFF),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppTheme.radiusLg),
              topRight: Radius.circular(AppTheme.radiusLg),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.textTertiary.withValues(alpha: 0.4)
                          : Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 20),

                  Text(
                    AppLocalizations.of(context).t('chatScreen.useStyle'),
                    style: AppTheme.headlineMedium.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.textPrimary
                          : Color(0xFF000000),
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      color: _responseMode == 'normal'
                          ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                          : Colors.transparent,
                      child: Row(
                        children: [
                          Icon(
                            Icons.flash_on_outlined,
                            color: _responseMode == 'normal'
                                ? AppTheme.primaryBlue
                                : (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppTheme.textPrimary
                                      : Color(0xFF1F2937)),
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  ).t('models.normal'),
                                  style: AppTheme.bodyLarge.copyWith(
                                    color: _responseMode == 'normal'
                                        ? AppTheme.primaryBlue
                                        : (Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? AppTheme.textPrimary
                                              : Color(0xFF000000)),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  ).t('models.normalDesc'),
                                  style: AppTheme.bodySmall.copyWith(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppTheme.textSecondary
                                        : Color(0xFF6B7280),
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
                      // TODO: Check user's premium status here
                      // For now, show premium dialog
                      Navigator.pop(context);
                      _showPremiumRequiredDialog();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: _responseMode == 'detailed'
                            ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                            : Colors.transparent,
                        border: Border.all(
                          color: AppTheme.warning.withOpacity(0.3),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              Icon(
                                Icons.article_outlined,
                                color: _responseMode == 'detailed'
                                    ? AppTheme.primaryBlue
                                    : (Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppTheme.textPrimary
                                          : Color(0xFF1F2937)),
                                size: 24,
                              ),
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.star,
                                    color: Colors.white,
                                    size: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      AppLocalizations.of(
                                        context,
                                      ).t('models.detailed'),
                                      style: AppTheme.bodyLarge.copyWith(
                                        color: _responseMode == 'detailed'
                                            ? AppTheme.primaryBlue
                                            : (Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? AppTheme.textPrimary
                                                  : Color(0xFF000000)),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.warning,
                                            Color(0xFFFF8C00),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'PREMIUM',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'In-depth explanations with examples',
                                  style: AppTheme.bodySmall.copyWith(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppTheme.textSecondary
                                        : Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: AppTheme.warning,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20),
                ],
              ),
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
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            gradient: Theme.of(context).brightness == Brightness.dark
                ? LinearGradient(colors: AppTheme.surfaceGradient)
                : LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFFAFAFA)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppTheme.radiusXl),
              topRight: Radius.circular(AppTheme.radiusXl),
            ),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.surfaceElevated.withValues(alpha: 0.3)
                  : Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spaceLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.textTertiary.withValues(alpha: 0.3)
                            : Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: AppTheme.spaceMd),

                    Text(
                      AppLocalizations.of(context).t('models.selectAiModel'),
                      style: AppTheme.headlineSmall.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.textPrimary
                            : Color(0xFF000000),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: AppTheme.spaceLg),

                    _buildModelOption(
                      name: AppLocalizations.of(context).t('models.sonnet'),
                      description: AppLocalizations.of(
                        context,
                      ).t('models.sonnetDesc'),
                      isSelected: _selectedModel == 'Sonnet 3.5',
                      gradient: AppTheme.primaryGradient,
                      onTap: () {
                        setState(() => _selectedModel = 'Sonnet 3.5');
                        Navigator.pop(context);
                      },
                    ),
                    SizedBox(height: AppTheme.spaceSm),
                    _buildModelOption(
                      name: AppLocalizations.of(context).t('models.gemini'),
                      description: AppLocalizations.of(
                        context,
                      ).t('models.geminiDesc'),
                      isSelected: _selectedModel == 'Gemini 2.0',
                      gradient: AppTheme.accentGradient,
                      onTap: () {
                        setState(() => _selectedModel = 'Gemini 2.0');
                        Navigator.pop(context);
                      },
                    ),
                    SizedBox(height: AppTheme.spaceSm),
                    _buildModelOption(
                      name: AppLocalizations.of(context).t('models.groq'),
                      description: AppLocalizations.of(
                        context,
                      ).t('models.groqDesc'),
                      isSelected: _selectedModel == 'Groq Pro',
                      gradient: [AppTheme.primaryBlue, AppTheme.accentBlue],
                      onTap: () {
                        setState(() => _selectedModel = 'Groq Pro');
                        Navigator.pop(context);
                      },
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
          gradient: Theme.of(context).brightness == Brightness.dark
              ? LinearGradient(
                  colors: isSelected
                      ? gradient.map((c) => c.withValues(alpha: 0.2)).toList()
                      : AppTheme.glassGradient,
                )
              : LinearGradient(
                  colors: isSelected
                      ? [Color(0xFFF0F4FF), Color(0xFFF9FAFB)]
                      : [Color(0xFFFAFAFA), Color(0xFFF5F5F5)],
                ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? (isSelected
                      ? gradient[0]
                      : AppTheme.surfaceElevated.withValues(alpha: 0.5))
                : (isSelected ? gradient[0] : Color(0xFFE5E7EB)),
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
                          color: gradient[0].withValues(alpha: 0.4),
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
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.textPrimary
                          : Color(0xFF000000),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    description,
                    style: AppTheme.bodySmall.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.textSecondary
                          : Color(0xFF6B7280),
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
    final transcribedText = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => const VoiceInputDialog(),
    );

    if (transcribedText != null && transcribedText.isNotEmpty) {
      setState(() {
        _controller.text = transcribedText;
      });
      // Optionally auto-send the message
      // await _sendMessage();
    }
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
      print('[Scroll Button] Error scrolling: $e');
    }
  }

  Widget _buildScrollButton() {
    if (!_showScrollButton) return const SizedBox.shrink();
    return Positioned(
      bottom: MediaQuery.of(context).viewInsets.bottom + 72,
      right: 20,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 300),
        child: GestureDetector(
          onTap: _scrollToLatestMessage,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryBlue,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(Icons.expand_more, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();

    if (text.isEmpty && _selectedImage == null) return;

    final hasImage = _selectedImage != null;
    final imageFile = _selectedImage;
    final imageName = _selectedFileName;

    if (_showGreeting) {
      _greetingAnimationController.reverse().then((_) {
        setState(() {
          _showGreeting = false;
        });
      });
    }

    setState(() {
      _messages.add(
        _Message(
          text: text,
          fromUser: true,
          imagePath: hasImage ? imageFile?.path : null,
        ),
      );
      _controller.clear();
      _selectedImage = null;
      _selectedFileName = null;
    });

    setState(() {
      _currentStatusMessage = hasImage
          ? 'Analyzing image...'
          : 'Generating response...';
      _messages.add(_Message(text: '', fromUser: false, isTyping: true));
    });

    if (_isSavingEnabled && _currentChatId == null) {
      try {
        _currentChatId = await _chatStorage.createChat(title: text);
      } catch (e) {
        _showSnackBar('Error creating chat: $e', isError: true);
      }
    }

    if (_isSavingEnabled && _currentChatId != null) {
      try {
        await _chatStorage.saveMessage(
          chatId: _currentChatId!,
          text: hasImage ? '$text\n📎 Image: $imageName' : text,
          fromUser: true,
        );
      } catch (e) {
        _showSnackBar('Error saving user message: $e', isError: true);
      }
    }

    String? response;

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
        print('🔍 [RAW IDENTITY RESPONSE] ${reply.toString()}');
        _logAndAddAiMessage(reply.toString());

        if (raw['identityOffered'] == true) {
          if (mounted) {
            final consent = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Show founder?'),
                content: Text(
                  'Would you like to know my founder or my builder?',
                ),
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
              final reply2 =
                  raw2['reply'] ?? raw2['response'] ?? raw2.toString();
              print('🔍 [RAW IDENTITY REVEAL RESPONSE] ${reply2.toString()}');
              _logAndAddAiMessage(reply2.toString());
            }
          }
        }

        handledLocally = true;
      } catch (e) {
        _showSnackBar('Identity flow error: $e', isError: true);
      }
    }

    if (handledLocally) {
      setState(() {
        if (_messages.isNotEmpty && _messages.last.isTyping) {
          _messages.removeLast();
        }
      });
      return;
    }

    if (hasImage && imageFile != null) {
      try {
        var bytes = await imageFile.readAsBytes();

        if (bytes.length > 300000) {
          bytes = await _compressImage(bytes, quality: 50);
        }

        final base64Image = base64Encode(bytes);

        String mimeType = 'image/jpeg';
        if (imageFile.path.toLowerCase().endsWith('.png')) {
          mimeType = 'image/png';
        } else if (imageFile.path.toLowerCase().endsWith('.gif')) {
          mimeType = 'image/gif';
        } else if (imageFile.path.toLowerCase().endsWith('.webp')) {
          mimeType = 'image/webp';
        }

        response = await _geminiService.generateContentWithImage(
          prompt: text,
          base64Image: base64Image,
          mimeType: mimeType,
        );
      } catch (e, stackTrace) {
        _showSnackBar('Error processing image: $e', isError: true);
        print('Stack trace: $stackTrace');
        response = '⚠️ Error processing image: $e';
      }
    } else {
      final instructions = _extractInstructionsFromText(text);
      response = await _callWithFallback(text, instructions: instructions);
    }

    setState(() {
      if (_messages.isNotEmpty && _messages.last.isTyping) {
        _messages.removeLast();
      }
    });

    if (response != null) {
      await _streamResponse(response);

      if (_isSavingEnabled && _currentChatId != null) {
        try {
          await _chatStorage.saveMessage(
            chatId: _currentChatId!,
            text: response,
            fromUser: false,
          );
        } catch (e) {
          _showSnackBar('Error saving AI response: $e', isError: true);
        }
      }
    } else {
      _logAndAddAiMessage('No response');
    }
  }

  /// Regenerate the response for an AI message by resending the previous user message
  Future<void> _regenerateResponse(int aiMessageIndex) async {
    // Find the previous user message
    int? userMessageIndex;
    for (int i = aiMessageIndex - 1; i >= 0; i--) {
      if (_messages[i].fromUser) {
        userMessageIndex = i;
        break;
      }
    }

    if (userMessageIndex == null) {
      _showSnackBar('Could not find previous message', isError: true);
      return;
    }

    final userMessage = _messages[userMessageIndex];
    final userText = userMessage.text;
    final userImage = userMessage.imagePath;

    if (userText.isEmpty) {
      _showSnackBar('Previous message is empty', isError: true);
      return;
    }

    // Remove the old AI response
    setState(() {
      if (aiMessageIndex < _messages.length) {
        _messages.removeAt(aiMessageIndex);
      }
      _currentStatusMessage = userImage != null
          ? 'Analyzing image...'
          : 'Regenerating response...';
      _messages.add(_Message(text: '', fromUser: false, isTyping: true));
    });

    String? response;

    // Handle image if present
    if (userImage != null && userImage.isNotEmpty) {
      try {
        final imageFile = File(userImage);
        var bytes = await imageFile.readAsBytes();

        if (bytes.length > 300000) {
          bytes = await _compressImage(bytes, quality: 50);
        }

        final base64Image = base64Encode(bytes);

        String mimeType = 'image/jpeg';
        if (imageFile.path.toLowerCase().endsWith('.png')) {
          mimeType = 'image/png';
        } else if (imageFile.path.toLowerCase().endsWith('.gif')) {
          mimeType = 'image/gif';
        } else if (imageFile.path.toLowerCase().endsWith('.webp')) {
          mimeType = 'image/webp';
        }

        response = await _geminiService.generateContentWithImage(
          prompt: userText,
          base64Image: base64Image,
          mimeType: mimeType,
        );
      } catch (e, stackTrace) {
        _showSnackBar('Error processing image: $e', isError: true);
        print('Stack trace: $stackTrace');
        response = '⚠️ Error processing image: $e';
      }
    } else {
      // Regular text message - resend to backend
      try {
        final fullResp = await ApiService.sendRaw('chat', {
          'message': userText,
        });

        final reply = fullResp['reply'] ?? fullResp['response'] ?? '';
        print(
          '🔍 [REGENERATE RAW AI RESPONSE] length=${reply.toString().length}',
        );
        response = reply.isEmpty ? null : reply.toString();
      } catch (e) {
        response = '⚠️ Regeneration failed: $e';
      }
    }

    setState(() {
      if (_messages.isNotEmpty && _messages.last.isTyping) {
        _messages.removeLast();
      }
    });

    if (response != null) {
      await _streamResponse(response);

      if (_isSavingEnabled && _currentChatId != null) {
        try {
          await _chatStorage.saveMessage(
            chatId: _currentChatId!,
            text: response,
            fromUser: false,
          );
        } catch (e) {
          _showSnackBar('Error saving regenerated response: $e', isError: true);
        }
      }
    } else {
      _logAndAddAiMessage('No response');
    }
  }

  Future<void> _streamResponse(String fullResponse) async {
    final streamingMessage = _Message(
      text: '',
      fromUser: false,
      isStreaming: true,
    );

    setState(() {
      _messages.add(streamingMessage);
    });

    // Stream by Unicode code points (runes) to avoid splitting surrogate pairs
    // This prevents temporary invalid UTF-16 halves (which crash rendering)
    final buffer = StringBuffer();
    final runes = fullResponse.runes.toList();
    for (int i = 0; i < runes.length; i++) {
      if (!mounted) return;
      buffer.write(String.fromCharCode(runes[i]));
      // Update the streaming message in small chunks to provide smooth typing effect
      if (i % 2 == 0 || i == runes.length - 1) {
        setState(() {
          streamingMessage.text = buffer.toString();
        });
      }
      await Future.delayed(const Duration(milliseconds: 6));
    }

    if (!mounted) return;
    setState(() {
      streamingMessage.isStreaming = false;
    });
  }

  bool _shouldSuggestWebSearch(String response, String query) {
    final lowerResponse = response.toLowerCase();

    if (lowerResponse.contains('don\'t have') ||
        lowerResponse.contains('cannot provide') ||
        lowerResponse.contains('do not have information') ||
        lowerResponse.contains('my knowledge was last updated') ||
        lowerResponse.contains('as of my last update') ||
        lowerResponse.contains('i don\'t have access')) {
      return true;
    }

    return _webSearchService.shouldSuggestWebSearch(query);
  }

  /// Intelligent web search detection: determines if a question needs recent information
  /// This analyzes the user's query to decide if web search is necessary
  /// Returns true only if the question implies a need for current/recent data
  bool _questionNeedsWebSearch(String userQuery) {
    final lower = userQuery.toLowerCase().trim();

    // Keywords that indicate need for current information
    final recentInfoKeywords = [
      // Time-based
      'today', 'tomorrow', 'tonight', 'now', 'currently', 'latest',
      'recent', 'this week', 'this month', 'this year',
      'yesterday', 'last week', 'last month',
      // News/Events
      'news', 'breaking', 'trending', 'viral', 'happening',
      'announced', 'released', 'launched',
      // Prices/Stocks
      'price', 'cost', 'stock', 'bitcoin', 'crypto', 'exchange rate',
      'usd', 'eur', 'gbp', 'market', 'investment',
      // Weather/Location-based
      'weather', 'temperature', 'forecast', 'climate',
      'location', 'nearby', 'where',
      // Live events
      'live', 'happening now', 'schedule', 'match', 'game',
      // Updates
      'update', 'version', 'release', 'new', 'new features',
      'improvement', 'patch',
      // Sports
      'score', 'result', 'standings', 'league', 'match', 'tournament',
      // People/Fame
      'dead', 'died', 'still alive', 'recent interview',
      // Specific dates
      '2024', '2025', '2026',
    ];

    // Check if query contains any recent info keywords
    for (final keyword in recentInfoKeywords) {
      if (lower.contains(keyword)) {
        return true;
      }
    }

    // Keywords that indicate knowledge-based questions (no web search needed)
    final knowledgeKeywords = [
      'how to',
      'explain',
      'what is',
      'define',
      'meaning',
      'history of',
      'who was',
      'what was',
      'why do',
      'concept',
      'theory',
      'mathematics',
      'physics',
      'biology',
      'chemistry',
      'algorithm',
      'process',
      'method',
      'technique',
      'tips',
      'advice',
      'write code',
      'how do i code',
      'programming',
      'solve',
      'calculate',
      'derive',
      'proof',
      'difference between',
      'compare',
      'vs',
    ];

    // If it's a knowledge-based question, don't search the web
    for (final keyword in knowledgeKeywords) {
      if (lower.contains(keyword)) {
        return false;
      }
    }

    // Default: if unclear, don't search (preserve user preference to avoid unnecessary API calls)
    return false;
  }

  /// Converts the current message history to the format expected by the search service.
  /// This provides conversation context for more relevant web searches.
  List<Map<String, String>> _getConversationHistoryForSearch() {
    // Take last 10 messages (excluding typing indicators)
    final relevantMessages = _messages
        .where((m) => !m.isTyping && m.text.isNotEmpty)
        .toList();

    // Take last 10 for context
    final recentMessages = relevantMessages.length > 10
        ? relevantMessages.sublist(relevantMessages.length - 10)
        : relevantMessages;

    return recentMessages.map((m) {
      return {'role': m.fromUser ? 'user' : 'assistant', 'content': m.text};
    }).toList();
  }

  void _showPremiumRequiredDialog() {
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
              Icon(Icons.star, color: AppTheme.primaryBlue),
              SizedBox(width: AppTheme.spaceSm),
              Text(
                AppLocalizations.of(context).t('premium.featureUnavailable'),
                style: AppTheme.headlineSmall.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            AppLocalizations.of(context).t('premium.upgradeToPremium'),
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context).t('common.cancel'),
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: Navigate to premium screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              child: Text(AppLocalizations.of(context).t('premium.upgrade')),
            ),
          ],
        );
      },
    );
  }

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
    try {
      // ALWAYS include conversation history for context-aware responses
      final List<Map<String, String>> convo = [];
      for (final m in _messages) {
        final role = m.fromUser ? 'user' : 'assistant';
        final content = m.text;

        if (content.isNotEmpty) {
          if (!role.contains('assistant') || !_isDefaultIntroMessage(content)) {
            convo.add({'role': role, 'content': content});
          }
        }
      }

      // Check if question needs web search
      final questionNeedsSearch = _questionNeedsWebSearch(prompt);

      // Track if we auto-enabled for this request
      _wasWebSearchAutoEnabledThisRequest = false;

      // SMART AUTO-ENABLE: If question needs web search but it's OFF, turn it ON automatically
      if (questionNeedsSearch && !_webSearchEnabled) {
        print(
          '[SMART WEB SEARCH] Question needs recent info - auto-enabling web search',
        );
        _showSnackBar(
          'Smart mode: Auto-enabling web search for this question.',
          isError: false,
        );
        setState(() {
          _webSearchEnabled = true;
          _wasWebSearchAutoEnabledThisRequest = true;
        });
      }

      // Determine if web search should be used
      final shouldUseWebSearch = _webSearchEnabled && questionNeedsSearch;

      final input = {
        'messages': convo, // Always include conversation history
        'message': prompt,
        'mode': _responseMode,
        'model': _getBackendModelName(_selectedModel),
        'systemPrompt': AiConstants.systemPrompt,
        'webSearchEnabled': shouldUseWebSearch,
        'conversationHistory': _getConversationHistoryForSearch(),
        if (instructions != null) 'instructions': instructions,
      };

      final fullResp = await ApiService.sendRaw('chat', input);

      // If we auto-enabled for this request, disable it back after response is received
      if (_wasWebSearchAutoEnabledThisRequest && _webSearchEnabled) {
        print(
          '[SMART WEB SEARCH] Request sent - disabling web search toggle back off',
        );
        setState(() {
          _webSearchEnabled = false;
          _wasWebSearchAutoEnabledThisRequest = false;
        });
      }

      if (fullResp['webSearchAutoTriggered'] == true && !shouldUseWebSearch) {
        _showSnackBar(
          'Backend detected need for recent information - searching web.',
          isError: false,
        );
        setState(() {
          _webSearchEnabled = true;
        });

        try {
          final searchResults = await _webSearchService.search(
            query: prompt,
            conversationHistory: _getConversationHistoryForSearch(),
          );
          final enhancedPrompt = _webSearchService.createEnhancedPrompt(
            prompt,
            searchResults,
          );

          return await _callWithSearchResults(
            enhancedPrompt,
            instructions: instructions,
          );
        } catch (e) {
          _showSnackBar('Auto web search failed: $e', isError: true);
          setState(() {
            _webSearchEnabled = false;
            _wasWebSearchAutoEnabledThisRequest = false;
          });
        }
      }

      final reply = fullResp['reply'] ?? fullResp['response'] ?? '';

      // If reply is empty or shows error, try to extract from fullResponse
      String finalReply = reply.toString();
      if (finalReply.isEmpty ||
          finalReply.contains('Oops') ||
          finalReply.contains('went wrong')) {
        // Try to extract from fullResponse structure (when backend returns structured response)
        if (fullResp['fullResponse'] != null) {
          final fullResponse = fullResp['fullResponse'];
          if (fullResponse is Map && fullResponse['choices'] is List) {
            final choices = fullResponse['choices'] as List;
            if (choices.isNotEmpty) {
              final firstChoice = choices[0];
              if (firstChoice is Map && firstChoice['message'] is Map) {
                final message = firstChoice['message'] as Map;
                final content = message['content'];
                if (content != null && content.toString().isNotEmpty) {
                  finalReply = content.toString();
                  print(
                    '🔍 [EXTRACTED FROM fullResponse] Using content from fullResponse',
                  );
                }
              }
            }
          }
        }
      }

      print(
        '🔍 [RAW AI RESPONSE] length=${finalReply.toString().length} hasNewlines=${finalReply.toString().contains('\n')}',
      );
      final replyStr = finalReply.toString();
      final previewStr = replyStr.runes.length > 400
          ? String.fromCharCodes(replyStr.runes.take(400)) + '...'
          : replyStr;
      print('🔍 [RAW AI RESPONSE PREVIEW] $previewStr');
      return finalReply.isEmpty ? null : finalReply.toString();
    } catch (e) {
      return '⚠️ All AI services are currently unavailable. ($e)';
    }
  }

  Future<String?> _callWithSearchResults(
    String enhancedPrompt, {
    Map<String, dynamic>? instructions,
  }) async {
    try {
      // Build conversation history including all previous messages for context
      final List<Map<String, String>> searchMessages = [];

      // Add all previous messages to maintain context
      for (final m in _messages) {
        final role = m.fromUser ? 'user' : 'assistant';
        final content = m.text;

        if (content.isNotEmpty) {
          if (!role.contains('assistant') || !_isDefaultIntroMessage(content)) {
            searchMessages.add({'role': role, 'content': content});
          }
        }
      }

      // Send to backend - backend will handle Exa API integration and model processing
      final input = {
        'messages': searchMessages,
        'message': enhancedPrompt,
        'mode': _responseMode,
        'model': _getBackendModelName(_selectedModel),
        'systemPrompt': AiConstants.systemPrompt,
        'webSearchEnabled': true,
        'conversationHistory': _getConversationHistoryForSearch(),
        if (instructions != null) 'instructions': instructions,
      };

      final fullResp = await ApiService.sendRaw('chat', input);

      // Extract enhanced answer from Exa web search results processed by AI
      final enhancedAnswer = fullResp['enhancedAnswer'];
      if (enhancedAnswer != null && enhancedAnswer.toString().isNotEmpty) {
        return enhancedAnswer.toString();
      }

      // Fallback to regular reply if enhanced answer not available
      final reply = fullResp['reply'] ?? fullResp['response'] ?? '';
      return reply.isEmpty ? null : reply.toString();
    } catch (e) {
      return '⚠️ Web search processing failed. ($e)';
    }
  }

  bool _isDefaultIntroMessage(String text) {
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    return (lower.contains('assistant introduction') ||
        lower.contains('ai assistant') && lower.contains('here to help') ||
        lower.contains('no fixed name') ||
        lower.contains('ai helper'));
  }

  Future<void> _loadChat(String chatId, String title) async {
    try {
      setState(() {
        _messages.clear();
        _currentChatId = chatId;
        _showGreeting = false;
      });

      final messagesStream = _chatStorage.getMessages(chatId);
      final messages = await messagesStream.first;

      setState(() {
        for (final msg in messages) {
          if (msg['fromUser'] == true) {
            _messages.add(_Message(text: msg['text'], fromUser: true));
          } else {
            // Log and add AI messages for audit
            _logAndAddAiMessage(msg['text']);
          }
        }
      });

      _showSnackBar('Loaded: $title', isError: false);
    } catch (e) {
      _showSnackBar('Error loading chat: $e', isError: true);
    }
  }

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
                Padding(
                  padding: EdgeInsets.only(top: 12, bottom: 20),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textTertiary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

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
                _buildOptionTile(
                  icon: isStarred ? Icons.star : Icons.star_border,
                  title: isStarred
                      ? AppLocalizations.of(context).t('chatScreen.unstarChat')
                      : AppLocalizations.of(context).t('chatScreen.starChat'),
                  color: AppTheme.primaryBlue,
                  onTap: () {
                    Navigator.pop(context);
                    _toggleStar(chatId, !isStarred);
                  },
                ),
                _buildOptionTile(
                  icon: Icons.edit,
                  title: AppLocalizations.of(
                    context,
                  ).t('chatScreen.renameChat'),
                  color: AppTheme.primaryBlue,
                  onTap: () {
                    Navigator.pop(context);
                    _showRenameDialog(chatId, title);
                  },
                ),
                _buildOptionTile(
                  icon: Icons.delete,
                  title: AppLocalizations.of(
                    context,
                  ).t('chatScreen.deleteChat'),
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
                  title: AppLocalizations.of(context).t('chatScreen.shareChat'),
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

  Future<void> _toggleStar(String chatId, bool newStarred) async {
    try {
      await _chatStorage.toggleStar(chatId, newStarred);
      _showSnackBar(newStarred ? '⭐ Chat starred' : 'Chat unstarred');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

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
            AppLocalizations.of(context).t('drawer.renameDialogTitle'),
            style: AppTheme.headlineSmall.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(
                context,
              ).t('drawer.renameDialogHint'),
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
                AppLocalizations.of(context).t('drawer.cancelButton'),
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
                    _showSnackBar(
                      AppLocalizations.of(context).t('drawer.chatRenamed'),
                    );
                  } catch (e) {
                    _showSnackBar(
                      AppLocalizations.of(context)
                          .t('drawer.renameError')
                          .replaceAll('{error}', e.toString()),
                      isError: true,
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: Text(
                AppLocalizations.of(context).t('drawer.renameButton'),
              ),
            ),
          ],
        );
      },
    );
  }

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
                AppLocalizations.of(context).t('drawer.deleteDialogTitle'),
                style: AppTheme.headlineSmall.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            AppLocalizations.of(
              context,
            ).t('drawer.deleteDialogMessage').replaceAll('{title}', title),
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                AppLocalizations.of(context).t('drawer.cancelButton'),
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(
                AppLocalizations.of(context).t('drawer.deleteButton'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showDeleteConfirmationWithOption() async {
    bool _doNotShowAgain = false;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      ).t('drawer.deleteConfirmTitle'),
                      style: AppTheme.headlineSmall.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(
                      context,
                    ).t('drawer.deleteConfirmMessage'),
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: AppTheme.spaceMd),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _doNotShowAgain,
                    onChanged: (value) {
                      setState(() {
                        _doNotShowAgain = value ?? false;
                      });
                    },
                    title: Text(
                      AppLocalizations.of(context).t('drawer.doNotShowAgain'),
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    activeColor: AppTheme.primaryBlue,
                    checkColor: Colors.white,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    AppLocalizations.of(context).t('drawer.cancelButton'),
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_doNotShowAgain) {
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('skip_delete_confirmation', true);
                        if (mounted) {
                          setState(() {
                            _skipDeleteConfirmation = true;
                          });
                        }
                      } catch (e) {
                        print('Error saving preference: $e');
                      }
                    }
                    if (mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    AppLocalizations.of(context).t('drawer.okButton'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteChat(String chatId, String title) async {
    // Show confirmation dialog unless user selected "Do not show again"
    if (!_skipDeleteConfirmation) {
      final confirmed = await _showDeleteConfirmationWithOption();
      if (confirmed != true) {
        return; // User cancelled
      }
    }

    try {
      await _chatStorage.deleteChat(chatId);
      // Silent delete - no notification shown
      if (_currentChatId == chatId) {
        setState(() {
          _currentChatId = null;
          _messages.clear();
          _showGreeting = true;
          _greetingAnimationController.forward();
        });
      }
    } catch (e) {
      // Only show error if something goes wrong
      _showSnackBar('Error deleting: $e', isError: true);
    }
  }

  Future<void> _shareChatLink(String chatId, String title) async {
    try {
      final shareText =
          '''Check out this chat on MyAI: "$title"\nOpen the app and search for chat ID: $chatId\n🤖 MyAI - Your AI Conversation Hub'''
              .trim();

      await Clipboard.setData(ClipboardData(text: shareText));

      if (mounted) {
        _showSnackBar(
          Row(
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
                        fontWeight: FontWeight.w600,
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
          duration: Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error sharing chat: $e', isError: true);
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
            color: Theme.of(ctx).brightness == Brightness.dark
                ? AppTheme.surfaceElevated.withOpacity(0.95)
                : Color(0xFFFFFFFF),
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
                Padding(
                  padding: EdgeInsets.only(top: 12, bottom: 20),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? AppTheme.textTertiary
                          : Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        AppLocalizations.of(ctx).t('menu.chatOptions'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(ctx).brightness == Brightness.dark
                              ? AppTheme.textPrimary
                              : Color(0xFF000000),
                          letterSpacing: 0.3,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(ctx).brightness == Brightness.dark
                              ? AppTheme.textTertiary
                              : Color(0xFF6B7280),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                Divider(
                  color: Theme.of(ctx).brightness == Brightness.dark
                      ? AppTheme.surfaceElevated.withOpacity(0.5)
                      : Color(0xFFE5E7EB),
                  height: 20,
                  thickness: 0.5,
                ),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Column(
                            children: [
                              _buildMenuItemAdvanced(
                                ctx,
                                icon: Icons.edit_outlined,
                                title: AppLocalizations.of(
                                  ctx,
                                ).t('menu.rename'),
                                subtitle: AppLocalizations.of(
                                  ctx,
                                ).t('menu.changeChatTitle'),
                                gradient: AppTheme.primaryGradient,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  if (_currentChatId != null) {
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
                                    _showSnackBar(
                                      'Start a conversation first to rename',
                                      isError: false,
                                    );
                                  }
                                },
                              ),
                              SizedBox(height: 8),

                              _buildMenuItemAdvanced(
                                ctx,
                                icon: Icons.star_outline,
                                title: AppLocalizations.of(ctx).t('menu.star'),
                                subtitle: AppLocalizations.of(
                                  ctx,
                                ).t('menu.markAsImportant'),
                                gradient: [Colors.amber, Colors.orange],
                                onTap: () {
                                  Navigator.pop(ctx);
                                  if (_currentChatId != null) {
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
                                    _showSnackBar(
                                      'Start a conversation first to star',
                                      isError: false,
                                    );
                                  }
                                },
                              ),
                              SizedBox(height: 8),

                              _buildMenuItemAdvanced(
                                ctx,
                                icon: Icons.add_circle_outline,
                                title: AppLocalizations.of(
                                  ctx,
                                ).t('menu.newChat'),
                                subtitle: AppLocalizations.of(
                                  ctx,
                                ).t('menu.startFreshConversation'),
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
                              SizedBox(height: 8),

                              _buildMenuItemAdvanced(
                                ctx,
                                icon: Icons.smart_toy_outlined,
                                title: AppLocalizations.of(
                                  ctx,
                                ).t('menu.recentBots'),
                                subtitle: AppLocalizations.of(
                                  ctx,
                                ).t('menu.viewStudyBotHistory'),
                                gradient: [
                                  Color(0xFF8B5CF6),
                                  Color(0xFFA855F7),
                                ],
                                onTap: () {
                                  Navigator.pop(ctx);
                                  Navigator.pushNamed(
                                    context,
                                    '/recent-study-bots',
                                  );
                                },
                              ),
                              SizedBox(height: 8),

                              _buildMenuItemAdvanced(
                                ctx,
                                icon: Icons.settings_outlined,
                                title: AppLocalizations.of(
                                  ctx,
                                ).t('menu.settings'),
                                subtitle: AppLocalizations.of(
                                  ctx,
                                ).t('menu.appPreferences'),
                                gradient: [
                                  Color(0xFF6B7280),
                                  Color(0xFF4B5563),
                                ],
                                onTap: () {
                                  Navigator.pop(ctx);
                                  Navigator.pushNamed(context, '/settings');
                                },
                              ),
                            ],
                          ),
                        ),

                        // Account section
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: _buildAccountSection(ctx),
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
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.surfaceElevated.withOpacity(0.3)
                : Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.primaryBlue.withOpacity(0.1)
                  : Color(0xFFE5E7EB),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
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
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.textPrimary
                            : Color(0xFF000000),
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.textSecondary
                            : Color(0xFF6B7280),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.textTertiary
                    : Color(0xFFD1D5DB),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSection(BuildContext ctx) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;

    if (isLoggedIn) {
      return FutureBuilder<String>(
        future: UserProfileService.instance.getDisplayName(),
        builder: (context, snapshot) {
          final displayName = snapshot.data ?? 'User';
          final email = user.email ?? '';

          return Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? LinearGradient(
                      colors: [
                        AppTheme.primaryBlue.withOpacity(0.1),
                        AppTheme.primaryBlue.withOpacity(0.05),
                      ],
                    )
                  : LinearGradient(
                      colors: [Color(0xFFEFF6FF), Color(0xFFF0F9FF)],
                    ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.primaryBlue.withOpacity(0.2)
                    : Color(0xFFBFDBFE),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppTheme.primaryGradient,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppTheme.textPrimary
                                  : Color(0xFF000000),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppTheme.textSecondary
                                    : Color(0xFF6B7280),
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _handleLogout();
                    },
                    icon: Icon(Icons.logout, size: 18),
                    label: Text(AppLocalizations.of(ctx).t('menu.signOut')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.8),
                      foregroundColor: Colors.white,
                      side: BorderSide.none,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            width: 0.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 48,
              color: AppTheme.textTertiary,
            ),
            SizedBox(height: 8),
            Text(
              AppLocalizations.of(ctx).t('menu.signInToSaveChats'),
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(context, '/login');
                        },
                        child: Text(
                          AppLocalizations.of(ctx).t('menu.logIn'),
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryBlue,
                          side: BorderSide(
                            color: AppTheme.primaryBlue.withOpacity(0.5),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Flexible(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(context, '/signup');
                        },
                        child: Text(
                          AppLocalizations.of(ctx).t('menu.signUp'),
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
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

  Future<void> _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      await UserProfileService.instance.clearUserData();

      if (mounted) {
        setState(() {
          _messages.clear();
          _currentChatId = null;
          _showGreeting = true;
          _isSavingEnabled = false;
        });
        _greetingAnimationController.forward();

        _showSnackBar('Signed out successfully', isError: false);
      }
    } catch (e) {
      _showSnackBar('Error signing out: $e', isError: true);
    }
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
              AppTheme.backgroundGradientStartFromContext(context),
              AppTheme.backgroundGradientEndFromContext(context),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: AppTheme.primaryGradient,
                              ).createShader(bounds),
                              child: Text(
                                AppLocalizations.of(context).t('drawer.chats'),
                                style: AppTheme.displayMedium.copyWith(
                                  fontWeight: FontWeight.w700,
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
                                  _currentChatId = null;
                                  _showGreeting = true;
                                  _greetingAnimationController.forward();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppTheme.spaceMd),
                      // ✨ STREAK INDICATOR - Premium UI reusing existing StudyActivityService
                      StreakIndicator(
                        onTap: () {
                          Navigator.pop(context);
                          StreakDetailsModal.show(context);
                        },
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppTheme.surfaceGradient,
                      ),
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
                        hintText: AppLocalizations.of(
                          context,
                        ).t('drawer.searchChats'),
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

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
                  child: InkWell(
                    key: OnboardingConfig.studyPlanKey,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BotCreationScreen(),
                        ),
                      );
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
                            AppLocalizations.of(
                              context,
                            ).t('drawer.createStudyPlan'),
                            style: AppTheme.labelLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
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

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
                  child: Text(
                    AppLocalizations.of(context).t('drawer.recentChats'),
                    style: AppTheme.labelMedium.copyWith(
                      color: AppTheme.textTertiary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                SizedBox(height: AppTheme.spaceSm),

                if (!_isSavingEnabled)
                  Center(
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
                          AppLocalizations.of(
                            context,
                          ).t('drawer.signInToSaveChats'),
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
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            AppLocalizations.of(
                              context,
                            ).t('drawer.signInButton'),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _chatStorage.getChats(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
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
                                AppLocalizations.of(
                                  context,
                                ).t('drawer.errorLoadingChats'),
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final allChats = snapshot.data ?? [];

                      if (_searchQuery.isEmpty) {
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
                                  AppLocalizations.of(
                                    context,
                                  ).t('drawer.noChats'),
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: AppTheme.spaceSm,
                                  ),
                                  child: Text(
                                    AppLocalizations.of(
                                      context,
                                    ).t('drawer.startChatting'),
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
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: displayChats.length,
                          itemBuilder: (context, index) {
                            final chat = displayChats[index];
                            final isStarred = chat['isStarred'] ?? false;
                            final chatId = chat['id'];
                            final chatTitle = chat['title'];
                            final timeStr = _formatTimestamp(chat['timestamp']);

                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppTheme.spaceSm,
                                vertical: 2,
                              ),
                              child: Dismissible(
                                key: Key(chatId),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (direction) async {
                                  // If user has checked "Do not show again", delete without confirmation
                                  if (_skipDeleteConfirmation) {
                                    return true;
                                  }
                                  // Otherwise show the confirmation dialog with checkbox
                                  final confirmed =
                                      await _showDeleteConfirmationWithOption();
                                  return confirmed ?? false;
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
                                        AppTheme.primaryBlue.withOpacity(0.1),
                                        AppTheme.primaryBlue.withOpacity(0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSm,
                                    ),
                                  ),
                                  alignment: Alignment.centerRight,
                                  child: Icon(
                                    Icons.delete_outline,
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
                                          : Border.all(
                                              color: AppTheme.surfaceElevated
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
                                              color: AppTheme.primaryBlue,
                                              size: 18,
                                            ),
                                          ),
                                        Expanded(
                                          child: Builder(
                                            builder: (context) {
                                              final isDarkMode =
                                                  Theme.of(
                                                    context,
                                                  ).brightness ==
                                                  Brightness.dark;
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    chatTitle,
                                                    style: AppTheme.bodyLarge
                                                        .copyWith(
                                                          color: isDarkMode
                                                              ? AppTheme
                                                                    .textPrimary
                                                              : Color(
                                                                  0xFF000000,
                                                                ),
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    '${chat['messageCount']} ${AppLocalizations.of(context).t('drawer.messages')}',
                                                    style: AppTheme.bodySmall
                                                        .copyWith(
                                                          color: isDarkMode
                                                              ? AppTheme
                                                                    .textTertiary
                                                              : Color(
                                                                  0xFF6B7280,
                                                                ),
                                                        ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                        Builder(
                                          builder: (context) {
                                            final isDarkMode =
                                                Theme.of(context).brightness ==
                                                Brightness.dark;
                                            return Text(
                                              timeStr,
                                              style: AppTheme.bodySmall
                                                  .copyWith(
                                                    color: isDarkMode
                                                        ? AppTheme.textTertiary
                                                        : Color(0xFF9CA3AF),
                                                  ),
                                            );
                                          },
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
                                  AppLocalizations.of(
                                    context,
                                  ).t('drawer.noChatFound'),
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: filteredChats.length,
                          itemBuilder: (context, index) {
                            final chat = filteredChats[index];
                            final timestamp = chat['updatedAt'];
                            final timeStr = timestamp != null
                                ? _formatTimestamp(timestamp)
                                : AppLocalizations.of(
                                    context,
                                  ).t('drawer.justNow');
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
                                  // If user has checked "Do not show again", delete without confirmation
                                  if (_skipDeleteConfirmation) {
                                    return true;
                                  }
                                  // Otherwise show the confirmation dialog with checkbox
                                  final confirmed =
                                      await _showDeleteConfirmationWithOption();
                                  return confirmed ?? false;
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
                                        AppTheme.primaryBlue.withOpacity(0.1),
                                        AppTheme.primaryBlue.withOpacity(0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSm,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.delete_outline,
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
                                              colors: AppTheme.primaryGradient,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusSm,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.chat_bubble_outline,
                                            color: Colors.white,
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
                                                      padding: EdgeInsets.only(
                                                        right: 4,
                                                      ),
                                                      child: Icon(
                                                        Icons.star,
                                                        color: AppTheme
                                                            .primaryBlue,
                                                        size: 14,
                                                      ),
                                                    ),
                                                  Expanded(
                                                    child: Builder(
                                                      builder: (context) {
                                                        final isDarkMode =
                                                            Theme.of(
                                                              context,
                                                            ).brightness ==
                                                            Brightness.dark;
                                                        return Text(
                                                          chatTitle,
                                                          style: AppTheme
                                                              .bodyLarge
                                                              .copyWith(
                                                                color:
                                                                    isDarkMode
                                                                    ? AppTheme
                                                                          .textPrimary
                                                                    : Color(
                                                                        0xFF000000,
                                                                      ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Builder(
                                                builder: (context) {
                                                  final isDarkMode =
                                                      Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark;
                                                  return Text(
                                                    '${chat['messageCount']} ${AppLocalizations.of(context).t('drawer.messages')}',
                                                    style: AppTheme.bodySmall
                                                        .copyWith(
                                                          color: isDarkMode
                                                              ? AppTheme
                                                                    .textTertiary
                                                              : Color(
                                                                  0xFF6B7280,
                                                                ),
                                                        ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        Builder(
                                          builder: (context) {
                                            final isDarkMode =
                                                Theme.of(context).brightness ==
                                                Brightness.dark;
                                            return Text(
                                              timeStr,
                                              style: AppTheme.bodySmall
                                                  .copyWith(
                                                    color: isDarkMode
                                                        ? AppTheme.textTertiary
                                                        : Color(0xFF9CA3AF),
                                                  ),
                                            );
                                          },
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
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.textSecondary
                                : Color(0xFF000000),
                            size: 20,
                          ),
                          SizedBox(width: AppTheme.spaceSm),
                          Text(
                            'Settings',
                            style: AppTheme.bodyMedium.copyWith(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppTheme.textSecondary
                                  : Color(0xFF000000),
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
      ),
    );
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    // Show/hide system UI for true full-screen experience
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.backgroundGradientStartFromContext(context),
                AppTheme.backgroundGradientEndFromContext(context),
              ],
            ),
            // Add any additional widgets or logic here
          ),
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            drawerEnableOpenDragGesture: true,
            drawer: _buildDrawer(),
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(60),
              child: Container(
                decoration: BoxDecoration(
                  gradient: Theme.of(context).brightness == Brightness.dark
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.backgroundDeep.withOpacity(0.95),
                            AppTheme.backgroundDeep.withOpacity(0.9),
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.primaryBlue.withOpacity(0.40),
                            AppTheme.primaryBlue.withOpacity(0.35),
                          ],
                        ),
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.surfaceElevated.withOpacity(0.1)
                          : Color(0xFFE5E7EB),
                      width: 0.5,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: Container(
                    margin: EdgeInsets.only(left: 16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.surfaceCard.withOpacity(0.8)
                          : Color(0xFFFFFFFF),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.surfaceElevated.withOpacity(0.2)
                            : Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      key: OnboardingConfig.hamburgerMenuKey,
                      icon: Icon(
                        Icons.menu,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.textPrimary
                            : Color(0xFF1F2937),
                        size: 20,
                      ),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      padding: EdgeInsets.all(8),
                      constraints: BoxConstraints(),
                    ),
                  ),
                  title: InkWell(
                    onTap: _showModelSelector,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.surfaceCard.withOpacity(0.6)
                            : Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.surfaceElevated.withOpacity(0.3)
                              : Color(0xFFE5E7EB),
                          width: 1,
                        ),
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
                              style: AppTheme.headlineSmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.textSecondary
                                : Color(0xFF6B7280),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  centerTitle: true,
                  actions: [
                    Container(
                      margin: EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.surfaceCard.withOpacity(0.8)
                            : Color(0xFFFFFFFF),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.surfaceElevated.withOpacity(0.2)
                              : Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _responseMode == 'detailed'
                              ? Icons.menu_book
                              : Icons.flash_on,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.textPrimary
                              : Color(0xFF1F2937),
                          size: 20,
                        ),
                        tooltip: _responseMode == 'detailed'
                            ? 'Detailed mode'
                            : 'Normal mode',
                        onPressed: () => setState(
                          () => _responseMode = _responseMode == 'detailed'
                              ? 'normal'
                              : 'detailed',
                        ),
                        padding: EdgeInsets.all(8),
                        constraints: BoxConstraints(),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.surfaceCard.withOpacity(0.8)
                            : Color(0xFFFFFFFF),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.surfaceElevated.withOpacity(0.2)
                              : Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.more_vert,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.textPrimary
                              : Color(0xFF1F2937),
                          size: 20,
                        ),
                        onPressed: _openMenu,
                        padding: EdgeInsets.all(8),
                        constraints: BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            body: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity! < -300) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotesScreen()),
                  );
                } else if (details.primaryVelocity! > 300) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChatHistoryScreen(),
                    ),
                  );
                }
              },
              onTap: () {
                // Handle single tap if needed
              },
              onDoubleTap: () {
                _toggleFullScreen();
              },
              child: SafeArea(
                child: Column(
                  children: [
                    // Premium Upgrade Button (shown only when no messages)
                    if (_messages.isEmpty)
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMd,
                          vertical: 0,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppTheme.primaryGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              // TODO: Navigate to premium screen
                              _showPremiumRequiredDialog();
                            },
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                            child: Container(
                              padding: EdgeInsets.all(AppTheme.spaceMd),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.diamond,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: AppTheme.spaceSm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Upgrade',
                                          style: AppTheme.bodyLarge.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Unlock Premium Features',
                                          style: AppTheme.bodySmall.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Stack(
                        children: [
                          _showGreeting && _messages.isEmpty
                              ? _buildGreetingUI()
                              : ListView.builder(
                                  controller: _messageScrollController,
                                  padding: EdgeInsets.fromLTRB(
                                    20,
                                    20,
                                    20,
                                    20, // Consistent padding, input area handles its own spacing
                                  ),
                                  itemCount: _messages.length,
                                  itemBuilder: (context, i) {
                                    final m = _messages[i];

                                    if (m.isTyping) {
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            TypingIndicator(
                                              message:
                                                  _currentStatusMessage
                                                      .isNotEmpty
                                                  ? _currentStatusMessage
                                                  : 'Generating response...',
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    if (m.isStreaming) {
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                                messageIndex: i,
                                                onRegenerate: !m.fromUser
                                                    ? () =>
                                                          _regenerateResponse(i)
                                                    : null,
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsets.only(
                                                left: 8,
                                                top: 16,
                                              ),
                                              child: TypingIndicator(),
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    return Padding(
                                      padding: EdgeInsets.only(bottom: 12),
                                      child: AiMessageBubble(
                                        text: m.text,
                                        fromUser: m.fromUser,
                                        imagePath: m.imagePath,
                                        gradientColors: m.fromUser
                                            ? AppTheme.primaryGradient
                                            : Theme.of(context).brightness ==
                                                  Brightness.light
                                            ? [
                                                Colors.black,
                                                Colors.grey.shade800,
                                              ]
                                            : AppTheme.surfaceGradient,
                                        textColor:
                                            Theme.of(context).brightness ==
                                                Brightness.light
                                            ? Colors.white
                                            : AppTheme.textPrimary,
                                        detailedByDefault:
                                            _responseMode == 'detailed',
                                        messageIndex: i,
                                        onRegenerate: !m.fromUser
                                            ? () => _regenerateResponse(i)
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                          _buildScrollButton(),
                        ],
                      ),
                    ),

                    // Input area - hide in full screen mode
                    if (!_isFullScreen)
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.backgroundDeep
                              : Color(0xFFFAFAFA),
                          border: Border(
                            top: BorderSide(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppTheme.surfaceElevated.withOpacity(0.1)
                                  : Color(0xFFE5E7EB),
                              width: 0.5,
                            ),
                          ),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          16 + MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_selectedImage != null)
                              Container(
                                margin: EdgeInsets.only(bottom: 16),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppTheme.surfaceCard
                                      : Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppTheme.surfaceElevated.withOpacity(
                                            0.3,
                                          )
                                        : Color(0xFFE5E7EB),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        _selectedImage!,
                                        height: 60,
                                        width: 60,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _selectedFileName ??
                                                AppLocalizations.of(
                                                  context,
                                                ).t('chatScreen.imageSelected'),
                                            style: AppTheme.bodyMedium.copyWith(
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark
                                                  ? AppTheme.textPrimary
                                                  : Color(0xFF000000),
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            AppLocalizations.of(
                                              context,
                                            ).t('chatScreen.attachedToMessage'),
                                            style: AppTheme.bodySmall.copyWith(
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark
                                                  ? AppTheme.textTertiary
                                                  : Color(0xFF6B7280),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.close,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppTheme.textTertiary
                                            : Color(0xFF6B7280),
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _selectedImage = null;
                                          _selectedFileName = null;
                                        });
                                      },
                                      padding: EdgeInsets.all(4),
                                      constraints: BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),

                            // Main input container - ChatGPT style
                            Container(
                              constraints: BoxConstraints(
                                minHeight: 56,
                                maxHeight: 120,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceCardFromContext(context),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: AppTheme.surfaceElevatedFromContext(
                                    context,
                                  ).withOpacity(0.2),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Attachment button
                                  Container(
                                    margin: EdgeInsets.only(left: 8, bottom: 8),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.add,
                                        color:
                                            AppTheme.textSecondaryFromContext(
                                              context,
                                            ),
                                        size: 22,
                                      ),
                                      onPressed: _showInputOptionsBottomSheet,
                                      padding: EdgeInsets.all(8),
                                      constraints: BoxConstraints(
                                        minWidth: 40,
                                        minHeight: 40,
                                      ),
                                    ),
                                  ),

                                  // Text input
                                  Expanded(
                                    child: TextField(
                                      key: OnboardingConfig.chatInputKey,
                                      controller: _controller,
                                      textInputAction: TextInputAction.newline,
                                      maxLines: null,
                                      keyboardType: TextInputType.multiline,
                                      style: AppTheme.bodyLarge.copyWith(
                                        color: AppTheme.textPrimaryFromContext(
                                          context,
                                        ),
                                        fontSize: 16,
                                        height: 1.4,
                                      ),
                                      onChanged: (value) {
                                        setState(() {});
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Message $_selectedModel...',
                                        hintStyle: AppTheme.bodyMedium.copyWith(
                                          color:
                                              AppTheme.textTertiaryFromContext(
                                                context,
                                              ),
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

                                  // Voice button
                                  Container(
                                    margin: EdgeInsets.only(bottom: 8),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.mic_none,
                                        color:
                                            AppTheme.textSecondaryFromContext(
                                              context,
                                            ),
                                        size: 22,
                                      ),
                                      onPressed: _toggleListening,
                                      padding: EdgeInsets.all(8),
                                      constraints: BoxConstraints(
                                        minWidth: 40,
                                        minHeight: 40,
                                      ),
                                    ),
                                  ),

                                  // Send button
                                  Container(
                                    margin: EdgeInsets.only(
                                      right: 8,
                                      bottom: 8,
                                    ),
                                    child: _buildSendButton(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGreetingUI() {
    return FadeTransition(
      opacity: _greetingFadeAnimation,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          constraints: BoxConstraints(
            minHeight:
                MediaQuery.of(context).size.height -
                300, // Account for app bar and input area
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Personalized greeting
              FutureBuilder<String>(
                future: GreetingUtils.getPersonalizedGreetingAsync(
                  context: context,
                ),
                builder: (context, snapshot) {
                  final greeting =
                      snapshot.data ??
                      GreetingUtils.getGreeting(context: context);
                  return Text(
                    greeting,
                    textAlign: TextAlign.center,
                    style: AppTheme.displayMedium.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Color(0xFF000000),
                      fontWeight: FontWeight.w600,
                      fontSize: 28,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  );
                },
              ),
              SizedBox(height: 4),

              // Feature highlights
              Container(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.light
                      ? AppTheme.surfaceCardFromContext(
                          context,
                        ).withOpacity(0.6)
                      : AppTheme.surfaceCard.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.light
                        ? AppTheme.surfaceElevatedFromContext(
                            context,
                          ).withOpacity(0.3)
                        : AppTheme.surfaceElevated.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    _buildFeatureRow(
                      Icons.chat_bubble_outline,
                      AppLocalizations.of(
                        context,
                      ).t('chatScreen.naturalConversations'),
                      AppLocalizations.of(
                        context,
                      ).t('chatScreen.engageFluidDialogue'),
                    ),
                    SizedBox(height: 16),
                    _buildFeatureRow(
                      Icons.image_outlined,
                      AppLocalizations.of(
                        context,
                      ).t('chatScreen.visualUnderstanding'),
                      AppLocalizations.of(
                        context,
                      ).t('chatScreen.uploadImagesDiscuss'),
                    ),
                    SizedBox(height: 16),
                    _buildFeatureRow(
                      Icons.psychology_outlined,
                      AppLocalizations.of(
                        context,
                      ).t('chatScreen.multipleAIModels'),
                      AppLocalizations.of(
                        context,
                      ).t('chatScreen.chooseAIPersonalities'),
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

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textTertiary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSendButton() {
    final hasText = _controller.text.trim().isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: hasText ? 44 : 0,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasText
              ? AppTheme.primaryGradient
              : [Colors.transparent, Colors.transparent],
        ),
        boxShadow: hasText
            ? [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: AnimatedOpacity(
        opacity: hasText ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: IconButton(
          icon: Icon(Icons.arrow_upward, color: Colors.white, size: 20),
          onPressed: hasText ? _send : null,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(),
        ),
      ),
    );
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
        print('Failed to decode image, returning original');
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
      print('Image compression failed: $e, returning original');
      return imageBytes;
    }
  }

  void _showSnackBar(
    dynamic content, {
    bool isError = false,
    Duration duration = const Duration(seconds: 4),
    Color? backgroundColor,
    ShapeBorder? shape,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: content is String ? Text(content) : content,
        backgroundColor:
            backgroundColor ??
            (isError ? AppTheme.error : AppTheme.primaryBlue),
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: shape,
      ),
    );
  }
}

class EqualizerIcon extends StatelessWidget {
  final Color color;
  final double size;

  const EqualizerIcon({Key? key, this.color = Colors.white, this.size = 24})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final barWidth = size / 12;
    final spacing = size / 8;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: barWidth,
          height: size * 0.7,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(barWidth / 2),
          ),
        ),
        SizedBox(width: spacing),
        Container(
          width: barWidth,
          height: size * 0.65,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(barWidth / 2),
          ),
        ),
        SizedBox(width: spacing),
        Container(
          width: barWidth,
          height: size * 0.5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(barWidth / 2),
          ),
        ),
      ],
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
