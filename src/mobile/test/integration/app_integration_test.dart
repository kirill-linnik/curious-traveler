import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:curious_traveler/main.dart' as app;
import '../helpers/test_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Curious Traveler Integration Tests', () {
    setUp(() async {
      // Set up test environment with mocked plugins
      setupTestEnvironment();
      await initializeSharedPreferencesForTests();
    });

    testWidgets('App launches successfully', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Should start on the home screen
      expect(find.text('Curious Traveler'), findsOneWidget);
    });

    testWidgets('Settings screen can be opened', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Look for settings button (assuming it exists in the UI)
      final settingsButton = find.byIcon(Icons.settings);
      if (settingsButton.hasFound) {
        await tester.tap(settingsButton);
        await tester.pumpAndSettle();

        // Verify settings screen is displayed
        expect(find.text('Settings'), findsOneWidget);
      }
    });
  });
}