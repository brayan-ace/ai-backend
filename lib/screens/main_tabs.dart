import 'package:flutter/material.dart';

import 'online_ai_screen.dart';
import 'notes_screen.dart';
import '../utils/globals.dart';
import '../utils/theme.dart';

/// MainTabs with bottom navigation: Your AI (chat) and Notes
class MainTabs extends StatefulWidget {
  final int initialIndex;
  const MainTabs({super.key, this.initialIndex = 0});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const OnlineAiScreen(), // Your AI Chat
      const NotesScreen(), // Notes
    ];

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
        body: IndexedStack(index: _selected, children: pages),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: AppTheme.surfaceGradientFromContext(context),
            ),
            border: Border(
              top: BorderSide(
                color: AppTheme.surfaceElevatedFromContext(
                  context,
                ).withOpacity(0.3),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spaceLg,
                vertical: AppTheme.spaceSm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    icon: Icons.chat_bubble_rounded,
                    label: 'Your AI',
                    index: 0,
                    gradient: AppTheme.primaryGradient,
                  ),
                  _buildNavItem(
                    icon: Icons.note_alt_rounded,
                    label: 'Notes',
                    index: 1,
                    gradient: AppTheme.accentGradient,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required List<Color> gradient,
  }) {
    final isSelected = _selected == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selected = index;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  )
                : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: gradient[0].withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.black : AppTheme.textTertiary,
                size: 28,
              ),
              SizedBox(height: AppTheme.spaceXs),
              Text(
                label,
                style: AppTheme.labelMedium.copyWith(
                  color: isSelected ? Colors.black : AppTheme.textTertiary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
