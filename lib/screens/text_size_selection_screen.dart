import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme.dart';
import '../utils/theme_provider.dart';
import '../utils/app_localizations.dart';

class TextSizeSelectionScreen extends StatefulWidget {
  const TextSizeSelectionScreen({super.key});

  @override
  State<TextSizeSelectionScreen> createState() =>
      _TextSizeSelectionScreenState();
}

class _TextSizeSelectionScreenState extends State<TextSizeSelectionScreen> {
  double _textScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadTextScale();
  }

  Future<void> _loadTextScale() async {
    final prefs = await SharedPreferences.getInstance();
    final scale = prefs.getDouble('text_size') ?? 1.0;
    setState(() => _textScale = scale);
  }

  Future<void> _saveTextScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('text_size', scale);

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    await themeProvider.setTextScaleFactor(scale);

    setState(() => _textScale = scale);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.text_fields, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${AppLocalizations.of(context).t('settings.textSizeUpdated')} ${(scale * 100).toInt()}%',
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryBlue,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
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
              Icons.arrow_back_ios_new,
              color: AppTheme.textPrimaryFromContext(context),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: AppTheme.primaryGradient,
            ).createShader(bounds),
            child: Text(
              AppLocalizations.of(context).t('settings.textSize'),
              style: AppTheme.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main info card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCardFromContext(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.textTertiaryFromContext(
                        context,
                      ).withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  padding: EdgeInsets.all(AppTheme.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with icon and title
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: AppTheme.primaryGradient,
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
                            child: Icon(
                              Icons.text_fields,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          SizedBox(width: AppTheme.spaceLg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  ).t('settings.adjustTextSize'),
                                  style: AppTheme.headlineSmall.copyWith(
                                    color: AppTheme.textPrimaryFromContext(
                                      context,
                                    ),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  ).t('settings.textSizeDescription'),
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textTertiaryFromContext(
                                      context,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppTheme.spaceLg),
                      // Current size display
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevatedFromContext(context),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                          border: Border.all(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMd,
                          vertical: AppTheme.spaceMd,
                        ),
                        child: Column(
                          children: [
                            Text(
                              AppLocalizations.of(
                                context,
                              ).t('settings.currentSize'),
                              style: AppTheme.labelMedium.copyWith(
                                color: AppTheme.textTertiaryFromContext(
                                  context,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '${(_textScale * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 48 * _textScale,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryFromContext(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Slider card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCardFromContext(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.textTertiaryFromContext(
                        context,
                      ).withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  padding: EdgeInsets.all(AppTheme.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(
                          context,
                        ).t('settings.selectYourSize'),
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textPrimaryFromContext(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: AppTheme.spaceLg),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 8,
                          activeTrackColor: AppTheme.primaryBlue,
                          inactiveTrackColor: AppTheme.textTertiaryFromContext(
                            context,
                          ).withValues(alpha: 0.2),
                          thumbColor: AppTheme.primaryBlue,
                          thumbShape: RoundSliderThumbShape(
                            enabledThumbRadius: 14,
                            elevation: 4,
                          ),
                          trackShape: RoundedRectSliderTrackShape(),
                          overlayColor: AppTheme.primaryBlue.withValues(
                            alpha: 0.3,
                          ),
                          overlayShape: RoundSliderOverlayShape(
                            overlayRadius: 20,
                          ),
                        ),
                        child: Slider(
                          value: _textScale,
                          min: 0.75,
                          max: 2.0,
                          divisions: 15,
                          label: '${(_textScale * 100).toInt()}%',
                          onChanged: (value) {
                            setState(() => _textScale = value);
                          },
                          onChangeEnd: _saveTextScale,
                        ),
                      ),
                      SizedBox(height: AppTheme.spaceLg),
                      // Size labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSizeLabel(
                            AppLocalizations.of(
                              context,
                            ).t('settings.sizeSmall'),
                            '75%',
                            context,
                          ),
                          _buildSizeLabel(
                            AppLocalizations.of(
                              context,
                            ).t('settings.sizeNormal'),
                            '100%',
                            context,
                          ),
                          _buildSizeLabel(
                            AppLocalizations.of(
                              context,
                            ).t('settings.sizeLarge'),
                            '150%',
                            context,
                          ),
                          _buildSizeLabel(
                            AppLocalizations.of(
                              context,
                            ).t('settings.sizeXLarge'),
                            '200%',
                            context,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Preview card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCardFromContext(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.textTertiaryFromContext(
                        context,
                      ).withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  padding: EdgeInsets.all(AppTheme.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).t('settings.livePreview'),
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textPrimaryFromContext(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: AppTheme.spaceMd),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevatedFromContext(context),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                          border: Border.all(
                            color: AppTheme.textTertiaryFromContext(
                              context,
                            ).withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        padding: EdgeInsets.all(AppTheme.spaceMd),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(
                                context,
                              ).t('settings.previewHeading'),
                              style: TextStyle(
                                fontSize: 20 * _textScale,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimaryFromContext(context),
                                height: 1.3,
                              ),
                            ),
                            SizedBox(height: AppTheme.spaceMd),
                            Text(
                              AppLocalizations.of(
                                context,
                              ).t('settings.previewBody'),
                              style: TextStyle(
                                fontSize: 14 * _textScale,
                                fontWeight: FontWeight.normal,
                                color: AppTheme.textSecondaryFromContext(
                                  context,
                                ),
                                height: 1.5,
                              ),
                            ),
                            SizedBox(height: AppTheme.spaceMd),
                            Text(
                              AppLocalizations.of(
                                context,
                              ).t('settings.previewSubtext'),
                              style: TextStyle(
                                fontSize: 12 * _textScale,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textTertiaryFromContext(
                                  context,
                                ),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppTheme.spaceLg),

                // Info section
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.accentBlue.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppTheme.accentBlue,
                            size: 20,
                          ),
                          SizedBox(width: AppTheme.spaceSm),
                          Text(
                            AppLocalizations.of(
                              context,
                            ).t('settings.accessibilityTip'),
                            style: AppTheme.labelMedium.copyWith(
                              color: AppTheme.accentBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppTheme.spaceSm),
                      Text(
                        AppLocalizations.of(
                          context,
                        ).t('settings.accessibilityInfo'),
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondaryFromContext(context),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppTheme.space2xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSizeLabel(String label, String percent, BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AppTheme.labelSmall.copyWith(
            color: AppTheme.textPrimaryFromContext(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 4),
        Text(
          percent,
          style: AppTheme.labelSmall.copyWith(
            color: AppTheme.textTertiaryFromContext(context),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
