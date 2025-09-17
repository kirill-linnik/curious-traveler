import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:curious_traveler/screens/settings_screen.dart';
import 'package:curious_traveler/providers/locale_provider.dart';
import 'package:curious_traveler/l10n/app_localizations.dart';

Future<Widget> createTestWidget({
  required Widget child,
  LocaleProvider? localeProvider,
  Locale locale = const Locale('en', 'US'),
}) async {
  final prefs = await SharedPreferences.getInstance();
  
  return MultiProvider(
    providers: [
      Provider<SharedPreferences>.value(value: prefs),
      ChangeNotifierProvider<LocaleProvider>.value(
        value: localeProvider ?? LocaleProvider(),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocaleProvider.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  group('Settings Screen Localization Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('should display localized strings in English', (WidgetTester tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        await createTestWidget(
          child: const SettingsScreen(),
          localeProvider: localeProvider,
        ),
      );

      await tester.pumpAndSettle();

      // Check if English strings are displayed
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Language & Region'), findsOneWidget);
      expect(find.text('Narration Language'), findsOneWidget);
      expect(find.text('Default Preferences'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      
      // Scroll to see more content
      await tester.scrollUntilVisible(find.text('Data & Storage'), 500.0);
      expect(find.text('Data & Storage'), findsOneWidget);
      expect(find.text('Clear Cached Data'), findsOneWidget);
    });

    testWidgets('should display localized strings in Spanish', (WidgetTester tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();
      await localeProvider.setLanguageCode('es-ES');

      await tester.pumpWidget(
        await createTestWidget(
          child: const SettingsScreen(),
          localeProvider: localeProvider,
          locale: const Locale('es', 'ES'),
        ),
      );

      await tester.pumpAndSettle();

      // Check if Spanish strings are displayed
      expect(find.text('Configuración'), findsOneWidget);
      expect(find.text('Idioma y Región'), findsOneWidget);
      expect(find.text('Idioma de Narración'), findsOneWidget);
      expect(find.text('Preferencias Predeterminadas'), findsOneWidget);
      expect(find.text('Acerca de'), findsOneWidget);
      
      // Scroll to see more content
      await tester.scrollUntilVisible(find.text('Datos y Almacenamiento'), 500.0);
      expect(find.text('Datos y Almacenamiento'), findsOneWidget);
      expect(find.text('Limpiar Datos en Caché'), findsOneWidget);
    });

    testWidgets('should display localized strings in French', (WidgetTester tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();
      await localeProvider.setLanguageCode('fr-FR');

      await tester.pumpWidget(
        await createTestWidget(
          child: const SettingsScreen(),
          localeProvider: localeProvider,
          locale: const Locale('fr', 'FR'),
        ),
      );

      await tester.pumpAndSettle();

      // Check if French strings are displayed
      expect(find.text('Paramètres'), findsOneWidget);
      expect(find.text('Langue et Région'), findsOneWidget);
      expect(find.text('Langue de Narration'), findsOneWidget);
      expect(find.text('Préférences par Défaut'), findsOneWidget);
      expect(find.text('À propos'), findsOneWidget);
      
      // Scroll to see more content
      await tester.scrollUntilVisible(find.text('Données et Stockage'), 500.0);
      expect(find.text('Données et Stockage'), findsOneWidget);
      expect(find.text('Effacer les Données en Cache'), findsOneWidget);
    });

    testWidgets('should display localized strings in German', (WidgetTester tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();
      await localeProvider.setLanguageCode('de-DE');

      await tester.pumpWidget(
        await createTestWidget(
          child: const SettingsScreen(),
          localeProvider: localeProvider,
          locale: const Locale('de', 'DE'),
        ),
      );

      await tester.pumpAndSettle();

      // Check if German strings are displayed
      expect(find.text('Einstellungen'), findsOneWidget);
      expect(find.text('Sprache & Region'), findsOneWidget);
      expect(find.text('Erzählsprache'), findsOneWidget);
      expect(find.text('Standardeinstellungen'), findsOneWidget);
      expect(find.text('Über'), findsOneWidget);
      
      // Scroll to see more content
      await tester.scrollUntilVisible(find.text('Daten & Speicher'), 500.0);
      expect(find.text('Daten & Speicher'), findsOneWidget);
      expect(find.text('Zwischengespeicherte Daten Löschen'), findsOneWidget);
    });

    testWidgets('should change language when dropdown selection changes', (WidgetTester tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        await createTestWidget(
          child: const SettingsScreen(),
          localeProvider: localeProvider,
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the language dropdown
      final dropdownFinder = find.byType(DropdownButtonFormField<String>);
      expect(dropdownFinder, findsOneWidget);
      
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      // Find and tap Spanish option
      await tester.tap(find.text('Spanish').last);
      await tester.pumpAndSettle();

      // Verify the locale changed
      expect(localeProvider.currentLanguageCode, equals('es-ES'));
    });

    testWidgets('should show clear data dialog with localized text', (WidgetTester tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        await createTestWidget(
          child: const SettingsScreen(),
          localeProvider: localeProvider,
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to see the clear data option
      await tester.scrollUntilVisible(find.text('Clear Cached Data'), 500.0);

      // Tap on clear cached data option
      await tester.tap(find.text('Clear Cached Data'));
      await tester.pumpAndSettle();

      // Verify dialog appears with localized text
      expect(find.text('Clear Data'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
    });

    testWidgets('should show privacy policy dialog with localized text', (WidgetTester tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        await createTestWidget(
          child: const SettingsScreen(),
          localeProvider: localeProvider,
        ),
      );

      await tester.pumpAndSettle();

      // Tap on privacy policy option
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      // Verify dialog appears with localized text
      expect(find.text('Privacy Policy'), findsAtLeastNWidgets(1));
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('should show help dialog with localized text', (WidgetTester tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        await createTestWidget(
          child: const SettingsScreen(),
          localeProvider: localeProvider,
        ),
      );

      await tester.pumpAndSettle();

      // Tap on help & support option
      await tester.tap(find.text('Help & Support'));
      await tester.pumpAndSettle();

      // Verify dialog appears with localized text
      expect(find.text('Help & Support'), findsAtLeastNWidgets(1));
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('should persist language selection', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'language': 'fr-FR'});
      
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        await createTestWidget(
          child: const SettingsScreen(),
          localeProvider: localeProvider,
          locale: const Locale('fr', 'FR'),
        ),
      );

      await tester.pumpAndSettle();

      // Verify French is the selected language
      expect(localeProvider.currentLanguageCode, equals('fr-FR'));
      
      // Check that French is displayed in the dropdown
      expect(find.text('French'), findsOneWidget);
    });
  });
}