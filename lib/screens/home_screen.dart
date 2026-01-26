import 'package:flutter/material.dart';

import '../utils/globals.dart';
import '../services/study_plan_service.dart';
import '../utils/theme.dart';
import '../services/user_profile_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: homeScaffoldKey,
      drawer: Drawer(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Futuristic header
                Container(
                  margin: EdgeInsets.all(AppTheme.spaceMd),
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppTheme.primaryGradient),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: AppTheme.glowShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(AppTheme.spaceSm),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          color: Colors.black,
                          size: 32,
                        ),
                      ),
                      SizedBox(width: AppTheme.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome',
                              style: AppTheme.bodySmall.copyWith(
                                color: Colors.black.withOpacity(0.7),
                              ),
                            ),
                            Text(
                              UserProfileService.instance.getDisplayNameSync(),
                              style: AppTheme.headlineMedium.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.settings, color: Colors.black),
                          onPressed: () =>
                              navigatorKey.currentState?.pushNamed('/settings'),
                        ),
                      ),
                    ],
                  ),
                ),

                // Futuristic search
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
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search chats and projects',
                        hintStyle: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppTheme.primaryBlue,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMd,
                          vertical: AppTheme.spaceSm,
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: AppTheme.spaceLg),

                // Study Plans Section - NEW!
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
                  child: Text(
                    'Study Plans',
                    style: AppTheme.labelMedium.copyWith(
                      color: AppTheme.textTertiary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: AppTheme.spaceSm),
                _buildDrawerItem(
                  icon: Icons.school_rounded,
                  title: 'My Study Plans',
                  context: context,
                  onTap: () {
                    navigatorKey.currentState?.pushNamed('/study');
                  },
                ),

                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMd,
                    vertical: AppTheme.spaceSm,
                  ),
                  child: Divider(color: AppTheme.surfaceElevated, height: 1),
                ),

                // Chats section
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
                  child: Text(
                    'Chats',
                    style: AppTheme.labelMedium.copyWith(
                      color: AppTheme.textTertiary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: AppTheme.spaceSm),
                _buildDrawerItem(
                  icon: Icons.chat_bubble_outline,
                  title: 'All chats',
                  context: context,
                ),
                _buildDrawerItem(
                  icon: Icons.star_border,
                  title: 'Starred',
                  context: context,
                ),
                _buildDrawerItem(
                  icon: Icons.archive_outlined,
                  title: 'Archived',
                  context: context,
                ),

                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMd,
                    vertical: AppTheme.spaceSm,
                  ),
                  child: Divider(color: AppTheme.surfaceElevated, height: 1),
                ),

                // Workspaces
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
                  child: Text(
                    'Workspaces',
                    style: AppTheme.labelMedium.copyWith(
                      color: AppTheme.textTertiary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: AppTheme.spaceSm),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: StudyPlanService().getPlans(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryBlue,
                            ),
                          ),
                        );
                      }
                      final plans = snap.data ?? [];
                      if (plans.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.all(AppTheme.spaceMd),
                          child: Text(
                            'No projects yet',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: plans.length,
                        itemBuilder: (context, i) {
                          final p = plans[i];
                          final title = p['title'] as String? ?? '(no title)';
                          return _buildWorkspaceItem(
                            title: title,
                            context: context,
                            onTap: () {
                              Navigator.pop(context);
                              hideTopOverlay.value = true;
                              navigatorKey.currentState
                                  ?.pushNamed('/study')
                                  .then((_) {
                                    hideTopOverlay.value = false;
                                  });
                            },
                          );
                        },
                      );
                    },
                  ),
                ),

                // Footer
                Padding(
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  child: Text(
                    'Version 1.0 • Privacy • Terms',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
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
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppTheme.spaceLg),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 100),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: AppTheme.primaryGradient,
                  ).createShader(bounds),
                  child: Text(
                    'What can I help with?',
                    style: AppTheme.displayLarge.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: AppTheme.spaceMd),
                Text(
                  'Quick starters — choose a persona or task to get going',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                SizedBox(height: AppTheme.space2xl),
                Wrap(
                  spacing: AppTheme.spaceMd,
                  runSpacing: AppTheme.spaceMd,
                  alignment: WrapAlignment.center,
                  children: [
                    _BigChip(
                      label: 'Talk to a friend',
                      icon: Icons.forum,
                      gradient: AppTheme.primaryGradient,
                      onTap: () => navigatorKey.currentState?.pushNamed('/ai'),
                    ),
                    _BigChip(
                      label: 'Discover the app',
                      icon: Icons.explore,
                      gradient: AppTheme.accentGradient,
                      onTap: () =>
                          navigatorKey.currentState?.pushNamed('/study'),
                    ),
                    _BigChip(
                      label: 'Talk to your agents',
                      icon: Icons.smart_toy,
                      gradient: AppTheme.primaryGradient,
                      onTap: () => navigatorKey.currentState?.pushNamed('/ai'),
                    ),
                    _BigChip(
                      label: 'Dating assistant',
                      icon: Icons.favorite,
                      gradient: AppTheme.accentGradient,
                      onTap: () => navigatorKey.currentState?.pushNamed('/ai'),
                    ),
                    _BigChip(
                      label: 'Create image',
                      icon: Icons.image,
                      gradient: AppTheme.primaryGradient,
                      onTap: () => navigatorKey.currentState?.pushNamed('/ai'),
                    ),
                    _BigChip(
                      label: 'Summarize text',
                      icon: Icons.text_snippet,
                      gradient: AppTheme.accentGradient,
                      onTap: () => navigatorKey.currentState?.pushNamed('/ai'),
                    ),
                    _BigChip(
                      label: 'Analyze data',
                      icon: Icons.analytics,
                      gradient: AppTheme.primaryGradient,
                      onTap: () => navigatorKey.currentState?.pushNamed('/ai'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required BuildContext context,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceSm, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.textSecondary, size: 20),
        title: Text(
          title,
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
        ),
        onTap: onTap ?? () => Navigator.pop(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        hoverColor: AppTheme.surfaceElevated.withOpacity(0.5),
      ),
    );
  }

  Widget _buildWorkspaceItem({
    required String title,
    required BuildContext context,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceSm, vertical: 2),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(AppTheme.spaceSm),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: AppTheme.accentGradient),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(Icons.folder_open, color: Colors.white, size: 16),
        ),
        title: Text(
          title,
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        hoverColor: AppTheme.surfaceElevated.withOpacity(0.5),
      ),
    );
  }
}

class _BigChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _BigChip({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spaceLg,
          vertical: AppTheme.spaceMd,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: AppTheme.surfaceGradient),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: AppTheme.surfaceElevated.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            SizedBox(width: AppTheme.spaceSm),
            Text(
              label,
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
