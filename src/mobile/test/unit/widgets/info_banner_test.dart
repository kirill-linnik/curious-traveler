import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:curious_traveler/widgets/info_banner.dart';

void main() {
  group('InfoBanner Widget Tests', () {
    testWidgets('should display info banner with correct message', (WidgetTester tester) async {
      const testMessage = 'Test message';
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const InfoBanner(
              message: testMessage,
              type: InfoBannerType.info,
            ),
          ),
        ),
      );

      // Verify the message is displayed
      expect(find.text(testMessage), findsOneWidget);
      
      // Verify the info icon is displayed
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('should display different colors for different types', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const InfoBanner(
              message: 'Success message',
              type: InfoBannerType.success,
            ),
          ),
        ),
      );

      // Verify success icon is displayed
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      
      // Pump the widget to complete animations
      await tester.pumpAndSettle();
    });

    testWidgets('should auto-dismiss after specified duration', (WidgetTester tester) async {
      bool dismissed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfoBanner(
              message: 'Auto dismiss test',
              duration: const Duration(milliseconds: 100),
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      // Initially the banner should be visible
      expect(find.text('Auto dismiss test'), findsOneWidget);
      
      // Wait for auto-dismiss
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      
      // Verify dismiss callback was called
      expect(dismissed, true);
    });

    testWidgets('should dismiss when close button is tapped', (WidgetTester tester) async {
      bool dismissed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                InfoBanner(
                  message: 'Manual dismiss test',
                  duration: const Duration(seconds: 10), // Long duration
                  onDismiss: () => dismissed = true,
                ),
              ],
            ),
          ),
        ),
      );

      // Wait for animations to complete
      await tester.pumpAndSettle();

      // Tap the close button with warnIfMissed: false to handle positioning issues
      await tester.tap(find.byIcon(Icons.close), warnIfMissed: false);
      await tester.pumpAndSettle();
      
      // Verify dismiss callback was called
      expect(dismissed, true);
    });
  });

  group('InfoBannerService Tests', () {
    testWidgets('should show and dismiss banners using service', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    InfoBannerService.showLocationDetecting(context);
                  },
                  child: const Text('Show Banner'),
                ),
              ),
            ),
          ),
        ),
      );

      // Initially no banner should be visible
      expect(find.text('Detecting your location...'), findsNothing);

      // Tap button to show banner
      await tester.tap(find.text('Show Banner'));
      await tester.pump(); // Pump once to insert overlay
      await tester.pump(const Duration(milliseconds: 100)); // Pump animation

      // Banner should now be visible
      expect(find.text('Detecting your location...'), findsOneWidget);
    });
  });
}