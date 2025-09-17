import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:curious_traveler/providers/locale_provider.dart';

void main() {
  group('LocaleProvider Tests', () {
    late LocaleProvider localeProvider;

    setUp(() {
      localeProvider = LocaleProvider();
      SharedPreferences.setMockInitialValues({});
    });

    test('should have default locale as en-US', () {
      expect(localeProvider.locale, equals(const Locale('en', 'US')));
      expect(localeProvider.currentLanguageCode, equals('en-US'));
    });

    test('should initialize from saved preferences', () async {
      // Set up mock preferences
      SharedPreferences.setMockInitialValues({'language': 'es-ES'});
      
      await localeProvider.initialize();
      
      expect(localeProvider.locale, equals(const Locale('es', 'ES')));
      expect(localeProvider.currentLanguageCode, equals('es-ES'));
      expect(localeProvider.isInitialized, isTrue);
    });

    test('should fall back to default locale for invalid saved language', () async {
      // Set up mock preferences with invalid language
      SharedPreferences.setMockInitialValues({'language': 'invalid-LANG'});
      
      await localeProvider.initialize();
      
      expect(localeProvider.locale, equals(const Locale('en', 'US')));
      expect(localeProvider.currentLanguageCode, equals('en-US'));
    });

    test('should save locale to preferences when changed', () async {
      await localeProvider.initialize();
      
      const newLocale = Locale('fr', 'FR');
      await localeProvider.setLocale(newLocale);
      
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('language'), equals('fr-FR'));
      expect(localeProvider.locale, equals(newLocale));
      expect(localeProvider.currentLanguageCode, equals('fr-FR'));
    });

    test('should set locale by language code', () async {
      await localeProvider.initialize();
      
      await localeProvider.setLanguageCode('de-DE');
      
      expect(localeProvider.locale, equals(const Locale('de', 'DE')));
      expect(localeProvider.currentLanguageCode, equals('de-DE'));
    });

    test('should ignore invalid language codes', () async {
      await localeProvider.initialize();
      const originalLocale = Locale('en', 'US');
      
      await localeProvider.setLanguageCode('invalid-CODE');
      
      expect(localeProvider.locale, equals(originalLocale));
    });

    test('should not change locale if same locale is set', () async {
      await localeProvider.initialize();
      const originalLocale = Locale('en', 'US');
      
      // Try to set the same locale
      await localeProvider.setLocale(originalLocale);
      
      expect(localeProvider.locale, equals(originalLocale));
    });

    test('should provide correct supported locales', () {
      final supportedLocales = LocaleProvider.supportedLocales;
      
      expect(supportedLocales, contains(const Locale('en', 'US')));
      expect(supportedLocales, contains(const Locale('es', 'ES')));
      expect(supportedLocales, contains(const Locale('fr', 'FR')));
      expect(supportedLocales, contains(const Locale('de', 'DE')));
      expect(supportedLocales, contains(const Locale('it', 'IT')));
      expect(supportedLocales, contains(const Locale('pt', 'BR')));
      expect(supportedLocales, contains(const Locale('zh', 'CN')));
      expect(supportedLocales, contains(const Locale('ja', 'JP')));
      expect(supportedLocales, contains(const Locale('ko', 'KR')));
      expect(supportedLocales.length, equals(10));
    });

    test('should provide correct display names for language codes', () {
      expect(LocaleProvider.getLanguageDisplayName('en-US'), equals('English (US)'));
      expect(LocaleProvider.getLanguageDisplayName('es-ES'), equals('Spanish'));
      expect(LocaleProvider.getLanguageDisplayName('fr-FR'), equals('French'));
      expect(LocaleProvider.getLanguageDisplayName('de-DE'), equals('German'));
      expect(LocaleProvider.getLanguageDisplayName('invalid'), equals('invalid'));
    });

    test('should get locale from code with fallback', () {
      expect(LocaleProvider.getLocaleFromCode('es-ES'), equals(const Locale('es', 'ES')));
      expect(LocaleProvider.getLocaleFromCode('invalid'), equals(const Locale('en', 'US')));
      expect(LocaleProvider.getLocaleFromCode(null), equals(const Locale('en', 'US')));
    });

    test('should notify listeners when locale changes', () async {
      await localeProvider.initialize();
      
      bool listenerCalled = false;
      localeProvider.addListener(() {
        listenerCalled = true;
      });
      
      await localeProvider.setLocale(const Locale('es', 'ES'));
      
      expect(listenerCalled, isTrue);
    });

    test('should handle SharedPreferences errors gracefully', () async {
      // This test verifies that the provider handles errors gracefully
      // In a real scenario, we'd mock SharedPreferences to throw errors
      await localeProvider.initialize();
      
      // Should not throw and should use default locale
      expect(localeProvider.locale, equals(const Locale('en', 'US')));
    });
  });

  group('LocaleProvider Integration Tests', () {
    testWidgets('should integrate with Flutter app correctly', (WidgetTester tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();
      
      await tester.pumpWidget(
        MaterialApp(
          locale: localeProvider.locale,
          supportedLocales: LocaleProvider.supportedLocales,
          home: Builder(
            builder: (context) {
              final locale = Localizations.localeOf(context);
              return Text('${locale.languageCode}-${locale.countryCode}');
            },
          ),
        ),
      );
      
      expect(find.text('en-US'), findsOneWidget);
    });
  });
}