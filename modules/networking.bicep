param location string

param projectName string

param vnetAddressPrefixes array

param defaultSubnetAddressPrefix string

param databaseSubnetAddressPrefix string

param cacheSubnetAddressPrefix string

param containerSubnetAddressPrefix string


var vnetName = 'vnet-${projectName}'
var privateDNSZoneName = '${projectName}.postgres.database.azure.com'
var privateCacheDNSZoneName = 'privatelink.redis.cache.azure.com'
var privateNsgName = 'privateNsg'


resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: vnetAddressPrefixes
    }
  }
}

resource privateNsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: privateNsgName
  location: location
}

resource defaultSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  name: 'default'
  parent: vnet
  properties: {
    addressPrefix: defaultSubnetAddressPrefix
  }
}

resource databaseSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  name: 'database'
  parent: vnet
  properties: {
    addressPrefix: databaseSubnetAddressPrefix
    networkSecurityGroup: {
      id: privateNsg.id
    }
    delegations: [
      {
        name: 'database'
        properties: {
          serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
        }
      }
    ]
  }
  dependsOn: [
    defaultSubnet
  ]
}

resource cacheSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  name: 'cache'
  parent: vnet
  properties: {
    addressPrefix: cacheSubnetAddressPrefix
    networkSecurityGroup: {
      id: privateNsg.id
    }
  }
  dependsOn: [
    databaseSubnet
  ]
}


resource containersSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  name: 'containers'
  parent: vnet
  properties: {
    addressPrefix: containerSubnetAddressPrefix
    networkSecurityGroup: {
      id: privateNsg.id
    }
    delegations: [
      {
        name: 'containerAppEnvironmentDelegation'
        properties: {
          serviceName: 'Microsoft.App/environments'
        }
      }
    ]
  }
  dependsOn: [
    cacheSubnet
  ]
}

resource privateDNSZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: privateDNSZoneName
  location: 'global'
}

resource privateDNSZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDNSZone
  name: uniqueString(vnet.id)
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}

resource privateCacheDNSZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: privateCacheDNSZoneName
  location: 'global'
}

resource privateChacheDNSZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateCacheDNSZone
  name: uniqueString(vnet.id)
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}

output databaseSubnetId string = databaseSubnet.id
output privateDNSZoneId string = privateDNSZone.id
output privateDNSZoneName string = privateDNSZone.name
output cacheSubnetId string = cacheSubnet.id
output cacheDnsZoneId string = privateCacheDNSZone.id
output cacheDnsZoneName string = privateCacheDNSZone.name
output containersSubnetId string = containersSubnet.id
