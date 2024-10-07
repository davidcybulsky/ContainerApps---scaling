param projectName string

param location string = resourceGroup().location

param szachmatyIdentity string

param szachmatyIdentityResourceGroup string

param keyVaultName string 

param postgresAdminLogin string

param vnetAddressPrefixes array

param defaultSubnetAddressPrefix string

param databaseSubnetAddressPrefix string

param cacheSubnetAddressPrefix string

param containersSubnetAddressPrefix string

param containerRegistryName string


resource kv 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: keyVaultName
  scope: resourceGroup('keyVaults')
}

module networking 'modules/networking.bicep' = {
  name: 'networking'
  params: {
    projectName: projectName
    location: location
    vnetAddressPrefixes: vnetAddressPrefixes
    defaultSubnetAddressPrefix: defaultSubnetAddressPrefix
    databaseSubnetAddressPrefix: databaseSubnetAddressPrefix
    cacheSubnetAddressPrefix: cacheSubnetAddressPrefix
    containerSubnetAddressPrefix: containersSubnetAddressPrefix
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    projectName: projectName
    location: location
    postgresAdminLogin: postgresAdminLogin
    postgresAdminPassword: kv.getSecret('postgresAdminPassword')
    databaseSubnetId: networking.outputs.databaseSubnetId
    cacheSubnetId: networking.outputs.cacheSubnetId
    privateDNSZoneId: networking.outputs.privateDNSZoneId
    cachePrivateDnsZoneId: networking.outputs.cacheDnsZoneId
  }
}

module computing 'modules/computing.bicep' = {
  name: 'computing'
  params: {
    projectName: projectName
    location: location
    szachmatyIdentity: szachmatyIdentity
    szachmatyIdentityResourceGroup: szachmatyIdentityResourceGroup
    cacheEndpoint: networking.outputs.cacheDnsZoneName
    postresServerEndpoint: networking.outputs.privateDNSZoneName 
    postgresAdminLogin: postgresAdminLogin
    postgresAdminPassword: kv.getSecret('postgresAdminPassword')
    chatServiceDbName: storage.outputs.chatServiceDbName
    userDataServiceDbName: storage.outputs.userDataServiceDbName
    jwtKey: kv.getSecret('jwtKey')
    cacheForRedisName: storage.outputs.cacheForRedisName
    containerRegistryName: containerRegistryName
    containerEnvironmentSubnetId: networking.outputs.containersSubnetId
  }
}
