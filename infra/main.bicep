targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Name of the existing resource group')
@minLength(1)
param resourceGroupName string

@description('Specify additional parameters as required.')
param containerAppsEnvironmentName string = ''
param containerRegistryName string = ''
param webAppName string = 'webapp'
param searchApiName string = 'search'
param searchApiImageName string = ''
param indexerApiName string = 'indexer'
param indexerApiImageName string = ''

param logAnalyticsName string = ''
param applicationInsightsName string = ''
param applicationInsightsDashboardName string = ''

param searchServiceName string = ''
param searchServiceLocation string = ''
@allowed(['basic', 'standard', 'standard2', 'standard3', 'storage_optimized_l1', 'storage_optimized_l2'])
param searchServiceSkuName string
param searchIndexName string

param storageAccountName string = ''
param storageContainerName string = 'content'
param storageSkuName string

param openAiServiceName string = ''
@description('Location for the OpenAI resource group')
@allowed(['australiaeast', 'canadaeast', 'eastus', 'eastus2', 'francecentral', 'japaneast', 'northcentralus', 'swedencentral', 'switzerlandnorth', 'uksouth', 'westeurope'])
param openAiResourceGroupLocation string
param openAiSkuName string = 'S0'

@description('Location for the Static Web App')
@allowed(['westus2', 'centralus', 'eastus2', 'westeurope', 'eastasia', 'eastasiastage'])
param webAppLocation string

param chatGptDeploymentName string
param chatGptDeploymentCapacity int = 30
param chatGptModelName string
param chatGptModelVersion string
param embeddingDeploymentName string = 'embedding'
param embeddingDeploymentCapacity int = 30
param embeddingModelName string = 'text-embedding-ada-002'

@description('Id of the user or app to assign application roles')
param principalId string = ''

param allowedOrigin string

// Allow overriding the default backend
param backendUri string = ''

// Differentiates between automated and manual deployments
param isContinuousDeployment bool = false

var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: resourceGroupName
}

module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    logAnalyticsName: logAnalyticsName
    applicationInsightsName: applicationInsightsName
    applicationInsightsDashboardName: applicationInsightsDashboardName
  }
}

// Add modules and resources as needed, using the existing `resourceGroup` for their scope
