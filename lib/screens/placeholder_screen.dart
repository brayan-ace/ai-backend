import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../utils/app_localizations.dart';

class PlaceholderScreen extends StatelessWidget {
  final String titleKey;
  final String messageKey;

  const PlaceholderScreen({
    super.key,
    required this.titleKey,
    this.messageKey = 'common.comingSoon',
  });

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
        extendBodyBehindAppBar: true,
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
          title: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: AppTheme.primaryGradient,
            ).createShader(bounds),
            child: Text(
              AppLocalizations.of(context).t(titleKey),
              style: AppTheme.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spaceLg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: AppTheme.primaryGradient,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      boxShadow: AppTheme.glowShadow,
                    ),
                    child: Icon(
                      Icons.rocket_launch,
                      color: Colors.black,
                      size: 60,
                    ),
                  ),
                  SizedBox(height: AppTheme.spaceLg),
                  Text(
                    AppLocalizations.of(context).t('common.comingSoon'),
                    style: AppTheme.headlineLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppTheme.spaceMd),
                  Text(
                    AppLocalizations.of(context).t(messageKey),
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppTheme.spaceXl),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceLg,
                        vertical: AppTheme.spaceMd,
                      ),
                    ),
                    child: Text('Go Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
