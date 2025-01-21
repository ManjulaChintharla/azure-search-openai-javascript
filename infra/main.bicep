@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param resourceGroupName string
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
param searchServiceResourceGroupName string
param searchServiceLocation string = ''
@allowed(['basic', 'standard', 'standard2', 'standard3', 'storage_optimized_l1', 'storage_optimized_l2'])
param searchServiceSkuName string
param searchIndexName string

param storageAccountName string = ''
param storageResourceGroupName string
param storageResourceGroupLocation string = location
param storageContainerName string = 'content'
param storageSkuName string

param openAiServiceName string = ''
param openAiResourceGroupName string
@description('Location for the OpenAI resource group')
@allowed(['australiaeast', 'canadaeast', 'eastus', 'eastus2', 'francecentral', 'japaneast', 'northcentralus', 'swedencentral', 'switzerlandnorth', 'uksouth', 'westeurope'])
@metadata({
  azd: {
    type: 'location'
  }
})
param openAiResourceGroupLocation string
param openAiSkuName string = 'S0'

@description('Location for the Static Web App')
@allowed(['westus2', 'centralus', 'eastus2', 'westeurope', 'eastasia', 'eastasiastage'])
@metadata({
  azd: {
    type: 'location'
  }
})
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

param backendUri string = ''

param aliasTag string = ''
param isContinuousDeployment bool = false

var abbrs = loadJsonContent('abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = union({ 'azd-env-name': environmentName }, empty(aliasTag) ? {} : { alias: aliasTag })
var allowedOrigins = empty(allowedOrigin) ? [webApp.outputs.uri] : [webApp.outputs.uri, allowedOrigin]

var indexerApiIdentityName = '${abbrs.managedIdentityUserAssignedIdentities}indexer-api-${resourceToken}'
var searchApiIdentityName = '${abbrs.managedIdentityUserAssignedIdentities}search-api-${resourceToken}'

resource openAiResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: openAiResourceGroupName
}

resource searchServiceResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: searchServiceResourceGroupName
}

resource storageResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: storageResourceGroupName
}

module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
  }
}

module containerApps './core/host/container-apps.bicep' = {
  name: 'container-apps'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: 'containerapps'
    containerAppsEnvironmentName: !empty(containerAppsEnvironmentName) ? containerAppsEnvironmentName : '${abbrs.appManagedEnvironments}${resourceToken}'
    containerRegistryName: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    containerRegistryAdminUserEnabled: true
  }
}

module webApp './core/host/staticwebapp.bicep' = {
  name: 'webapp'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: !empty(webAppName) ? webAppName : '${abbrs.webStaticSites}web-${resourceToken}'
    location: webAppLocation
    tags: union(tags, { 'azd-service-name': webAppName })
  }
}

module searchApiIdentity 'core/security/managed-identity.bicep' = {
  name: 'search-api-identity'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: searchApiIdentityName
    location: location
  }
}

module searchApi './core/host/container-app.bicep' = {
  name: 'search-api'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: !empty(searchApiName) ? searchApiName : '${abbrs.appContainerApps}search-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': searchApiName })
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    containerRegistryName: containerApps.outputs.registryName
    identityName: searchApiIdentityName
    allowedOrigins: allowedOrigins
    containerCpuCoreCount: '1.0'
    containerMemory: '2.0Gi'
    secrets: [
      {
        name: 'appinsights-cs'
        value: monitoring.outputs.applicationInsightsConnectionString
      }
    ]
    env: [
      {
        name: 'AZURE_OPENAI_CHATGPT_DEPLOYMENT'
        value: chatGptDeploymentName
      }
      {
        name: 'AZURE_OPENAI_CHATGPT_MODEL'
        value: chatGptModelName
      }
      {
        name: 'AZURE_OPENAI_EMBEDDING_DEPLOYMENT'
        value: embeddingDeploymentName
      }
      {
        name: 'AZURE_OPENAI_EMBEDDING_MODEL'
        value: embeddingModelName
      }
      {
        name: 'AZURE_OPENAI_SERVICE'
        value: openAiResourceGroupName
      }
      {
        name: 'AZURE_SEARCH_INDEX'
        value: searchIndexName
      }
      {
        name: 'AZURE_SEARCH_SERVICE'
        value: searchServiceName
      }
      {
        name: 'AZURE_STORAGE_ACCOUNT'
        value: storageAccountName
      }
      {
        name: 'AZURE_STORAGE_CONTAINER'
        value: storageContainerName
      }
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        secretRef: 'appinsights-cs'
      }
      {
        name: 'AZURE_CLIENT_ID'
        value: searchApiIdentity.outputs.clientId
      }
    ]
    imageName: !empty(searchApiImageName) ? searchApiImageName : 'nginx:latest'
    targetPort: 3000
  }
}

module indexerApiIdentity 'core/security/managed-identity.bicep' = {
  name: 'indexer-api-identity'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: indexerApiIdentityName
    location: location
  }
}

module indexerApi './core/host/container-app.bicep' = {
  name: 'indexer-api'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: !empty(indexerApiName) ? indexerApiName : '${abbrs.appContainerApps}indexer-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': indexerApiName })
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    containerRegistryName: containerApps.outputs.registryName
