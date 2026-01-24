import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'utils/theme_provider.dart';
import 'widgets/auth_gate.dart';
import 'screens/online_ai_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/main_tabs.dart';
import 'screens/welcome_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen_new.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_settings_screen.dart';
import 'screens/capabilities_screen.dart';
import 'screens/placeholder_screen.dart';
import 'screens/home_screen.dart';
import 'screens/api_test_screen.dart';
import 'screens/chat_history_screen.dart';
import 'screens/recent_study_bots_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/analytics_dashboard_screen.dart';
import 'screens/study_plan_screen_phase1.dart';
import 'services/push_notification_service.dart';
import 'services/analytics_service.dart';
import 'services/gamification_service.dart';
import 'utils/globals.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone data
  tz.initializeTimeZones();

  // On web, FirebaseOptions are required when calling initializeApp.
  // If options are not provided, initialization will throw; catch and continue
  // so the app can run in environments where web options are not configured.
  try {
    if (kIsWeb) {
      // Try to initialize; if FirebaseOptions are missing this may throw.
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    // Log and continue without a configured Firebase app (web may lack options)
    // Firebase features will be unavailable in this case.
    // This keeps the app runnable for development/testing on web/desktop.
    // ignore: avoid_print
    print('Firebase initialization skipped or failed: $e');
  }

  // Initialize premium services
  try {
    await PushNotificationService().initialize();
    await AnalyticsService().initialize();
    await GamificationService().initialize();
    print('[Main] ✅ Premium services initialized');
  } catch (e) {
    print('[Main] ⚠️ Premium services initialization failed: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nexa Smart AI',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaleFactor: themeProvider.textScaleFactor),
          child: child!,
        );
      },
      // Use AuthGate as the app home for centralized auth management
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey: navigatorKey,
      home: const AuthGate(),
      routes: {
        '/welcome': (_) => const WelcomeScreen(),
        '/signup': (_) => const SignUpScreen(),
        '/login': (_) => const LoginScreen(),
        '/main': (_) => const MainTabs(),
        '/profile': (_) => ProfileScreen(),
        '/ai': (_) => const OnlineAiScreen(),
        '/online-ai': (_) => const OnlineAiScreen(),
        '/offline': (_) => const MainTabs(initialIndex: 2),
        '/study': (_) => const StudyPlanScreen(),
        '/settings': (_) => const SettingsScreenNew(),
        '/settings-old': (_) => const SettingsScreen(),
        '/profile-settings': (_) => const ProfileSettingsScreen(),
        '/capabilities': (_) => const CapabilitiesScreen(),
        '/notification-settings': (_) => const NotificationSettingsScreen(),
        '/analytics': (_) => const AnalyticsDashboardScreen(),
        '/billing': (_) => const PlaceholderScreen(
          title: 'Billing',
          message: 'Billing features coming soon',
        ),
        '/permissions': (_) => const PlaceholderScreen(
          title: 'Permissions',
          message: 'Permissions will be configurable here soon',
        ),
        '/speech-language': (_) => const PlaceholderScreen(
          title: 'Speech Language',
          message: 'Speech language settings coming soon',
        ),
        '/privacy': (_) => const PlaceholderScreen(
          title: 'Privacy',
          message: 'Privacy settings coming soon',
        ),
        '/home': (_) => const HomeScreen(),
        '/api-test': (_) => const ApiTestScreen(),
        '/notes': (_) => const NotesScreen(),
        '/chat-history': (_) => const ChatHistoryScreen(),
        '/recent-study-bots': (_) => const RecentStudyBotsScreen(),
        '/bot-history': (_) => const RecentStudyBotsScreen(),
      },
    );
  }
}

// Demo widget kept for reference
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
