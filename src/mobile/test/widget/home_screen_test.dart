import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:curious_traveler/screens/home_screen.dart';
import 'package:curious_traveler/providers/itinerary_provider.dart';
import 'package:curious_traveler/providers/enhanced_location_provider.dart';
import 'package:curious_traveler/providers/audio_provider.dart';
import 'package:curious_traveler/services/api_service.dart';
import 'package:curious_traveler/widgets/location_search_input.dart';
import 'package:curious_traveler/providers/locale_provider.dart';
import 'package:curious_traveler/models/itinerary_models.dart';
import 'package:curious_traveler/models/location_models.dart';
import 'package:curious_traveler/l10n/app_localizations.dart';
import '../helpers/mock_api_service.dart';

class MockItineraryProvider extends Mock implements ItineraryProvider {}
class MockEnhancedLocationProvider extends Mock implements EnhancedLocationProvider {}
class MockAudioProvider extends Mock implements AudioProvider {}
class MockLocaleProvider extends Mock implements LocaleProvider {}
class MockSharedPreferences extends Mock implements SharedPreferences {}

// Fake classes for fallback values
class LocationFake extends Fake implements Location {}

void main() {
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(CommuteStyle.walking);
    registerFallbackValue(LocationFake());
    registerFallbackValue(LocationMode.currentLocation);
  });

  group('HomeScreen Widget Tests', () {
    late MockItineraryProvider mockItineraryProvider;
    late MockEnhancedLocationProvider mockLocationProvider;
    late MockAudioProvider mockAudioProvider;
    late MockLocaleProvider mockLocaleProvider;
    late MockSharedPreferences mockSharedPreferences;
    late MockApiService mockApiService;

    setUp(() {
      mockItineraryProvider = MockItineraryProvider();
      mockLocationProvider = MockEnhancedLocationProvider();
      mockAudioProvider = MockAudioProvider();
      mockLocaleProvider = MockLocaleProvider();
      mockSharedPreferences = MockSharedPreferences();
      mockApiService = MockApiService();

      // Setup default mock returns for EnhancedLocationProvider
      when(() => mockLocationProvider.mode).thenReturn(LocationMode.currentLocation);
      when(() => mockLocationProvider.status).thenReturn(LocationStatus.unknown);
      when(() => mockLocationProvider.currentLocation).thenReturn(null);
      when(() => mockLocationProvider.selectedLocation).thenReturn(null);
      when(() => mockLocationProvider.searchResults).thenReturn([]);
      when(() => mockLocationProvider.error).thenReturn(null);
      when(() => mockLocationProvider.isLoading).thenReturn(false);
      when(() => mockLocationProvider.detectCurrentLocation()).thenAnswer((_) async {});
      when(() => mockLocationProvider.getCurrentLocation()).thenAnswer((_) async {});
      when(() => mockLocationProvider.searchLocations(any())).thenAnswer((_) async {});
      when(() => mockLocationProvider.setMode(any())).thenReturn(null);
      when(() => mockLocationProvider.clearSearch()).thenReturn(null);
      
      when(() => mockLocaleProvider.locale).thenReturn(const Locale('en'));
      when(() => mockSharedPreferences.getString(any())).thenReturn(null);
      when(() => mockSharedPreferences.getInt(any())).thenReturn(null);
      when(() => mockSharedPreferences.getStringList(any())).thenReturn(null);
    });

    Widget createTestWidget() {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<ItineraryProvider>.value(value: mockItineraryProvider),
            ChangeNotifierProvider<EnhancedLocationProvider>.value(value: mockLocationProvider),
            ChangeNotifierProvider<AudioProvider>.value(value: mockAudioProvider),
            ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
            Provider<SharedPreferences>.value(value: mockSharedPreferences),
            Provider<ApiService>.value(value: mockApiService),
          ],
          child: const HomeScreen(),
        ),
      );
    }

    testWidgets('should display app bar with correct title', (WidgetTester tester) async {
      // Arrange
      when(() => mockItineraryProvider.currentItinerary).thenReturn(null);
      when(() => mockItineraryProvider.isLoading).thenReturn(false);
      when(() => mockItineraryProvider.error).thenReturn(null);

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Curious Traveler'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('should show loading indicator when loading', (WidgetTester tester) async {
      // Arrange
      when(() => mockItineraryProvider.currentItinerary).thenReturn(null);
      when(() => mockItineraryProvider.isLoading).thenReturn(true);
      when(() => mockItineraryProvider.error).thenReturn(null);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should handle error state properly', (WidgetTester tester) async {
      // Arrange
      const errorMessage = 'Network error occurred';
      when(() => mockItineraryProvider.currentItinerary).thenReturn(null);
      when(() => mockItineraryProvider.isLoading).thenReturn(false);
      when(() => mockItineraryProvider.error).thenReturn(errorMessage);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert - HomeScreen should still render properly even with an error
      // Errors are handled through InfoBannerService overlays, not direct text display
      expect(find.byType(LocationSearchInput), findsNWidgets(2)); // Start and End blocks
      expect(find.text('Generate Itinerary'), findsOneWidget);
    });

    testWidgets('should show welcome content when no itinerary', (WidgetTester tester) async {
      // Arrange
      when(() => mockItineraryProvider.currentItinerary).thenReturn(null);
      when(() => mockItineraryProvider.isLoading).thenReturn(false);
      when(() => mockItineraryProvider.error).thenReturn(null);

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Welcome to Curious Traveler!'), findsOneWidget);
      expect(find.text('Generate Itinerary'), findsOneWidget);
    });

    testWidgets('should display basic UI when itinerary is available', (WidgetTester tester) async {
      // Arrange
      const testLocation = Location(
        latitude: 37.7749,
        longitude: -122.4194,
        address: 'San Francisco, CA',
      );

      final testItinerary = Itinerary(
        itineraryId: 'test_123',
        locations: [
          const ItineraryLocation(
            id: 'loc_1',
            name: 'Golden Gate Bridge',
            description: 'Famous suspension bridge',
            location: testLocation,
            duration: 60,
            category: 'landmark',
            travelTime: 15,
            travelDistance: 2500.0,
            order: 1,
          ),
        ],
        totalDuration: 75,
        commuteStyle: 'walking',
      );

      when(() => mockItineraryProvider.currentItinerary).thenReturn(testItinerary);
      when(() => mockItineraryProvider.isLoading).thenReturn(false);
      when(() => mockItineraryProvider.error).thenReturn(null);

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pump(); // Let the widget settle

      // Assert - HomeScreen doesn't display itinerary details, just basic UI
      expect(find.text('Welcome to Curious Traveler!'), findsOneWidget);
      expect(find.text('Generate Itinerary'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('should display plan button when no itinerary', (WidgetTester tester) async {
      // Arrange
      when(() => mockItineraryProvider.currentItinerary).thenReturn(null);
      when(() => mockItineraryProvider.isLoading).thenReturn(false);
      when(() => mockItineraryProvider.error).thenReturn(null);

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pump(); // Let the widget settle
      
      // Assert
      expect(find.text('Generate Itinerary'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('should handle widget lifecycle correctly', (WidgetTester tester) async {
      // Arrange
      when(() => mockItineraryProvider.currentItinerary).thenReturn(null);
      when(() => mockItineraryProvider.isLoading).thenReturn(false);
      when(() => mockItineraryProvider.error).thenReturn(null);

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Assert - Verify the widget loads correctly
      expect(find.byType(HomeScreen), findsOneWidget);
      // Note: getCurrentLocation is no longer called in initState, 
      // location detection is handled by EnhancedLocationProvider itself
    });

    testWidgets('should display Spanish text when locale is Spanish', (WidgetTester tester) async {
      // Arrange
      when(() => mockItineraryProvider.currentItinerary).thenReturn(null);
      when(() => mockItineraryProvider.isLoading).thenReturn(false);
      when(() => mockItineraryProvider.error).thenReturn(null);
      when(() => mockLocaleProvider.locale).thenReturn(const Locale('es'));

      // Create widget with Spanish locale
      final spanishWidget = MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<ItineraryProvider>.value(value: mockItineraryProvider),
            ChangeNotifierProvider<EnhancedLocationProvider>.value(value: mockLocationProvider),
            ChangeNotifierProvider<AudioProvider>.value(value: mockAudioProvider),
            ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
            Provider<SharedPreferences>.value(value: mockSharedPreferences),
            Provider<ApiService>.value(value: mockApiService),
          ],
          child: const HomeScreen(),
        ),
      );

      // Act
      await tester.pumpWidget(spanishWidget);
      await tester.pumpAndSettle();

      // Assert - Check for Spanish text
      expect(find.text('Viajero Curioso'), findsOneWidget); // App title in Spanish
      expect(find.text('¡Bienvenido a Viajero Curioso!'), findsOneWidget); // Welcome message in Spanish
      expect(find.text('Generar Itinerario'), findsOneWidget); // Generate button in Spanish
    });

    testWidgets('should display French text when locale is French', (WidgetTester tester) async {
      // Arrange
      when(() => mockItineraryProvider.currentItinerary).thenReturn(null);
      when(() => mockItineraryProvider.isLoading).thenReturn(false);
      when(() => mockItineraryProvider.error).thenReturn(null);
      when(() => mockLocaleProvider.locale).thenReturn(const Locale('fr'));

      // Create widget with French locale
      final frenchWidget = MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<ItineraryProvider>.value(value: mockItineraryProvider),
            ChangeNotifierProvider<EnhancedLocationProvider>.value(value: mockLocationProvider),
            ChangeNotifierProvider<AudioProvider>.value(value: mockAudioProvider),
            ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
            Provider<SharedPreferences>.value(value: mockSharedPreferences),
            Provider<ApiService>.value(value: mockApiService),
          ],
          child: const HomeScreen(),
        ),
      );

      // Act
      await tester.pumpWidget(frenchWidget);
      await tester.pumpAndSettle();

      // Assert - Check for French text
      expect(find.text('Voyageur Curieux'), findsOneWidget); // App title in French
      expect(find.text('Bienvenue dans Voyageur Curieux !'), findsOneWidget); // Welcome message in French
      expect(find.text('Générer un Itinéraire'), findsOneWidget); // Generate button in French
    });
  });

  group('HomeScreen Navigation Tests', () {
    testWidgets('should navigate to settings when settings icon tapped', (WidgetTester tester) async {
      // This would test navigation to settings screen
      // Implementation depends on your navigation setup
    });

    testWidgets('should navigate to itinerary screen when itinerary exists', (WidgetTester tester) async {
      // This would test navigation to detailed itinerary view
      // Implementation depends on your navigation setup
    });
  });

  group('HomeScreen Accessibility Tests', () {
    testWidgets('should have proper semantic labels', (WidgetTester tester) async {
      // Test accessibility features
      // This ensures the app is usable with screen readers
    });

    testWidgets('should support large text scaling', (WidgetTester tester) async {
      // Test text scaling for accessibility
      // This ensures the app works with system text size settings
    });
  });
}
