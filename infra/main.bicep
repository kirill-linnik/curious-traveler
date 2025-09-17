targetScope = 'subscription'

@maxLength(64)
@description('Name of the environment')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Azure Maps SKU')
@allowed(['S0', 'S1', 'G2'])
param mapsSku string = 'G2'

@description('CORS allowed origins for the API')
param allowedOrigins array = ['*']

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: {
    'azd-env-name': environmentName
  }
}

// Deploy main resources
module mainResources 'main-resources.bicep' = {
  name: 'main-resources'
  scope: rg
  params: {
    environmentName: environmentName
    location: location
    mapsSku: mapsSku
    allowedOrigins: allowedOrigins
  }
}

// Outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name

// App Service outputs
output SERVICE_API_NAME string = mainResources.outputs.API_NAME
output SERVICE_API_URI string = mainResources.outputs.API_URI

// Key Vault outputs removed - no longer needed

// Application Insights outputs
output AZURE_APPLICATION_INSIGHTS_NAME string = mainResources.outputs.AZURE_APPLICATION_INSIGHTS_NAME
output APPLICATIONINSIGHTS_CONNECTION_STRING string = mainResources.outputs.APPLICATIONINSIGHTS_CONNECTION_STRING

// Azure Maps outputs
output AZURE_MAPS_ACCOUNT_NAME string = mainResources.outputs.AZURE_MAPS_ACCOUNT_NAME
output AZURE_MAPS_RESOURCE_ID string = mainResources.outputs.AZURE_MAPS_RESOURCE_ID
// Removed AZURE_MAPS_AUTH_MODE output - authentication method is fixed to subscription key
