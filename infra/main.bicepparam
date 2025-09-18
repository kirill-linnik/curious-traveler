using './main.bicep'

param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'dev')
param location = readEnvironmentVariable('AZURE_LOCATION', 'eastus')
param resourceGroupName = 'rg-${readEnvironmentVariable('AZURE_ENV_NAME', 'dev')}'
