import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'offline_ai_screen.dart';
import 'profile_screen.dart';

/// Minimal, safe MainTabs used while repairing the original implementation.
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
      const HomeScreen(),
      const Center(child: Text('Online AI (placeholder)')),
      const OfflineAiScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: const [
            DrawerHeader(child: Text('Menu')),
            ListTile(title: Text('Placeholder')),
          ],
        ),
      ),
      body: Stack(
        children: [
          IndexedStack(index: _selected, children: pages),
          if (_selected == 0)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: context,
                          builder: (ctx) => Container(
                            padding: const EdgeInsets.all(20),
                            child: const Text('Get Plus sheet'),
                          ),
                        );
                      },
                      child: const Text('Get Plus'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
