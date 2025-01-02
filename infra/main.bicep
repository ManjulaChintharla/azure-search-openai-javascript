// Define the resource group and location parameters
param location string = resourceGroup().location

// Define parameters for storage account
param storageAccountName string
param skuName string = 'Standard_LRS'

// Define parameters for Azure Function App
param functionAppName string
param hostingPlanSkuName string = 'Y1' // Consumption Plan
param runtimeStack string = 'dotnet'
param osType string = 'Windows'

// Define parameters for Application Insights
param appInsightsName string

// Define parameters for Key Vault
param keyVaultName string

// Storage account resource
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
  }
}

// App Service plan resource (Consumption Plan for Function App)
resource hostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${functionAppName}-plan'
  location: location
  sku: {
    name: hostingPlanSkuName
    tier: 'Dynamic'
  }
  kind: 'functionapp'
}

// Application Insights resource
resource appInsights 'Microsoft.Insights/components@2021-10-01' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

// Function App resource
resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storageAccount.properties.primaryEndpoints.blob
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: runtimeStack
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
      ]
    }
  }
  dependsOn: [
    storageAccount
    hostingPlan
    appInsights
  ]
}

// Key Vault resource
resource keyVault 'Microsoft.KeyVault/vaults@2022-11-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableSoftDelete: true
    accessPolicies: [] // Add access policies as needed
  }
}
