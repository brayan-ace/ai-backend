import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// Key to control the HomeScreen Scaffold so the top menu can open its drawer.
final GlobalKey<ScaffoldState> homeScaffoldKey = GlobalKey<ScaffoldState>();
// Toggle to hide the top overlay (menu + Get Plus). Use a ValueNotifier so
// UI can listen and rebuild when the value changes.
final ValueNotifier<bool> hideTopOverlay = ValueNotifier<bool>(false);
