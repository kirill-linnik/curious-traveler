targetScope = 'subscription'

@maxLength(64)
@description('Name of the environment')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Name of the resource group (will be made unique automatically)')
param resourceGroupName string = ''

// Generate resource group name
var uniqueResourceGroupName = empty(resourceGroupName) ? 'rg-${environmentName}' : resourceGroupName

@description('Azure Maps SKU')
@allowed(['S0', 'S1', 'G2'])
param mapsSku string = 'G2'

@description('CORS allowed origins for the API')
param allowedOrigins array = ['*']

@description('Azure OpenAI deployment region')
param openAILocation string = 'swedencentral'

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: uniqueResourceGroupName
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
    openAILocation: openAILocation
  }
}

// Outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name
output RESOURCE_GROUP_ID string = rg.id

// App Service outputs
output SERVICE_API_NAME string = mainResources.outputs.API_NAME
output SERVICE_API_URI string = mainResources.outputs.API_URI

// Application Insights outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = mainResources.outputs.APPLICATIONINSIGHTS_CONNECTION_STRING
output LOG_ANALYTICS_WORKSPACE_ID string = mainResources.outputs.LOG_ANALYTICS_WORKSPACE_ID

// Azure Maps outputs
output AzureMaps__AccountName string = mainResources.outputs.AzureMaps__AccountName
output AzureMaps__ResourceId string = mainResources.outputs.AzureMaps__ResourceId

// Storage outputs
output Storage__AccountName string = mainResources.outputs.Storage__AccountName

// Azure OpenAI outputs
output AzureOpenAI__AccountName string = mainResources.outputs.AzureOpenAI__AccountName
output AzureOpenAI__Endpoint string = mainResources.outputs.AzureOpenAI__Endpoint
