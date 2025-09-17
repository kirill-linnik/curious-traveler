import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _languageKey = 'language';
  
  Locale _locale = const Locale('en', 'US');
  bool _isInitialized = false;

  // Map language codes to Locale objects
  static const Map<String, Locale> _languageMap = {
    'en-US': Locale('en', 'US'),
    'es-ES': Locale('es', 'ES'),
    'fr-FR': Locale('fr', 'FR'),
    'de-DE': Locale('de', 'DE'),
    'it-IT': Locale('it', 'IT'),
    'pt-BR': Locale('pt', 'BR'),
    'zh-CN': Locale('zh', 'CN'),
    'ja-JP': Locale('ja', 'JP'),
    'ko-KR': Locale('ko', 'KR'),
    'ru-RU': Locale('ru', 'RU'),
  };

  // Reverse map for getting language code from locale
  static final Map<Locale, String> _localeToCode = {
    for (var entry in _languageMap.entries) entry.value: entry.key
  };

  // Supported locales for the app
  static List<Locale> get supportedLocales => _languageMap.values.toList();

  Locale get locale => _locale;
  bool get isInitialized => _isInitialized;

  /// Get the current language code (e.g., 'en-US')
  String get currentLanguageCode => _localeToCode[_locale] ?? 'en-US';

  /// Initialize the locale from saved preferences
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_languageKey);
      
      if (savedLanguage != null && _languageMap.containsKey(savedLanguage)) {
        _locale = _languageMap[savedLanguage]!;
      }
    } catch (e) {
      debugPrint('Error loading saved language: $e');
      // Fallback to default locale
      _locale = const Locale('en', 'US');
    }
    
    _isInitialized = true;
    notifyListeners();
  }

  /// Set the locale and save to preferences
  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    
    _locale = locale;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = _localeToCode[locale] ?? 'en-US';
      await prefs.setString(_languageKey, languageCode);
      debugPrint('Language saved: $languageCode');
    } catch (e) {
      debugPrint('Error saving language: $e');
    }
  }

  /// Set locale by language code (e.g., 'es-ES')
  Future<void> setLanguageCode(String languageCode) async {
    final locale = _languageMap[languageCode];
    if (locale != null) {
      await setLocale(locale);
    } else {
      debugPrint('Unsupported language code: $languageCode');
    }
  }

  /// Get a user-friendly display name for a language code
  static String getLanguageDisplayName(String languageCode) {
    switch (languageCode) {
      case 'en-US':
        return 'English (US)';
      case 'en-GB':
        return 'English (UK)';
      case 'es-ES':
        return 'Spanish';
      case 'fr-FR':
        return 'French';
      case 'de-DE':
        return 'German';
      case 'it-IT':
        return 'Italian';
      case 'pt-BR':
        return 'Portuguese';
      case 'zh-CN':
        return 'Chinese (Simplified)';
      case 'ja-JP':
        return 'Japanese';
      case 'ko-KR':
        return 'Korean';
      default:
        return languageCode;
    }
  }

  /// Get locale from language code, with fallback
  static Locale getLocaleFromCode(String? code) {
    return _languageMap[code] ?? const Locale('en', 'US');
  }
}