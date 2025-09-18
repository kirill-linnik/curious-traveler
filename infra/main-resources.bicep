@description('Name of the environment')
param environmentName string

@description('Primary location for all resources')
param location string = resourceGroup().location

@description('Azure Maps SKU')
@allowed(['S0', 'S1', 'G2'])
param mapsSku string = 'G2'

@description('Azure Maps deployment region')
param mapsLocation string = 'northeurope'

@description('CORS allowed origins for the API')
param allowedOrigins array = ['*']

@description('Azure OpenAI deployment region')
param openAILocation string = 'swedencentral'

@description('Azure OpenAI SKU')
@allowed(['S0'])
param openAISku string = 'S0'

@description('Whether to deploy Azure OpenAI resources (can be disabled to avoid provisioning conflicts)')
param deployOpenAI bool = true

// Generate resource token for unique names 
var resourceToken = 'curioustr'

// Common tags for all resources
var tags = {
  'azd-env-name': environmentName
}

// Storage Account for queues and tables
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'st${resourceToken}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowSharedKeyAccess: true
    supportsHttpsTrafficOnly: true
  }
  tags: tags
}

// Azure OpenAI Account (conditional deployment)
resource openAIAccount 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = if (deployOpenAI) {
  name: 'oai-sc-${resourceToken}'
  location: openAILocation
  kind: 'OpenAI'
  sku: {
    name: openAISku
  }
  properties: {
    customSubDomainName: 'oai-sc-${resourceToken}'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
  tags: tags
}

// GPT-5 Mini Deployment
resource gpt5MiniDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = if (deployOpenAI) {
  parent: openAIAccount
  name: 'gpt-5-mini'
  sku: {
    name: 'GlobalStandard'
    capacity: 50
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-5-mini'
      version: '2025-08-07'
    }
  }
}

// GPT-5 Chat Deployment (using gpt-5-chat model)
resource gpt5ChatDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = if (deployOpenAI) {
  parent: openAIAccount
  name: 'gpt-5-chat'
  sku: {
    name: 'GlobalStandard'
    capacity: 30
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-5-chat'
      version: '2025-08-07'
    }
  }
  dependsOn: [
    gpt5MiniDeployment
  ]
}

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
  location: mapsLocation  // Azure Maps has limited regional availability
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

// Log Analytics Workspace for Application Insights
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'law-${resourceToken}'
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

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
    WorkspaceResourceId: logAnalyticsWorkspace.id
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
      appSettings: union([
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Production'
        }
        {
          name: 'AzureMaps__AccountName'
          value: mapsAccount.name
        }
        {
          name: 'AzureMaps__SubscriptionKey'
          value: mapsAccount.listKeys().primaryKey
        }
        {
          name: 'ALLOWED_ORIGINS'
          value: join(allowedOrigins, ',')
        }
        // Storage configuration
        {
          name: 'Storage__ConnectionString'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'Storage__QueueName'
          value: 'itinerary-jobs'
        }
        {
          name: 'Storage__JobsTable'
          value: 'ItineraryJobs'
        }
        // Rate limiting configuration
        {
          name: 'RateLimiting__PostPerMinute'
          value: '20'
        }
        {
          name: 'RateLimiting__GetPerMinute'
          value: '60'
        }
        // Itineraries configuration
        {
          name: 'Itineraries__MaxPois'
          value: '5'
        }
        {
          name: 'Itineraries__UseIsochroneIfAvailable'
          value: 'true'
        }
        {
          name: 'Itineraries__StrictOpeningHours'
          value: 'true'
        }
        {
          name: 'Itineraries__ProcessingRetryAfterSeconds'
          value: '3'
        }
        {
          name: 'Itineraries__JobTtlHours'
          value: '24'
        }
        // Azure Maps configuration
        {
          name: 'AzureMaps__AuthMode'
          value: 'KEY'
        }
        {
          name: 'AzureMaps__AccountName'
          value: mapsAccount.name
        }
        {
          name: 'AzureMaps__TransitEnabledHint'
          value: 'true'
        }
      ], deployOpenAI ? [
        // Azure OpenAI configuration (conditional)
        {
          name: 'AzureOpenAI__Endpoint'
          value: openAIAccount!.properties.endpoint
        }
        {
          name: 'AzureOpenAI__ApiKey'
          value: openAIAccount!.listKeys().key1
        }
        {
          name: 'AzureOpenAI__Gpt5MiniDeployment'
          value: gpt5MiniDeployment!.name
        }
        {
          name: 'AzureOpenAI__Gpt5ChatDeployment'
          value: gpt5ChatDeployment!.name
        }
      ] : [])
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
output APPLICATIONINSIGHTS_CONNECTION_STRING string = applicationInsights.properties.ConnectionString
output LOG_ANALYTICS_WORKSPACE_ID string = logAnalyticsWorkspace.id
output AzureMaps__AccountName string = mapsAccount.name
output AzureMaps__ResourceId string = mapsAccount.id
output Storage__AccountName string = storageAccount.name
output AzureOpenAI__AccountName string = deployOpenAI ? openAIAccount!.name : ''
output AzureOpenAI__Endpoint string = deployOpenAI ? openAIAccount!.properties.endpoint : ''
