@description('Name of the environment')
param environmentName string

@description('Primary location for all resources')
param location string = resourceGroup().location

@description('Azure Maps SKU')
@allowed(['S0', 'S1', 'G2'])
param mapsSku string = 'G2'

@description('CORS allowed origins for the API')
param allowedOrigins array = ['*']

// Generate unique suffix for resource names
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: 'plan-${resourceToken}'
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  sku: {
    name: 'B1'
    tier: 'Basic'
    size: 'B1'
    family: 'B'
    capacity: 1
  }
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: false
    maximumElasticWorkerCount: 1
    isSpot: false
    reserved: false
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
}

// Azure Maps Account
resource mapsAccount 'Microsoft.Maps/accounts@2023-06-01' = {
  name: 'maps-${resourceToken}'
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  sku: {
    name: mapsSku
  }
  kind: 'Gen2'
  properties: {
    disableLocalAuth: false  // Allow both AAD and key-based auth for Gen2
    cors: {
      corsRules: [
        {
          allowedOrigins: allowedOrigins
        }
      ]
    }
  }
}

// Azure Maps Primary Key secret removed - using AAD authentication instead

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${resourceToken}'
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    RetentionInDays: 90
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Web App
resource webApp 'Microsoft.Web/sites@2022-09-01' = {
  name: 'app-${resourceToken}'
  location: location
  tags: {
    'azd-env-name': environmentName
    'azd-service-name': 'api'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: 'v8.0'
      metadata: [
        {
          name: 'CURRENT_STACK'
          value: 'dotnet'
        }
      ]
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Production'
        }
        {
          name: 'AZURE_MAPS_ACCOUNT_NAME'
          value: mapsAccount.name
        }
        {
          name: 'AZURE_MAPS_SUBSCRIPTION_KEY'
          value: mapsAccount.listKeys().primaryKey
        }
        {
          name: 'ALLOWED_ORIGINS'
          value: join(allowedOrigins, ',')
        }
      ]
      cors: {
        allowedOrigins: allowedOrigins
        supportCredentials: false
      }
      httpLoggingEnabled: true
      logsDirectorySizeLimit: 35
      detailedErrorLoggingEnabled: true
      requestTracingEnabled: true
      requestTracingExpirationTime: '9999-12-31T23:59:00Z'
    }
  }
}

// Web App Logging Configuration
resource webAppLogs 'Microsoft.Web/sites/config@2022-09-01' = {
  parent: webApp
  name: 'logs'
  properties: {
    applicationLogs: {
      fileSystem: {
        level: 'Information'
      }
    }
    httpLogs: {
      fileSystem: {
        enabled: true
        retentionInDays: 7
        retentionInMb: 50
      }
    }
    failedRequestsTracing: {
      enabled: true
    }
    detailedErrorMessages: {
      enabled: true
    }
  }
}

// Outputs
output API_NAME string = webApp.name
output API_URI string = 'https://${webApp.properties.defaultHostName}'
// Key Vault outputs removed - no longer needed
output AZURE_APPLICATION_INSIGHTS_NAME string = applicationInsights.name
output APPLICATIONINSIGHTS_CONNECTION_STRING string = applicationInsights.properties.ConnectionString
output AZURE_MAPS_ACCOUNT_NAME string = mapsAccount.name
output AZURE_MAPS_RESOURCE_ID string = mapsAccount.id
// Removed AZURE_MAPS_AUTH_MODE output - authentication method is fixed to subscription key
