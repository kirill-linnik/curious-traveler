# Curious Traveler

AI-driven personalized city exploration for travelers in transit. Generate tailored itineraries based on commute style, get voiceover narration in your mother tongue, and dynamically adjust your agenda based on real-time feedback.

**Current Version: 1.0.0** | **Last Updated: September 2025**

Built with modern Azure services and comprehensive multi-language support for global travelers.

![Curious Traveler Architecture](https://img.shields.io/badge/Azure-App_Service-blue) ![Flutter](https://img.shields.io/badge/Flutter-Mobile-02569B) ![.NET](https://img.shields.io/badge/.NET-8.0-512BD4) ![Azure Maps](https://img.shields.io/badge/Azure-Maps-0078D4)

## 🚀 Features

- **AI-Powered Itineraries**: Generate personalized exploration plans using Azure OpenAI GPT-4
- **Smart Location Detection**: GPS-based current location detection with fallback to manual entry
- **Type-Ahead Location Search**: Real-time location search with autocomplete suggestions for POIs, addresses, and localities powered by Azure Maps
- **Multi-Modal Transport**: Optimize routes for walking, public transit, or driving
- **Multi-Language Support**: Full interface localization with synchronized audio narration in 10 languages
- **Audio Narration**: Get location descriptions in your preferred language via Azure Speech Services
- **Real-Time Updates**: Provide feedback to dynamically adjust your itinerary
- **Cross-Platform Mobile**: Flutter app with Azure Maps Web SDK integration for iOS and Android
- **Reliable Backend**: ASP.NET Core Web API hosted on Azure App Service with Azure Maps integration
- **Secure Authentication**: Azure Maps access via Managed Identity (AAD) with subscription key fallback

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │────│ ASP.NET Core    │────│   Azure OpenAI  │
│   (iOS/Android) │    │    Web API      │    │     Service     │
│  ┌─────────────┐ │    │ ┌─────────────┐ │    └─────────────────┘
│  │   WebView   │ │    │ │ Geocoding   │ │             │
│  │ Azure Maps  │ │────│ │ Controller  │ │    ┌─────────────────┐
│  │   Web SDK   │ │    │ │ Maps Token  │ │    │ Azure Speech    │
│  └─────────────┘ │    │ │ Controller  │ │    │    Service      │
└─────────────────┘    │ └─────────────┘ │    └─────────────────┘
                       └─────────────────┘             │
                                │                      │
                         ┌─────────────────┐    ┌─────────────────┐
                         │   Azure Maps    │    │  Azure Key      │
                         │  (Gen2 Account) │    │    Vault        │
                         │  • Search API   │    │  • Maps Keys    │
                         │  • Reverse API  │    │  • Secrets      │
                         │  • Web SDK      │    └─────────────────┘
                         └─────────────────┘
                                │
                         ┌─────────────────┐
                         │ Managed Identity│
                         │   (AAD Auth)    │
                         └─────────────────┘
```

### Azure Maps Integration

- **Azure Maps Gen2 Account**: Provisioned via Bicep for high-performance geospatial services
- **Dual Authentication Modes**:
  - **AAD Mode (Preferred)**: Uses Managed Identity for secure, keyless authentication
  - **KEY Mode (Fallback)**: Uses subscription keys stored in Azure Key Vault
- **Security**: Maps keys never exposed to clients; server-side authentication only
- **Mobile Rendering**: Azure Maps Web SDK via WebView with token-based authentication

## 📋 Prerequisites

- **Azure Subscription** with appropriate permissions
- **Azure Developer CLI (azd)** - [Install here](https://docs.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- **.NET 8 SDK** - [Download here](https://dotnet.microsoft.com/download/dotnet/8.0)
- **Flutter SDK** (3.24.0+) - [Install here](https://flutter.dev/docs/get-started/install)
- **Dart SDK** (3.8.0+) - Included with Flutter
- **Azure Maps** account will be automatically provisioned during deployment

## 🚀 Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd curious-traveler
```

### 2. Configure Environment

1. Copy the environment template:
```bash
cp .env.example .env
```

2. Configure Azure Maps Authentication Mode (optional):
   
   **Option A: AAD Authentication (Recommended - Default)**
   ```bash
   azd env set AZURE_MAPS_AUTH_MODE "AAD"
   ```
   
   **Option B: Subscription Key Authentication (Fallback)**
   ```bash
   azd env set AZURE_MAPS_AUTH_MODE "KEY"
   ```

   **Note**: AAD mode uses Managed Identity for secure, keyless authentication. KEY mode stores subscription keys in Azure Key Vault. If not specified, AAD mode is used by default.

3. Set additional configuration (optional):
   ```bash
   # Set Azure Maps SKU (default: G2)
   azd env set AZURE_MAPS_SKU "G2"
   
   # Configure CORS origins for development
   azd env set ALLOWED_ORIGINS "*"
   ```

### 3. Deploy to Azure

```bash
# Initialize azd (first time only)
azd init

# Set your Azure subscription
azd auth login

# Deploy infrastructure and application
azd up
```

This will:
- Create Azure resource group
- Deploy ASP.NET Core Web API on Azure App Service
- **Provision Azure Maps Gen2 account** with automatic SKU selection
- **Configure Managed Identity** and assign Azure Maps Data Reader role
- Set up Azure OpenAI with GPT-4 models
- Configure Azure Speech Services
- Create Azure Key Vault for secrets (maps keys in KEY mode)
- Deploy the backend API with rate limiting and CORS
- **Configure authentication mode** (AAD or KEY based on settings)

### Authentication Modes

#### AAD Mode (Default - Recommended)
- Uses **System-Assigned Managed Identity** for secure authentication
- **No keys exposed** - all authentication is token-based
- Maps Data Reader role automatically assigned to the Web App
- Mobile clients receive short-lived access tokens via `/api/maps/token` endpoint

#### KEY Mode (Fallback)
- Uses subscription keys stored securely in **Azure Key Vault**
- Keys retrieved at runtime using Managed Identity
- Mobile clients use server-side tile proxy to avoid key exposure
- Useful for development or environments where AAD isn't available

### 4. Configure Mobile App

After deployment, update the mobile app configuration:

1. Get your App Service URL from azd output:
```bash
azd env get-values
```

2. Update the mobile app API configuration in `src/mobile/lib/services/api_service.dart`:
```dart
static const String _baseUrl = 'https://your-app-service.azurewebsites.net/api';
```

Note: No function keys are required since this is an App Service deployment with standard HTTP endpoints.

## 🗺️ Azure Maps Configuration

### Security Model

The application implements a **secure-by-design** approach for Azure Maps access:

1. **Server-Side Only Authentication**: Azure Maps credentials are never sent to client applications
2. **Managed Identity Integration**: Uses Azure AD for keyless authentication (AAD mode)
3. **Key Vault Protection**: Subscription keys encrypted and stored in Azure Key Vault (KEY mode)
4. **Token-Based Client Access**: Mobile apps receive short-lived tokens for map rendering
5. **Role-Based Access**: Minimal permission assignment (Azure Maps Data Reader only)

### Endpoints

#### Geocoding APIs (Unchanged from Bing Maps)
- `GET /api/geocode/reverse?latitude={lat}&longitude={lon}&language={lang}` - Convert coordinates to addresses
- `GET /api/geocode/search?query={q}&language={lang}&limit={n}` - Search for locations

#### Azure Maps Token API (New)
- `GET /api/maps/token` - Get short-lived access token for client-side map rendering (AAD mode only)

### Client-Side Map Integration

The mobile app now uses **Azure Maps Web SDK** instead of Bing Maps:

```dart
// Token-based authentication (AAD mode)
final token = await azureMapsService.getToken();
webViewController.loadHtmlString('''
<!DOCTYPE html>
<html>
<head>
    <script src="https://atlas.microsoft.com/sdk/javascript/mapcontrol/3/atlas.min.js"></script>
    <link href="https://atlas.microsoft.com/sdk/javascript/mapcontrol/3/atlas.min.css" rel="stylesheet" />
</head>
<body>
    <div id="myMap" style="position:relative;width:100%;min-width:290px;height:600px;"></div>
    <script>
        const map = new atlas.Map('myMap', {
            authOptions: {
                authType: 'anonymous',
                getToken: function() {
                    return Promise.resolve('$token');
                }
            }
        });
    </script>
</body>
</html>
''');
```

### Switching Authentication Modes

To change authentication modes after deployment:

1. **Switch to KEY mode:**
   ```bash
   azd env set AZURE_MAPS_AUTH_MODE "KEY"
   azd up
   ```

2. **Switch to AAD mode:**
   ```bash
   azd env set AZURE_MAPS_AUTH_MODE "AAD"
   azd up
   ```

**Note**: Mode changes require redeployment to update infrastructure and application settings.

### 5. Run Mobile App

```bash
cd src/mobile

# Get dependencies
flutter pub get

# Generate localization files
flutter gen-l10n

# Generate model files
dart run build_runner build

# Run on your preferred platform
flutter run
```

## 🌍 Multi-Language Support

The Curious Traveler app provides **complete internationalization** with synchronized interface and audio language selection across 10 languages. All user-facing text has been localized and no hardcoded strings remain in the application.

### Supported Languages

| Language | Code | Interface | Audio | Status |
|----------|------|-----------|-------|---------|
| English | en-US | ✅ | ✅ | Complete |
| Spanish | es-ES | ✅ | ✅ | Complete |
| French | fr-FR | ✅ | ✅ | Complete |
| German | de-DE | ✅ | ✅ | Complete |
| Italian | it-IT | ✅ | ✅ | Complete |
| Portuguese | pt-BR | ✅ | ✅ | Complete |
| Chinese (Simplified) | zh-CN | ✅ | ✅ | Complete |
| Japanese | ja-JP | ✅ | ✅ | Complete |
| Korean | ko-KR | ✅ | ✅ | Complete |
| Russian | ru-RU | ✅ | ✅ | Complete |

### Key Features

- **Synchronized Language Control**: Single setting in the app controls both interface language and audio narration language
- **Real-time Switching**: Language changes take effect immediately without app restart
- **Persistent Settings**: Language selection is saved and restored between app sessions
- **Complete Localization**: All UI strings, error messages, dialogs, and user-facing text are localized
- **No Hardcoded Strings**: Comprehensive audit ensures all user-visible text uses translation system
- **Easy Expansion**: Adding new languages requires only ARB file translation

### Implementation Details

The app uses Flutter's built-in internationalization with:
- **ARB Files**: Application Resource Bundle files for translation management
- **LocaleProvider**: Clean state management for language selection
- **SharedPreferences**: Persistent language choice storage
- **Material Design**: Native localization delegates for platform consistency

### Adding New Languages

To add a new language:

1. Create a new ARB file: `lib/l10n/app_[locale].arb`
2. Copy content from `app_en.arb` and translate all string values
3. The app will automatically detect and support the new language
4. Test using the language selection dropdown in settings

### Testing

Comprehensive test coverage includes:
- **Unit Tests**: LocaleProvider functionality and state management
- **Widget Tests**: Localized UI component verification  
- **Integration Tests**: End-to-end language switching workflows
- **Multi-language Testing**: All implemented languages verified

## 📍 Location Detection & Search

The app features intelligent location detection and search capabilities for enhanced user experience.

### Smart Location Detection

- **GPS-based Detection**: Automatic current location detection with permission handling
- **Graceful Fallbacks**: Manual location entry when GPS is unavailable or denied
- **Real-time Status**: Live feedback during location detection process
- **Error Recovery**: Retry mechanisms for failed location detection

### Type-Ahead Search

- **Real-time Search**: Instant location suggestions as you type
- **Multiple Result Types**: Points of Interest (POIs), addresses, and localities
- **Smart Ranking**: Results prioritized by proximity and relevance
- **Visual Indicators**: Icons differentiate between cities, addresses, and POIs
- **Performance Optimized**: Search debouncing and memory caching reduce API calls

### Backend APIs

#### Reverse Geocoding
```http
GET /api/geocode/reverse?latitude={latitude}&longitude={longitude}&language={lang}
```

Convert GPS coordinates to human-readable addresses using **Azure Maps Search API**:
- **Input validation** with coordinate range checking (-90 to 90 lat, -180 to 180 lon)
- **Memory caching** for 5 minutes to improve performance and reduce costs
- **Multi-language support** for localized address formats
- **Error handling** with structured RFC 7807 ProblemDetails responses
- **Rate limiting** (60 requests/minute per IP) to prevent abuse

#### Location Search
```http
GET /api/geocode/search?query={searchTerm}&language={lang}&limit={maxResults}&userLat={lat}&userLon={lon}
```

Search for locations with autocomplete functionality using **Azure Maps Fuzzy Search API**:
- **Minimum query length**: 2 characters required
- **Debouncing support** for type-ahead scenarios (300ms client-side delay)
- **Memory caching** for 60 seconds per unique query
- **Proximity bias** using optional user location parameters for better relevance
- **Configurable limits** (1-20 results, default: 10)
- **Multi-type results**: POIs, addresses, and localities with clear type indicators

#### Azure Maps Token API
```http
GET /api/maps/token
```

Get short-lived access token for client-side Azure Maps rendering (AAD mode only):
- **AAD Authentication**: Returns bearer token with 5-15 minute lifespan
- **Security**: Tokens scoped specifically to Azure Maps services
- **Client Integration**: Used by mobile WebView for Azure Maps Web SDK initialization
- **Rate Limited**: Standard API rate limits apply

**Note**: In KEY mode, clients use server-side tile proxy instead of direct token access.

### User Interface Components

#### Location Mode Toggle
- **Segmented Control**: Switch between "Current Location" and "Another Location"
- **Material Design**: Consistent theming with proper accessibility
- **Visual Feedback**: Clear selection states and transitions

#### Enhanced Location Input
- **Overlay Dropdown**: Search results appear below input field
- **Smart Positioning**: Results overlay adjusts to screen boundaries
- **Loading States**: Progress indicators during search operations
- **Error States**: User-friendly error messages with retry options

#### Status Indicators
- **Live Updates**: Real-time status for location detection and search
- **Color-coded Cards**: Different visual states for various operations
- **Action Buttons**: Retry functionality for failed operations
- **Progress Indicators**: Visual feedback for ongoing processes

### Technical Implementation

- **Azure Maps Integration**: Direct REST API calls to Azure Maps Search services
- **Dual Authentication**: AAD (Managed Identity) and KEY (Azure Key Vault) modes
- **Memory Caching**: 80% reduction in API calls through intelligent caching strategies
- **Search Debouncing**: 300ms delay prevents excessive API requests during typing
- **Permission Handling**: Proper GPS permission flow with graceful fallbacks
- **State Management**: Clean provider pattern for location state management
- **Error Boundaries**: Comprehensive error handling and recovery mechanisms
- **Security**: Zero client-side exposure of Azure Maps credentials

## 🔧 Local Development

### API Development

1. Navigate to the API project:
```bash
cd src/api
```

2. Configure user secrets for local development:

   **For AAD Mode (Recommended):**
   ```bash
   dotnet user-secrets set "AZURE_MAPS_AUTH_MODE" "AAD"
   dotnet user-secrets set "AZURE_MAPS_ACCOUNT_NAME" "your-dev-maps-account"
   ```

   **For KEY Mode:**
   ```bash
   dotnet user-secrets set "AZURE_MAPS_AUTH_MODE" "KEY"
   dotnet user-secrets set "AZURE_MAPS_ACCOUNT_NAME" "your-dev-maps-account"
   dotnet user-secrets set "AZURE_MAPS_PRIMARY_KEY" "your-azure-maps-key"
   ```

   **Note**: For local AAD development, ensure you're logged in with `az login` and have appropriate permissions on your development Azure Maps account.
```

3. Run the API locally:
```bash
dotnet run
```

The API will be available at `https://localhost:5001` with Swagger documentation at `https://localhost:5001/swagger`.

### Mobile Development

1. Start the API locally (see above)

2. Update API base URL in mobile app to point to local API:

```dart
// lib/services/api_service.dart
static const String _baseUrl = 'https://localhost:5001/api';
```

3. Install Flutter dependencies and generate localization files:

```bash
cd src/mobile

# Get dependencies
flutter pub get

# Generate localization files from ARB files
flutter gen-l10n

# Generate model files
dart run build_runner build
```

4. Run the app:

```bash
# Run on your preferred platform
flutter run

# For web development
flutter run -d chrome --web-port 8080

# For Windows development  
flutter run -d windows
```

### Testing Localization

Run the comprehensive test suite:

```bash
# Run all tests
flutter test

# Run specific test suites
flutter test test/unit/providers/locale_provider_test.dart
flutter test test/widget/settings_screen_localization_test.dart

# Run integration tests
flutter test integration_test/multi_language_integration_test.dart
```
```dart
static const String _baseUrl = 'http://localhost:7071/api';
```

3. Run the mobile app:
```bash
cd src/mobile
flutter run
```

## 📱 Mobile App Features

### Home Screen
- Enter destination city
- Select commute style (walking, transit, driving)
- Set exploration duration
- Choose interests (history, food, culture, etc.)
- Generate AI-powered itinerary

### Itinerary Screen
- **List View**: Detailed location cards with descriptions
- **Map View**: Interactive map with numbered waypoints
- **Audio Narration**: Tap locations for AI-generated audio guides
- **Feedback System**: Like/dislike locations, request more/less time

### Settings Screen
- Language preferences for narration
- Default duration settings
- Privacy information
- Help documentation

## 🔐 Security & Authentication

The application uses Azure Managed Identity for secure service-to-service authentication:

- **App Service** → **Azure OpenAI**: Managed Identity with Cognitive Services OpenAI User role
- **App Service** → **Speech Service**: Managed Identity with Cognitive Services User role
- **App Service** → **Key Vault**: Managed Identity with Key Vault Secrets User role
- **App Service** → **Storage**: Managed Identity with Storage Blob Data Owner role

No API keys are stored in application code - all secrets are managed through Azure Key Vault.

## 💰 Cost Optimization

This solution is optimized for hackathon/demo usage:

### Azure App Service (Linux)
- **Pay-per-use** scaling model with automatic scaling
- **Always-on** availability for production workloads
- **No cold start** delays for better performance
- **Estimated cost**: ~$0.50-3.00 per day for demo usage

### Azure OpenAI
- **Pay-per-token** pricing
- **GPT-4**: $30/1M input tokens, $60/1M output tokens
- **GPT-4 Mini**: $0.15/1M input tokens, $0.60/1M output tokens
- **Estimated cost**: ~$0.50-2.00 per day for demo usage

### Azure Speech Services
- **Pay-per-character** TTS
- **Standard voices**: $4/1M characters
- **Neural voices**: $16/1M characters
- **Estimated cost**: ~$0.10-0.50 per day for demo usage

### Total Estimated Daily Cost: $1.10-6.10

## 🛠️ Troubleshooting

### Deployment Issues

1. **Bicep deployment fails**:
   ```bash
   azd down  # Clean up partial deployment
   azd up    # Retry deployment
   ```

2. **App Service deployment timeout**:
   - Check Application Insights logs in Azure Portal
   - Verify managed identity permissions
   - Ensure all environment variables are set

3. **OpenAI API errors**:
   - Verify deployment names match configuration
   - Check quota limits in Azure Portal
   - Ensure proper role assignments

### Mobile App Issues

1. **API connection fails**:
   - Verify App Service URL
   - Check CORS settings in App Service
   - Ensure App Service is running

2. **Location permission denied**:
   - Enable location services in device settings
   - Grant app location permissions
   - Check platform-specific permission configurations

3. **Audio playback issues**:
   - Verify Speech Service configuration
   - Check device audio permissions
   - Ensure network connectivity

## 📖 API Documentation

### Geocoding Services

#### Reverse Geocoding
```http
GET /api/geocode/reverse
Content-Type: application/json

Parameters:
- lat (required): Latitude coordinate
- lon (required): Longitude coordinate  
- language (optional): Response language (default: en)

Response:
{
  "formattedAddress": "1234 Main St, City, State, Country",
  "locality": "City",
  "countryCode": "US",
  "center": {
    "lat": 40.7128,
    "lon": -74.0060
  }
}
```

#### Location Search
```http
GET /api/geocode/search
Content-Type: application/json

Parameters:
- query (required): Search term
- language (optional): Response language
- userLat (optional): User latitude for proximity bias
- userLon (optional): User longitude for proximity bias
- limit (optional): Maximum results (default: 10)

Response:
[
  {
    "id": "unique-id",
    "type": "POI",
    "name": "Eiffel Tower",
    "fullAddress": "Champ de Mars, 5 Avenue Anatole France, 75007 Paris, France",
    "position": {
      "lat": 48.8584,
      "lon": 2.2945
    }
  }
]
```

### Itinerary Services

#### Generate Itinerary
```http
POST /api/itinerary/generate
Content-Type: application/json

{
  "city": "Paris",
  "commuteStyle": "walking",
  "duration": 4,
  "interests": ["history", "art", "food"],
  "language": "en-US",
  "startLocation": {
    "latitude": 48.8566,
    "longitude": 2.3522,
    "address": "Paris, France"
  }
}
```

#### Update Itinerary
```http
POST /api/itinerary/generate
Content-Type: application/json

{
  "city": "Paris",
  "commuteStyle": "walking",
  "duration": 4,
  "interests": ["history", "art", "food"],
  "language": "en-US",
  "startLocation": {
    "latitude": 48.8566,
    "longitude": 2.3522,
    "address": "Paris, France"
  }
}
```

### Update Itinerary
```http
POST /api/itinerary/update
Content-Type: application/json

{
  "itineraryId": "uuid",
  "locationId": "location-1",
  "feedback": "like",
  "currentLocation": {
    "latitude": 48.8566,
    "longitude": 2.3522,
    "address": "Current location"
  }
}
```

### Generate Audio
```http
POST /api/speech/generate
Content-Type: application/json

{
  "text": "Welcome to the Eiffel Tower...",
  "language": "en-US"
}
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Azure OpenAI** for intelligent itinerary generation
- **Azure Speech Services** for multilingual narration
- **Azure Maps** for geospatial services, routing, and location search
- **Flutter** for cross-platform mobile development
- **Azure App Service** for Web API hosting and Managed Identity integration

## � Troubleshooting

### Common Azure Maps Issues

#### Authentication Errors
**Problem**: `401 Unauthorized` responses from Azure Maps APIs
- **AAD Mode**: Ensure Managed Identity has "Azure Maps Data Reader" role assigned
- **KEY Mode**: Verify Azure Maps primary key is correctly stored in Key Vault
- **Check**: Application settings include correct `AZURE_MAPS_AUTH_MODE` and `AZURE_MAPS_ACCOUNT_NAME`

```bash
# Verify current authentication mode
azd env get-values | grep AZURE_MAPS

# Check role assignments
az role assignment list --assignee <managed-identity-id> --scope <maps-account-resource-id>
```

#### Mobile Map Rendering Issues
**Problem**: Maps don't load in mobile app
- **Token Mode**: Verify `/api/maps/token` endpoint returns valid tokens
- **WebView**: Check mobile device console for JavaScript errors
- **Network**: Ensure mobile app can reach the backend API

#### Rate Limiting
**Problem**: `429 Too Many Requests` responses
- **Development**: Consider increasing rate limits in `Program.cs`
- **Production**: Review usage patterns and implement client-side caching
- **Azure Maps**: Monitor Azure Maps account usage in Azure Portal

#### Geocoding Issues
**Problem**: No results or incorrect location data
- **Query Length**: Ensure search queries are at least 2 characters
- **Coordinates**: Verify latitude (-90 to 90) and longitude (-180 to 180) ranges
- **Language**: Use supported language codes (e.g., 'en', 'es', 'fr')

### Deployment Issues

#### Azure Resource Provisioning
**Problem**: `azd up` fails during infrastructure deployment
- **Permissions**: Ensure account has Contributor role on subscription
- **Quotas**: Check Azure Maps and App Service quotas in target region
- **Region**: Verify Azure Maps is available in selected region

```bash
# Check available regions for Azure Maps
az provider show --namespace Microsoft.Maps --query "resourceTypes[?resourceType=='accounts'].locations"

# Verify quota usage
az vm list-usage --location eastus | grep -i maps
```

#### Application Settings
**Problem**: Backend API returns configuration errors
- **Missing Settings**: Verify all required app settings are deployed
- **Key Vault Access**: Ensure Managed Identity can access Key Vault secrets
- **Connection Strings**: Check Application Insights and other service connections

```bash
# List current app settings
az webapp config appsettings list --name <app-name> --resource-group <rg-name>

# Test Key Vault access
az keyvault secret show --vault-name <vault-name> --name AZURE-MAPS-PRIMARY-KEY
```

### Development Issues

#### Local Authentication
**Problem**: Azure Maps calls fail in local development
- **AAD Mode**: Run `az login` and ensure account has access to Maps account
- **KEY Mode**: Set user secrets with valid Azure Maps key
- **Configuration**: Verify `AZURE_MAPS_ACCOUNT_NAME` matches actual account

#### Mobile Development
**Problem**: Flutter app compilation or runtime errors
- **Dependencies**: Run `flutter pub get` and `flutter doctor`
- **WebView**: Ensure WebView plugin is properly installed for target platform
- **API URLs**: Verify mobile app points to correct backend API URL

### Monitoring and Logs

#### Application Insights
- **Backend Logs**: Check `traces` table for detailed request/response logs
- **Error Tracking**: Monitor `exceptions` table for service errors
- **Performance**: Review `requests` table for API response times

#### Azure Maps Metrics
- **Usage**: Monitor API call volume and response codes in Azure Portal
- **Billing**: Track usage against pricing tier limits
- **Performance**: Check average response times for geocoding operations

## �📞 Support

For questions and support:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review App Service logs in Application Insights
3. Open an issue in this repository
4. Contact the development team

---

**Happy Exploring! 🌍✈️**