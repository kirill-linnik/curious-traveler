# AI Assistant Guide for Curious Traveler

## Project Overview
Curious Traveler is a comprehensive travel planning application with:
- **Backend**: ASP.NET Core Web API (.NET 8) providing REST APIs for itinerary generation and geolocation services
- **Mobile**: Flutter application for cross-platform mobile experience with complete multi-language support
- **Infrastructure**: Bicep templates for Azure deployment via Azure Developer CLI (azd)
- **Geospatial Services**: Azure Maps integration for location search, reverse geocoding, and map rendering

## Architecture Summary

### Technology Stack
- **Backend**: .NET 8, ASP.NET Core Web API, Azure OpenAI, Azure Maps, Azure Storage
- **Mobile**: Flutter/Dart with provider pattern for state management and internationalization
- **Infrastructure**: Azure (App Service, Application Insights, OpenAI, Storage, Azure Maps)
- **Testing**: xUnit, comprehensive unit and integration tests with mockito patterns
- **Localization**: Flutter i18n with ARB files for complete 10-language support
- **Geospatial**: Azure Maps for location services, search, and interactive map rendering

### Key Dependencies
- **Microsoft.AspNetCore.App** v8.0+ framework references
- **Microsoft.Extensions.Http** v8.0.1 for HTTP client configuration
- **Flutter**: Latest stable (3.24.0+) with Dart 3.8.0+
- **Mobile Dependencies**: Updated packages (geolocator 14.0.2, audioplayers 6.5.1, webview_flutter 4.2.2)
- All packages updated to latest versions (September 2025)

## Project Structure

```
curious-traveler/
├── azure.yaml                 # Azure Developer CLI configuration
├── src/
│   ├── api/                   # ASP.NET Core Web API (.NET 8)
│   │   ├── Controllers/       # API controllers
│   │   ├── Services/          # Business logic services
│   │   ├── Models/            # API models and DTOs
│   │   └── Program.cs         # DI container and app startup
│   └── mobile/                # Flutter application
│       ├── lib/
│       │   ├── l10n/          # Localization (ARB files)
│       │   ├── providers/     # State management (including LocaleProvider)
│       │   └── screens/       # UI screens (fully localized)
│       └── test/              # Unit, widget, and integration tests
├── tests/
│   └── api/                   # Comprehensive test suite
└── infra/                     # Bicep infrastructure templates
```

## Important Implementation Details

### Nullable Reference Types
- **Status**: Fully enabled with `<Nullable>enable</Nullable>` in both projects
- **Pattern**: Comprehensive null checking in constructors and public methods
- **API Models**: Use nullable annotations (`?`) for optional properties
- **Tests**: Use null-forgiving operator (`!`) when intentionally testing null values

### Azure OpenAI Integration
- **Current Implementation**: Uses Azure OpenAI for itinerary generation and content creation
- **Configuration**: Deployment names configured via environment variables
- **Models**: Configured for latest available chat models (GPT-4, etc.)
- **Security**: Integrated with Azure App Service configuration for secure access

### Service Layer Architecture
```csharp
// Standard service pattern with dependency injection
public interface IItineraryService
{
    Task<ItineraryResponse> GenerateItineraryAsync(ItineraryRequest request);
    Task<ItineraryResponse> UpdateItineraryAsync(ItineraryUpdateRequest request);
}
```

### API Models Guidelines
- Use `JsonPropertyName` attributes for consistent API contracts
- Avoid `required` keywords on properties that come from JSON deserialization
- Provide sensible defaults (`= string.Empty`, `= new()`)
- Use nullable types (`Location?`) for truly optional properties

### Testing Patterns
- **Unit Tests**: Mock external dependencies (Azure clients, HTTP clients)
- **Integration Tests**: Marked with `[Fact(Skip = "reason")]` for tests requiring real Azure services
- **Test Data**: Use object initializers with all required properties set
- **Validation Tests**: Test both happy path and error conditions
- **Localization Tests**: Comprehensive testing for all 10 supported languages
- **Widget Tests**: UI component testing with localization verification

## Common Operations

### Adding New API Endpoints
1. Create request/response models in `Models/ApiModels.cs`
2. Add service interface method in appropriate service interface
3. Implement business logic in service class
4. Create Azure Function in `Functions/` folder
5. Add comprehensive unit tests
6. Update this guide if new patterns emerge

### Azure Services Integration
- **Azure Maps**: Uses Azure Maps for location search, reverse geocoding, and map rendering
- **Azure Storage**: Uses queues and tables for background job processing
- **OpenAI**: Use `IItineraryService` which wraps Azure OpenAI calls
- **Configuration**: Secure authentication for Azure services via App Service settings

### Deployment
- Uses Azure Developer CLI (`azd up`) for infrastructure provisioning and deployment
- Bicep templates in `infra/` folder define Azure resources
- Environment variables configured via Azure App Settings

## Development Workflow

### Before Making Changes
1. Build both projects: `dotnet build` in `src/api` and `tests/api`
2. Run tests: `dotnet test` in `tests/api`
3. Check for warnings: Both projects should build with 0 warnings

### Code Quality Standards
- **Null Safety**: Always validate parameters in public methods
- **Error Handling**: Use structured logging with meaningful error messages
- **Testing**: Maintain test coverage for new functionality
- **Documentation**: Update XML comments for public APIs

### Recent Major Changes (September 2025)
- ✅ Updated all NuGet packages to latest versions
- ✅ Migrated from OpenAI SDK v1.0 beta to Azure.AI.OpenAI v2.1.0
- ✅ Implemented comprehensive multi-language support in Flutter app (10 languages)
- ✅ Added LocaleProvider for synchronized UI and audio language selection
- ✅ Created complete ARB files for all supported languages with full localization
- ✅ Built comprehensive test suite for localization (13/13 unit tests passing)
- ✅ Simplified English language option (removed US/UK distinction)
- ✅ Added Russian language support with complete Cyrillic translations

## Multi-Language Implementation

### Architecture
The app implements Flutter's internationalization (i18n) with synchronized interface and audio language selection:

```
User selects language in Settings
    ↓
LocaleProvider.setLanguageCode()
    ↓
Updates internal locale state + saves to SharedPreferences
    ↓ 
Notifies listeners (MaterialApp rebuilds)
    ↓
All screens show localized content + audio uses same language
```

### Key Components
- **LocaleProvider**: ChangeNotifier-based state management for locale selection
- **ARB Files**: Application Resource Bundle files in `lib/l10n/` for translations
- **AppLocalizations**: Generated Flutter class for accessing localized strings
- **Settings Integration**: Single dropdown controls both UI and audio language

### Supported Languages
- **Complete**: English, Spanish, French, German, Italian, Portuguese, Chinese (Simplified), Japanese, Korean, Russian (68+ strings each)
- **UI Support**: Full interface localization for all supported languages
- **Unified Experience**: Single language selection controls entire UI experience

### Testing Strategy
- **Unit Tests**: LocaleProvider functionality (`locale_provider_test.dart`)
- **Widget Tests**: Localized UI verification (`settings_screen_localization_test.dart`)  
- **Integration Tests**: End-to-end language switching (`multi_language_integration_test.dart`)

### Adding New Languages
1. Create `app_[locale].arb` file in `lib/l10n/`
2. Copy English template and translate all string values
3. App automatically detects and supports new language
4. No code changes required - fully declarative

### Best Practices
- **Synchronized State**: Always use LocaleProvider for language changes
- **Persistence**: Language selection saved to SharedPreferences automatically  
- **Real-time Updates**: No app restart required for language switching
- **Fallback Handling**: Graceful degradation to English for missing translations
- ✅ Migrated from Azure Functions to ASP.NET Core Web API
- ✅ Implemented comprehensive nullable reference types
- ✅ Enhanced parameter validation across all services
- ✅ Updated all Flutter dependencies to latest versions
- ✅ Resolved dependency constraints (reduced from 7 to 6 constrained packages)
- ✅ Enhanced JSON serialization with `explicitToJson: true` for nested objects
- ✅ Updated testing framework: mockito 5.5.1, build_runner 2.4.13, patrol 3.19.0
- ✅ Fixed all model tests and compilation errors
- ✅ Updated Dart SDK constraint to ≥3.8.0
- ✅ Fixed all compiler warnings and deprecation issues

## Troubleshooting Common Issues

### Build Errors
- **Required member errors**: Check if object initializers set all required properties
- **Nullable warnings**: Ensure proper null checking and nullable annotations
- **Package conflicts**: All packages recently updated and compatible

### Test Failures
- **Service mocking**: Use Moq with proper setup for async methods
- **Validation tests**: Update test expectations when adding parameter validation
- **Integration tests**: Skip tests requiring real Azure services in unit test runs
- **Flutter tests**: Use proper enum testing patterns (avoid non-existent .fromString() methods)
- **Model tests**: Ensure JSON serialization tests use `explicitToJson: true` for nested objects

### Azure Function Issues
- **DI configuration**: Check `Program.cs` for proper service registration
- **HTTP binding**: Verify route templates and authorization levels
- **JSON serialization**: Ensure models have proper JsonPropertyName attributes

### Dependency Management
- **Flutter Dependencies**: Expect 6 packages with newer versions incompatible with constraints
- **Core Constraints**: `characters`, `material_color_utilities`, `meta`, `test_api` constrained by Flutter SDK
- **Ecosystem Constraints**: `package_info_plus`, `unicode` constrained by compatibility requirements
- **Resolution**: These constraints are normal, intentional, and safe - they prevent breaking changes
- **Updates**: Use `flutter pub upgrade` after removing `pubspec.lock` for clean resolution

## Mobile App Context
The Flutter mobile app follows provider pattern:
- **State Management**: Provider pattern with dedicated providers
- **API Integration**: Calls ASP.NET Core Web API via HTTP client
- **Models**: Dart classes with JSON serialization using `json_annotation`
- **JSON Pattern**: Uses `@JsonSerializable(explicitToJson: true)` for nested objects
- **Testing**: Comprehensive test suite with mockito 5.5.1, mocktail 1.0.4, patrol 3.19.0
- **Build Generation**: Uses `build_runner 2.4.13` for code generation
- **SDK**: Dart ≥3.8.0, Flutter ≥3.24.0

## Project Completion Status

### ✅ Fully Implemented Features
- **Backend**: Complete ASP.NET Core Web API with itinerary generation and speech synthesis
- **Mobile App**: Full-featured Flutter app with cross-platform support
- **Multi-Language Support**: Complete internationalization with 10 languages
- **Infrastructure**: Production-ready Bicep templates for Azure deployment
- **Testing**: Comprehensive test coverage (unit, widget, integration)
- **CI/CD**: Azure Developer CLI (azd) deployment pipeline
- **Code Quality**: Zero warnings, modern API usage, null safety enabled

### 🎯 Production Ready
The Curious Traveler app is **production-ready** with:
- Complete feature set implemented and tested
- Full multi-language support across all UI components
- Robust error handling and fallback mechanisms
- Scalable Azure infrastructure with cost optimization
- Comprehensive documentation and deployment guides

## Future Considerations
- Consider implementing caching layer for itinerary responses
- Evaluate adding authentication/authorization
- Monitor for new Azure SDK updates and breaking changes
- Consider migrating to newer .NET versions as they become available

---

**Last Updated**: September 15, 2025  
**AI Agent Compatibility**: This guide is optimized for AI assistants working on the Curious Traveler project.