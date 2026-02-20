import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme.dart';
import '../utils/language_provider.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  late TextEditingController _searchController;
  List<String> _filteredLanguages = [];
  final Map<String, String> _languageFlags = {
    'en': '🇬🇧',
    'es': '🇪🇸',
    'fr': '🇫🇷',
    'ar': '🇸🇦',
    'hi': '🇮🇳',
  };

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _initializeFilteredLanguages();
    _searchController.addListener(_updateFilteredLanguages);
  }

  void _initializeFilteredLanguages() {
    _filteredLanguages = LanguageProvider.languageNames.keys.toList();
  }

  void _updateFilteredLanguages() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _initializeFilteredLanguages();
      } else {
        _filteredLanguages = LanguageProvider.languageNames.entries
            .where((entry) {
              final langName = entry.value.toLowerCase();
              return langName.contains(query) || entry.key.contains(query);
            })
            .map((entry) => entry.key)
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLang = languageProvider.currentLanguageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              color: AppTheme.textPrimaryFromContext(context),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Select Language',
            style: AppTheme.headlineSmall.copyWith(
              color: AppTheme.textPrimaryFromContext(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMd,
                  vertical: AppTheme.spaceMd,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppTheme.surfaceGradientFromContext(context),
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(
                      color: AppTheme.surfaceElevatedFromContext(
                        context,
                      ).withValues(alpha: 0.5),
                      width: 1,
                    ),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search languages...',
                      hintStyle: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textTertiaryFromContext(context),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppTheme.textTertiaryFromContext(context),
                        size: 22,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: AppTheme.textTertiaryFromContext(
                                  context,
                                ),
                                size: 22,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _updateFilteredLanguages();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMd,
                        vertical: AppTheme.spaceMd,
                      ),
                    ),
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimaryFromContext(context),
                    ),
                    cursorColor: AppTheme.primaryBlue,
                  ),
                ),
              ),

              // Languages List
              Expanded(
                child: _filteredLanguages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.language_outlined,
                              size: 60,
                              color: AppTheme.textTertiaryFromContext(context),
                            ),
                            SizedBox(height: AppTheme.spaceMd),
                            Text(
                              'No languages found',
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.textTertiaryFromContext(
                                  context,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMd,
                          vertical: AppTheme.spaceSm,
                        ),
                        itemCount: _filteredLanguages.length,
                        itemBuilder: (context, index) {
                          final langCode = _filteredLanguages[index];
                          final langName =
                              LanguageProvider.languageNames[langCode] ??
                              langCode;
                          final isSelected = currentLang == langCode;
                          final flag = _languageFlags[langCode] ?? '🌐';

                          return Padding(
                            padding: EdgeInsets.only(bottom: AppTheme.spaceSm),
                            child: InkWell(
                              onTap: () {
                                languageProvider.setLanguage(langCode);
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Language changed to $langName',
                                                style: AppTheme.bodyMedium
                                                    .copyWith(
                                                      color: Colors.white,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: AppTheme.primaryBlue,
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: 2),
                                      ),
                                    )
                                    .closed
                                    .then((_) {
                                      Navigator.pop(context);
                                    });
                              },
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusLg,
                              ),
                              child: Container(
                                padding: EdgeInsets.all(AppTheme.spaceMd),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? LinearGradient(
                                          colors: AppTheme.primaryGradient,
                                        )
                                      : LinearGradient(
                                          colors:
                                              AppTheme.surfaceGradientFromContext(
                                                context,
                                              ),
                                        ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusLg,
                                  ),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primaryBlue
                                        : AppTheme.surfaceElevatedFromContext(
                                            context,
                                          ).withValues(alpha: 0.5),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.primaryBlue
                                                .withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            offset: Offset(0, 4),
                                          ),
                                        ]
                                      : AppTheme.cardShadow,
                                ),
                                child: Row(
                                  children: [
                                    // Flag Emoji
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppTheme.primaryBlue.withValues(
                                          alpha: isSelected ? 0.3 : 0.1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          flag,
                                          style: TextStyle(fontSize: 24),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: AppTheme.spaceMd),

                                    // Language Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            langName,
                                            style: AppTheme.bodyLarge.copyWith(
                                              color: isSelected
                                                  ? Colors.white
                                                  : AppTheme.textPrimaryFromContext(
                                                      context,
                                                    ),
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Language code: $langCode',
                                            style: AppTheme.bodySmall.copyWith(
                                              color: isSelected
                                                  ? Colors.white.withValues(
                                                      alpha: 0.8,
                                                    )
                                                  : AppTheme.textTertiaryFromContext(
                                                      context,
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Selection Indicator
                                    if (isSelected)
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      )
                                    else
                                      Icon(
                                        Icons.chevron_right,
                                        color: AppTheme.textTertiaryFromContext(
                                          context,
                                        ),
                                        size: 24,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
