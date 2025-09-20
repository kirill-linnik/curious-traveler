# Curious Traveler Mobile App

A Flutter-based mobile application for AI-driven personalized city exploration. Built with modern Flutter practices and complete internationalization support.

## 🚀 Features

- **AI-Powered Itineraries**: Generate personalized travel plans using Azure OpenAI
- **Smart Location Detection**: GPS-based location detection with graceful fallbacks
- **Type-Ahead Search**: Real-time location search with Azure Maps integration
- **Multi-Language Support**: Complete localization for 10 languages
- **Interactive Maps**: Azure Maps Web SDK integration via WebView
- **Cross-Platform**: Native iOS and Android support

## 🏗️ Architecture

### State Management
- **Provider Pattern**: Clean separation of state management and UI
- **LocaleProvider**: Centralized language selection and persistence
- **LocationProvider**: GPS and location search state management
- **ItineraryProvider**: Travel plan state management

### Key Components
- **Location Search**: Type-ahead search with overlay dropdown
- **Azure Maps Widget**: Interactive map rendering with WebView
- **Interest Selector**: Multi-selection UI for travel preferences
- **Language Selector**: Dynamic language switching

### Services
- **ApiService**: HTTP client for backend API communication
- **AzureMapsService**: Token management and map authentication
- **LocationService**: GPS detection and permission handling

## 📱 Requirements

- **Flutter**: 3.24.0 or higher
- **Dart**: 3.8.0 or higher
- **iOS**: 12.0+ (for iOS builds)
- **Android**: API level 21+ (Android 5.0)

## 🛠️ Development Setup

### 1. Prerequisites

Ensure you have Flutter installed:
```bash
flutter doctor
```

### 2. Get Dependencies

```bash
flutter pub get
```

### 3. Generate Localization Files

```bash
flutter gen-l10n
```

### 4. Generate Model Files

```bash
dart run build_runner build
```

### 5. Configure API Endpoint

Update the API base URL in `lib/services/api_service.dart`:
```dart
static const String _baseUrl = 'https://your-api-endpoint.azurewebsites.net/api';
```

### 6. Run the App

```bash
# Run on connected device/simulator
flutter run

# Run with specific flavor
flutter run --flavor development
flutter run --flavor production
```

## 🌍 Internationalization

The app provides complete localization support for 10 languages:

### Supported Languages
- English (en-US)
- Spanish (es-ES)
- French (fr-FR)
- German (de-DE)
- Italian (it-IT)
- Portuguese (pt-BR)
- Chinese Simplified (zh-CN)
- Japanese (ja-JP)
- Korean (ko-KR)
- Russian (ru-RU)

### Implementation
- **ARB Files**: All translations stored in `lib/l10n/app_*.arb`
- **Generated Code**: Flutter automatically generates `AppLocalizations` class
- **No Hardcoded Strings**: All user-facing text uses the localization system

### Adding New Languages

1. Create new ARB file: `lib/l10n/app_[locale].arb`
2. Copy structure from `app_en.arb` and translate values
3. Run `flutter gen-l10n` to generate code
4. Test the new language in the app

## 🧪 Testing

### Test Structure
```
test/
├── helpers/           # Shared test utilities
├── unit/             # Unit tests for models, services, providers
├── widget/           # Widget tests for UI components
└── integration/      # End-to-end integration tests
```

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/unit/providers/locale_provider_test.dart

# Run with coverage
flutter test --coverage

# Run widget tests only
flutter test test/widget/

# Run integration tests
flutter test test/integration/
```

### Test Utilities
- **MockApiService**: Shared mock for API interactions
- **TestDataFactory**: Generate test data objects
- **TestableProviders**: Testable versions of state providers

## 📦 Key Dependencies

### Core Dependencies
- `flutter`: Flutter SDK
- `flutter_localizations`: Internationalization support
- `provider`: State management
- `shared_preferences`: Persistent storage

### Location & Maps
- `geolocator`: GPS location detection
- `permission_handler`: Location permissions
- `webview_flutter`: Azure Maps Web SDK integration

### UI & Media
- `url_launcher`: External URL handling

### Networking
- `http`: API communication
- `json_annotation`: JSON serialization

### Development
- `build_runner`: Code generation
- `json_serializable`: Model generation
- `mockito`: Test mocking
- `flutter_test`: Testing framework

## 🔧 Configuration

### Environment Configuration
The app supports multiple environments via `lib/config/`:
- `app_config.dart`: Global app configuration
- `environment_config.dart`: Environment-specific settings

### API Configuration
Update API endpoints in `lib/services/api_service.dart` based on deployment:
- **Development**: Local ASP.NET Core API (localhost:5001)
- **Production**: Azure App Service endpoint

## 🚀 Building for Release

### Android Release
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS Release
```bash
flutter build ios --release
```

## 📁 Project Structure

```
lib/
├── config/           # App configuration and environment setup
├── l10n/            # Localization ARB files
├── models/          # Data models with JSON serialization
├── providers/       # State management providers
├── screens/         # UI screens and navigation
├── services/        # Business logic and API services
├── widgets/         # Reusable UI components
└── main.dart        # App entry point
```

## 🐛 Troubleshooting

### Common Issues

**Localization not working:**
```bash
flutter gen-l10n
flutter pub get
```

**Build errors after dependencies:**
```bash
flutter clean
flutter pub get
dart run build_runner build
```

**iOS build issues:**
```bash
cd ios
pod install
cd ..
flutter clean
flutter run
```

### Debug Information
- Use `flutter doctor` to verify setup
- Check `flutter logs` for runtime errors
- Use Flutter Inspector for UI debugging
