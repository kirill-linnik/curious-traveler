# Configuration Management

This document explains how the app's configuration system works and how to manage different environments.

## Overview

The app uses a centralized configuration system to manage:
- Azure App Service URLs
- API endpoints
- HTTP timeouts
- Environment-specific settings
- Feature flags
- Azure Maps integration settings

## Configuration Files

### 1. `lib/config/app_config.dart`
Main configuration file that provides constants used throughout the app:
- API endpoint paths
- Default HTTP headers
- App metadata (name, version)
- Environment-dependent values (via EnvironmentConfig)
- Azure Maps configuration

### 2. `lib/config/environment_config.dart`
Environment-specific configuration that supports:
- **Development**: Local ASP.NET Core Web API (localhost:5001)
- **Production**: Production Azure App Service

## Switching Environments

To switch between environments, change the `currentEnvironment` value in `environment_config.dart`:

```dart
// For development
static const Environment currentEnvironment = Environment.development;

// For production (current)
static const Environment currentEnvironment = Environment.production;
```

## Usage Examples

### Accessing Configuration Values

```dart
// Get Azure App Service base URL (environment-specific)
String baseUrl = AppConfig.apiBaseUrl;

// Get API endpoint
String fullUrl = '$baseUrl${AppConfig.generateItineraryEndpoint}';

// Check environment
if (AppConfig.isProduction) {
  // Production-specific logic
}

// Get timeout duration
Duration timeout = AppConfig.httpTimeout;

// Azure Maps configuration
String mapsTokenEndpoint = AppConfig.azureMapsTokenEndpoint;
```

### Adding New Configuration Values

1. Add the constant to `app_config.dart`:
```dart
static const String newApiEndpoint = '/new/endpoint';
```

2. For environment-specific values, add to `environment_config.dart`:
```dart
Environment.development: {
  'newSetting': 'dev-value',
},
Environment.production: {
  'newSetting': 'prod-value',
},
```

3. Add getter in `environment_config.dart`:
```dart
static String get newSetting => current['newSetting'] as String;
```

## Benefits

1. **No Magic Strings**: All URLs and constants are centralized
2. **Environment Management**: Easy switching between dev/production
3. **Type Safety**: Compile-time checking of configuration values
4. **Maintainability**: Single source of truth for all configuration
5. **Testing**: Easy to mock configuration values in tests
6. **Azure Integration**: Proper configuration for Azure Maps and App Services

## Best Practices

1. Never hard-code URLs or endpoints in service classes
2. Always use AppConfig constants for configuration values
3. Add environment-specific values to EnvironmentConfig when needed
4. Document any new configuration values
5. Use meaningful constant names that describe their purpose
6. Keep Azure service configuration centralized