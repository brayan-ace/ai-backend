import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:provider/provider.dart";
import "package:myai/main.dart";
import "package:myai/utils/theme_provider.dart";
import "package:myai/utils/globals.dart" as globals; // Import globals

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter binding is initialized for tests
  globals.isTesting = true; // Set testing flag

  testWidgets("App starts without critical errors (Firebase not mocked in test)", (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MyApp(),
      ),
    );

    // Await for any asynchronous operations in MyApp\'s build to complete
    await tester.pumpAndSettle();

    // Verify that the MaterialApp widget is present, indicating the app has launched successfully
    // Expecting a MaterialApp to be present, even if Firebase related errors occur in console.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
