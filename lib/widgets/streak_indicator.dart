/// ============================================================================
/// DAILY STREAK INDICATOR - PREMIUM UX FEATURE
/// ============================================================================
///
/// This widget displays a beautiful, interactive streak indicator that:
/// 1. Shows the current study streak using the 🔥 emoji + number
/// 2. Appears in the hamburger menu (drawer header) next to "Chats"
/// 3. Taps to open a premium details modal with streak information
///
/// IMPORTANT: REUSES EXISTING STREAK LOGIC
/// This widget does NOT implement any new streak calculation. Instead, it:
/// - Reads from StudyActivityService (existing singleton)
/// - Displays stats.currentStreak (already calculated elsewhere)
/// - Respects the existing 24-48h logic
/// - Works with existing notification system
///
/// Existing Logic Architecture (NOT modified):
/// ┌─────────────────────────────────────────────────────┐
/// │ StudyActivityService (lib/services/)                 │
/// │ - Records study activities when user sends message   │
/// │ - Manages: currentStreak, longestStreak, lastStudy  │
/// │ - Persists in SharedPreferences                      │
/// │ - Streak Rules:                                      │
/// │   * < 24h since last study → no increment            │
/// │   * 24-48h → increment by 1                          │
/// │   * > 48h → reset to 1                               │
/// └─────────────────────────────────────────────────────┘
///                          ↓
/// ┌─────────────────────────────────────────────────────┐
/// │ StreakIndicator (THIS FILE)                          │
/// │ - Reads currentStreak from above                     │
/// │ - Displays with 🔥 icon                             │
/// │ - Premium animations & glows                         │
/// │ - Navigates to StreakDetailsModal on tap             │
/// └─────────────────────────────────────────────────────┘
///                          ↓
/// ┌─────────────────────────────────────────────────────┐
/// │ StreakDetailsModal (lib/widgets/)                    │
/// │ - Shows current & longest streak                     │
/// │ - Displays calendar of recent days                   │
/// │ - Highlighting: active days vs missed days           │
/// │ - Motivational messages based on streak length       │
/// │ - Premium glassmorphism & animations                │
/// └─────────────────────────────────────────────────────┘
///
/// VISUAL HIERARCHY:
/// Menu Header
/// ├── "Chats" label (big, gradient)
/// ├── + button (add new chat)
/// └── 🔥 Streak Indicator ← THIS WIDGET
///     (Shows: 🔥 6 → )
///     (Tappable)
///
/// STYLING DECISIONS:
/// • Subtle gradient background (not bold)
/// • Glow animation (breathing effect)
/// • Icon scales smoothly
/// • Border with blue tint (matches theme)
/// • Arrow indicator shows it's tappable
/// • Only shows if streak > 0
///
/// INTEGRATION POINTS:
/// 1. online_ai_screen.dart: _buildDrawer() method
///    Placed right below "Chats" + button section
/// 2. StreakDetailsModal imported and called on tap
/// 3. No modifications to existing service layer
///
/// ANIMATION DETAILS:
/// • Glow opacity: 0.3 → 0.6 (breathing)
/// • Duration: 2000ms (slow, elegant)
/// • Flame icon: scales 1.0 → 1.1
/// • Curve: easeInOut (smooth)
///
/// PERFORMANCE:
/// • Lazy loads streak data (doesn't block UI)
/// • Shows SizedBox.shrink() if no streak yet
/// • Single service initialization
/// • Lightweight animation controller
///
/// FUTURE ENHANCEMENTS:
/// • Add haptic feedback on tap
/// • Animated flame when streak increments
/// • Daily notification coordination
/// • Streak achievements/badges

import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../services/study_activity_service.dart';

/// Premium streak indicator widget
/// Displays current streak with 🔥 icon in a clean, tappable format
/// Designed for hamburger menu integration
class StreakIndicator extends StatefulWidget {
  final VoidCallback? onTap;

  const StreakIndicator({super.key, this.onTap});

  @override
  State<StreakIndicator> createState() => _StreakIndicatorState();
}

class _StreakIndicatorState extends State<StreakIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  int _currentStreak = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupGlowAnimation();
    _loadStreakData();
  }

  void _setupGlowAnimation() {
    _glowController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadStreakData() async {
    try {
      final activityService = StudyActivityService();
      await activityService.initialize();
      final stats = await activityService.getStudyStats();

      if (mounted) {
        setState(() {
          _currentStreak = stats.currentStreak;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[StreakIndicator] Error loading streak data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return SizedBox.shrink();
    }

    // Only show if streak > 0
    if (_currentStreak == 0) {
      return SizedBox.shrink();
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMd,
                vertical: AppTheme.spaceSm,
              ),
              decoration: BoxDecoration(
                // Subtle gradient background
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Color(0xFF1976D2).withOpacity(0.15),
                          Color(0xFF42A5F5).withOpacity(0.08),
                        ]
                      : [
                          Color(0xFF1976D2).withOpacity(0.08),
                          Color(0xFF42A5F5).withOpacity(0.05),
                        ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(isDark ? 0.25 : 0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(
                      0xFF2196F3,
                    ).withOpacity(_glowAnimation.value * (isDark ? 1.0 : 0.5)),
                    blurRadius: 16,
                    spreadRadius: 0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flame icon with scale animation
                  ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.1).animate(
                      CurvedAnimation(
                        parent: _glowController,
                        curve: Curves.easeInOut,
                      ),
                    ),
                    child: Text('🔥', style: TextStyle(fontSize: 20)),
                  ),
                  SizedBox(width: AppTheme.spaceXs),
                  // Streak count
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: AppTheme.primaryGradient,
                    ).createShader(bounds),
                    child: Text(
                      '$_currentStreak',
                      style: AppTheme.labelLargeFromContext(context).copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: AppTheme.spaceXs),
                  // Subtle arrow indicator
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppTheme.primaryBlue.withOpacity(isDark ? 0.6 : 0.4),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
