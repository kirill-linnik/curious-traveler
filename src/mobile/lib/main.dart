import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/itinerary_provider.dart';
import 'providers/enhanced_location_provider.dart';
import 'providers/audio_provider.dart';
import 'providers/locale_provider.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';
import 'screens/itinerary_screen.dart';
import 'screens/settings_screen.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize shared preferences
  final prefs = await SharedPreferences.getInstance();
  
  // Initialize locale provider
  final localeProvider = LocaleProvider();
  await localeProvider.initialize();
  
  runApp(CuriousTravelerApp(prefs: prefs, localeProvider: localeProvider));
}

class CuriousTravelerApp extends StatelessWidget {
  final SharedPreferences prefs;
  final LocaleProvider localeProvider;

  const CuriousTravelerApp({
    super.key, 
    required this.prefs,
    required this.localeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SharedPreferences>.value(value: prefs),
        Provider<ApiService>(
          create: (_) => ApiService(),
        ),
        ChangeNotifierProvider<LocaleProvider>.value(
          value: localeProvider,
        ),
        ChangeNotifierProvider<EnhancedLocationProvider>(
          create: (context) => EnhancedLocationProvider(context.read<ApiService>()),
        ),
        ChangeNotifierProvider<AudioProvider>(
          create: (context) => AudioProvider(),
        ),
        ChangeNotifierProvider<ItineraryProvider>(
          create: (context) => ItineraryProvider(
            context.read<ApiService>(),
            context.read<EnhancedLocationProvider>(),
          ),
        ),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, child) {
          return MaterialApp(
            title: 'Curious Traveler',
            locale: localeProvider.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: LocaleProvider.supportedLocales,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1E88E5),
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
              ),
            ),
            home: MainNavigator(key: mainNavigatorKey),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

// Global navigator key for tab switching
final GlobalKey<_MainNavigatorState> mainNavigatorKey = GlobalKey<_MainNavigatorState>();

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  _MainNavigatorState createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ItineraryScreen(),
    const SettingsScreen(),
  ];

  void switchToTab(int index) {
    if (mounted && index >= 0 && index < _screens.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.explore),
            label: localizations.tabExplore,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.map),
            label: localizations.tabItinerary,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: localizations.tabSettings,
          ),
        ],
      ),
    );
  }
}