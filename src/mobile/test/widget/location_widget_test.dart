import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:curious_traveler/widgets/location_mode_toggle.dart';
import 'package:curious_traveler/viewmodels/home_location_vm.dart';
import 'package:curious_traveler/viewmodels/journey_endpoint_state.dart';
import 'package:curious_traveler/models/location_models.dart';
import 'package:curious_traveler/l10n/app_localizations.dart';

void main() {
  group('Location Widget Tests', () {
    late HomeLocationVm locationVm;

    setUp(() {
      locationVm = HomeLocationVm();
    });

    tearDown(() {
      locationVm.dispose();
    });

    testWidgets('start endpoint mode toggle works', (WidgetTester tester) async {
      final widget = MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: LocationModeToggle(
            mode: locationVm.start.mode,
            onChanged: (mode) => locationVm.start.mode = mode,
          ),
        ),
      );

      await tester.pumpWidget(widget);
      
      expect(find.text('Current location'), findsOneWidget);
      expect(find.text('Another location'), findsOneWidget);
      expect(locationVm.start.mode, equals(LocationMode.currentLocation));

      await tester.tap(find.text('Another location'));
      await tester.pump();

      expect(locationVm.start.mode, equals(LocationMode.anotherLocation));
    });

    test('endpoints work independently', () {
      locationVm.start.mode = LocationMode.anotherLocation;
      locationVm.end.mode = LocationMode.currentLocation;

      expect(locationVm.start.mode, equals(LocationMode.anotherLocation));
      expect(locationVm.end.mode, equals(LocationMode.currentLocation));
    });
  });
}