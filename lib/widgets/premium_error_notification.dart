import 'package:flutter/material.dart';
import 'dart:ui';
import '../utils/theme.dart';
import '../utils/app_localizations.dart';

class PremiumErrorNotification extends StatefulWidget {
  final String errorType; // 'network', 'timeout', 'server_error', 'generic'
  final String? customMessage;
  final VoidCallback? onRetry;
  final Duration displayDuration;

  const PremiumErrorNotification({
    Key? key,
    required this.errorType,
    this.customMessage,
    this.onRetry,
    this.displayDuration = const Duration(seconds: 6),
  }) : super(key: key);

  @override
  State<PremiumErrorNotification> createState() =>
      _PremiumErrorNotificationState();
}

class _PremiumErrorNotificationState extends State<PremiumErrorNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _scheduleHide();
  }

  void _setupAnimations() {
    _animController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));

    _animController.forward();
  }

  void _scheduleHide() {
    Future.delayed(widget.displayDuration, () async {
      if (mounted) {
        await _animController.reverse();
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getErrorConfig() {
    final localizations = AppLocalizations.of(context);
    switch (widget.errorType) {
      case 'network':
        return {
          'title': localizations.t('error.network.title'),
          'message':
              widget.customMessage ?? localizations.t('error.network.message'),
          'icon': Icons.wifi_off_rounded,
          'iconColor': Color(0xFFEF4444),
          'backgroundColor': Color(0xFF7F1D1D),
          'borderColor': Color(0xFFDC2626),
          'accentColor': Color(0xFFDC2626),
        };
      case 'timeout':
        return {
          'title': localizations.t('error.timeout.title'),
          'message':
              widget.customMessage ?? localizations.t('error.timeout.message'),
          'icon': Icons.schedule_rounded,
          'iconColor': Color(0xFFF59E0B),
          'backgroundColor': Color(0xFF78350F),
          'borderColor': Color(0xFFCAA006),
          'accentColor': Color(0xFFCAA006),
        };
      case 'server_error':
        return {
          'title': localizations.t('error.server.title'),
          'message':
              widget.customMessage ?? localizations.t('error.server.message'),
          'icon': Icons.cloud_off_rounded,
          'iconColor': Color(0xFF8B5CF6),
          'backgroundColor': Color(0xFF4C1D95),
          'borderColor': Color(0xABB3D9FF),
          'accentColor': Color(0xABB3D9FF),
        };
      default:
        return {
          'title': localizations.t('error.generic.title'),
          'message':
              widget.customMessage ?? localizations.t('error.generic.message'),
          'icon': Icons.error_outline_rounded,
          'iconColor': Color(0xFF6366F1),
          'backgroundColor': Color(0xFF312E81),
          'borderColor': Color(0xFF818CF8),
          'accentColor': Color(0xFF818CF8),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _getErrorConfig();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  config['backgroundColor'],
                  config['backgroundColor'].withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: config['borderColor'], width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: config['accentColor'].withOpacity(0.3),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with icon and title
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(AppTheme.spaceSm),
                            decoration: BoxDecoration(
                              color: config['accentColor'].withOpacity(0.2),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm,
                              ),
                              border: Border.all(
                                color: config['accentColor'].withOpacity(0.4),
                              ),
                            ),
                            child: Icon(
                              config['icon'],
                              color: config['iconColor'],
                              size: 24,
                            ),
                          ),
                          SizedBox(width: AppTheme.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  config['title'],
                                  style: AppTheme.headlineSmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: AppTheme.spaceXs),
                                Text(
                                  config['message'],
                                  style: AppTheme.bodySmall.copyWith(
                                    color: Colors.white.withOpacity(0.85),
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Retry button (if callback provided)
                      if (widget.onRetry != null) ...[
                        SizedBox(height: AppTheme.spaceMd),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  widget.onRetry?.call();
                                  Navigator.of(context).pop();
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppTheme.spaceMd,
                                    vertical: AppTheme.spaceSm,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        config['accentColor'],
                                        config['accentColor'].withOpacity(0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSm,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: config['accentColor']
                                            .withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.refresh_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: AppTheme.spaceXs),
                                      Text(
                                        AppLocalizations.of(
                                          context,
                                        ).t('error.retryButton'),
                                        style: AppTheme.bodySmall.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
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
                      // Animated loading indicator for persistent notification
                      if (widget.onRetry == null) ...[
                        SizedBox(height: AppTheme.spaceSm),
                        SizedBox(
                          height: 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusXl,
                            ),
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                config['accentColor'],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Show premium error notification
Future<void> showPremiumError(
  BuildContext context, {
  required String errorType,
  String? customMessage,
  VoidCallback? onRetry,
  Duration displayDuration = const Duration(seconds: 6),
}) async {
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return child;
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return Material(
        color: Colors.transparent,
        child: PremiumErrorNotification(
          errorType: errorType,
          customMessage: customMessage,
          onRetry: onRetry,
          displayDuration: displayDuration,
        ),
      );
    },
  );
}
