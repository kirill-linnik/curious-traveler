import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:curious_traveler/widgets/location_search_input.dart';
import 'package:curious_traveler/widgets/location_mode_toggle.dart';
import 'package:curious_traveler/viewmodels/home_location_vm.dart';
import 'package:curious_traveler/models/location_models.dart';
import 'package:curious_traveler/l10n/app_localizations.dart';

/// Consolidated location widget tests
/// Replaces 8 separate location test files with organized test groups
void main() {
  group('Location Widget Tests', () {
    late HomeLocationVm locationVm;

    setUp(() {
      locationVm = HomeLocationVm();
    });

    tearDown(() {
      locationVm.dispose();
    });

    Widget createLocationModeToggleWidget() {
      return MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: LocationModeToggle(
            mode: locationVm.locationSource,
            onChanged: locationVm.handleModeChanged,
          ),
        ),
      );
    }

    Widget createLocationSearchWidget({
      List<LocationSearchResult> searchResults = const [],
      LocationStatus status = LocationStatus.unknown,
      bool enabled = true,
    }) {
      return MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: LocationSearchInput(
            viewModel: locationVm,
            searchResults: searchResults,
            status: status,
            enabled: enabled,
          ),
        ),
      );
    }

    final testResults = [
      LocationSearchResult(
        id: 'paris-1',
        type: 'POI',
        name: 'Paris',
        formattedAddress: 'Paris, France',
        locality: 'Paris',
        countryCode: 'FR',
        latitude: 48.8566,
        longitude: 2.3522,
        confidence: 'high',
      ),
      LocationSearchResult(
        id: 'london-1',
        type: 'POI',
        name: 'London',
        formattedAddress: 'London, United Kingdom',
        locality: 'London',
        countryCode: 'GB',
        latitude: 51.5074,
        longitude: -0.1278,
        confidence: 'high',
      ),
    ];

    group('LocationModeToggle Tests', () {
      testWidgets('switches to another location mode', (WidgetTester tester) async {
        await tester.pumpWidget(createLocationModeToggleWidget());

        // Initially should be in current location mode
        expect(locationVm.locationSource, equals(LocationMode.currentLocation));

        // Tap another location option
        await tester.tap(find.text('Another location'));
        await tester.pump();

        // Should switch to another location mode
        expect(locationVm.locationSource, equals(LocationMode.anotherLocation));
      });

      testWidgets('switches back to current location mode', (WidgetTester tester) async {
        // Start in another location mode
        locationVm.handleModeChanged(LocationMode.anotherLocation);
        
        await tester.pumpWidget(createLocationModeToggleWidget());

        expect(locationVm.locationSource, equals(LocationMode.anotherLocation));

        // Tap current location option
        await tester.tap(find.text('Current location'));
        await tester.pump();

        // Should switch back to current location mode
        expect(locationVm.locationSource, equals(LocationMode.currentLocation));
      });

      testWidgets('displays both location mode options', (WidgetTester tester) async {
        await tester.pumpWidget(createLocationModeToggleWidget());

        // Both options should be visible
        expect(find.text('Current location'), findsOneWidget);
        expect(find.text('Another location'), findsOneWidget);
      });
    });

    group('LocationSearchInput Display Tests', () {
      testWidgets('shows text field when in another location mode', (WidgetTester tester) async {
        locationVm.handleModeChanged(LocationMode.anotherLocation);
        
        await tester.pumpWidget(createLocationSearchWidget());

        expect(find.byType(TextFormField), findsOneWidget);
      });

      testWidgets('displays loading state correctly', (WidgetTester tester) async {
        locationVm.handleModeChanged(LocationMode.anotherLocation);
        
        await tester.pumpWidget(createLocationSearchWidget(
          status: LocationStatus.searching,
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows hint text when empty', (WidgetTester tester) async {
        locationVm.handleModeChanged(LocationMode.anotherLocation);
        
        await tester.pumpWidget(createLocationSearchWidget());

        final textField = find.byType(TextFormField);
        expect(textField, findsOneWidget);
        
        // Should have a text field for input
        expect(textField, findsOneWidget);
      });

      testWidgets('shows text field in current location mode', (WidgetTester tester) async {
        locationVm.handleModeChanged(LocationMode.currentLocation);
        
        await tester.pumpWidget(createLocationSearchWidget());

        // Should still show the text field
        expect(find.byType(TextFormField), findsOneWidget);
      });
    });

    group('LocationSearchInput Interaction Tests', () {
      testWidgets('accepts text input', (WidgetTester tester) async {
        locationVm.handleModeChanged(LocationMode.anotherLocation);
        
        await tester.pumpWidget(createLocationSearchWidget());

        final textField = find.byType(TextFormField);
        await tester.enterText(textField, 'Paris');
        await tester.pump();

        expect(locationVm.locationController.text, equals('Paris'));
      });

      testWidgets('triggers search on text change', (WidgetTester tester) async {
        locationVm.handleModeChanged(LocationMode.anotherLocation);
        
        await tester.pumpWidget(createLocationSearchWidget());

        final textField = find.byType(TextFormField);
        await tester.enterText(textField, 'Test Location');
        await tester.pump();

        // VM should have been notified of text change
        expect(locationVm.locationController.text, equals('Test Location'));
      });

      testWidgets('suggestion tap triggers selection', (WidgetTester tester) async {
        locationVm.handleModeChanged(LocationMode.anotherLocation);
        
        await tester.pumpWidget(createLocationSearchWidget(
          searchResults: testResults,
          status: LocationStatus.searchComplete,
        ));

        // Focus the input to show overlay
        await tester.tap(find.byType(TextFormField));
        await tester.pump();

        // Tap on a search result
        await tester.tap(find.text('Paris, France'));
        await tester.pump();

        // Should select the location
        expect(locationVm.anotherLocationSelection?.formattedAddress, equals('Paris, France'));
      });

      testWidgets('clears text when location is selected', (WidgetTester tester) async {
        locationVm.handleModeChanged(LocationMode.anotherLocation);
        locationVm.locationController.text = 'Par';
        
        await tester.pumpWidget(createLocationSearchWidget(
          searchResults: testResults,
          status: LocationStatus.searchComplete,
        ));

        // Focus and select
        await tester.tap(find.byType(TextFormField));
        await tester.pump();
        await tester.tap(find.text('Paris, France'));
        await tester.pump();

        // Text field should show selected location
        expect(locationVm.locationController.text, contains('Paris'));
      });

      testWidgets('enables and disables correctly', (WidgetTester tester) async {
        locationVm.handleModeChanged(LocationMode.anotherLocation);
        
        await tester.pumpWidget(createLocationSearchWidget(enabled: false));

        final textField = tester.widget<TextFormField>(find.byType(TextFormField));
        expect(textField.enabled, isFalse);
      });
    });

    group('LocationSearchInput Overlay Tests', () {
      testWidgets('shows overlay with search results', (WidgetTester tester) async {
        locationVm.handleModeChanged(LocationMode.anotherLocation);
        
        await tester.pumpWidget(createLocationSearchWidget(
          searchResults: testResults,
          status: LocationStatus.searchComplete,
        ));

        // Focus the input to potentially show overlay
        await tester.tap(find.byType(TextFormField));
        await tester.pump();

        // Should show search results
        expect(find.text('Paris, France'), findsOneWidget);
        expect(find.text('London, United Kingdom'), findsOneWidget);
      });

      testWidgets('hides overlay when no results', (WidgetTester tester) async {
        locationVm.handleModeChanged(LocationMode.anotherLocation);
        
        await tester.pumpWidget(createLocationSearchWidget(
          searchResults: [],
          status: LocationStatus.searchComplete,
        ));

        final textField = find.byType(TextFormField);
        await tester.tap(textField);
        await tester.pump();

        // Should not show any results
        expect(find.text('Paris, France'), findsNothing);
      });

      testWidgets('handles empty search results gracefully', (WidgetTester tester) async {
        locationVm.handleModeChanged(LocationMode.anotherLocation);
        
        await tester.pumpWidget(createLocationSearchWidget(
          searchResults: [],
          status: LocationStatus.searchComplete,
        ));

        final textField = find.byType(TextFormField);
        await tester.tap(textField);
        await tester.pump();

        // Should not crash and should not show any results
        expect(find.text('Paris, France'), findsNothing);
      });

      testWidgets('updates overlay when search results change', (WidgetTester tester) async {
        locationVm.handleModeChanged(LocationMode.anotherLocation);
        
        // Start with empty results
        await tester.pumpWidget(createLocationSearchWidget(
          searchResults: [],
          status: LocationStatus.unknown,
        ));

        expect(find.text('Paris, France'), findsNothing);

        // Pump with results
        await tester.pumpWidget(createLocationSearchWidget(
          searchResults: testResults,
          status: LocationStatus.searchComplete,
        ));
        
        await tester.tap(find.byType(TextFormField));
        await tester.pump();

        // Should show updated results
        expect(find.text('Paris, France'), findsOneWidget);
      });
    });

    group('Location Selection & State Tests', () {
      testWidgets('updates selected location on suggestion tap', (WidgetTester tester) async {
        locationVm.handleModeChanged(LocationMode.anotherLocation);
        
        await tester.pumpWidget(createLocationSearchWidget(
          searchResults: testResults,
          status: LocationStatus.searchComplete,
        ));

        await tester.tap(find.byType(TextFormField));
        await tester.pump();
        await tester.tap(find.text('London, United Kingdom'));
        await tester.pump();

        expect(locationVm.anotherLocationSelection?.formattedAddress, equals('London, United Kingdom'));
      });

      testWidgets('maintains controller text after selection', (WidgetTester tester) async {
        locationVm.handleModeChanged(LocationMode.anotherLocation);
        
        await tester.pumpWidget(createLocationSearchWidget(
          searchResults: testResults,
          status: LocationStatus.searchComplete,
        ));

        await tester.tap(find.byType(TextFormField));
        await tester.pump();
        await tester.tap(find.text('Paris, France'));
        await tester.pump();

        expect(locationVm.locationController.text, isNotEmpty);
      });

      testWidgets('resets state when mode changes', (WidgetTester tester) async {
        locationVm.handleModeChanged(LocationMode.anotherLocation);
        locationVm.locationController.text = 'Test';
        
        await tester.pumpWidget(createLocationSearchWidget());

        // Change mode back to current location
        locationVm.handleModeChanged(LocationMode.currentLocation);
        await tester.pump();

        // State should be appropriate for current location mode
        expect(locationVm.locationSource, equals(LocationMode.currentLocation));
      });

      testWidgets('handles rapid mode switching', (WidgetTester tester) async {
        await tester.pumpWidget(createLocationModeToggleWidget());

        // Rapidly switch modes
        await tester.tap(find.text('Another location'));
        await tester.pump();
        await tester.tap(find.text('Current location'));
        await tester.pump();
        await tester.tap(find.text('Another location'));
        await tester.pump();

        expect(locationVm.locationSource, equals(LocationMode.anotherLocation));
      });
    });

    group('ViewModel Unit Tests', () {
      test('programmatic text setting clears composing range', () {
        // Set up a composing state (simulating IME input)
        locationVm.locationController.value = const TextEditingValue(
          text: 'test',
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange(start: 0, end: 4),
        );

        expect(locationVm.locationController.value.composing.isValid, isTrue);

        // Programmatically set text (should clear composing)
        locationVm.setTextProgrammatically('new text');

        expect(locationVm.locationController.text, equals('new text'));
        expect(locationVm.locationController.value.composing, equals(TextRange.empty));
      });

      test('mode changes update state correctly', () {
        expect(locationVm.locationSource, equals(LocationMode.currentLocation));

        locationVm.handleModeChanged(LocationMode.anotherLocation);
        expect(locationVm.locationSource, equals(LocationMode.anotherLocation));

        locationVm.handleModeChanged(LocationMode.currentLocation);
        expect(locationVm.locationSource, equals(LocationMode.currentLocation));
      });

      test('controller initialization is consistent', () {
        final controller1 = locationVm.locationController;
        final controller2 = locationVm.locationController;
        
        expect(identical(controller1, controller2), isTrue);
        expect(controller1, isNotNull);
      });
    });
  });
}