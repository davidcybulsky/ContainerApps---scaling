param location string

param projectName string

param postgresAdminLogin string

@secure()
param postgresAdminPassword string

param databaseSubnetId string

param cacheSubnetId string

param privateDNSZoneId string

param cachePrivateDnsZoneId string


var postgresServerName = '${projectName}server'
var chatservicedbName = 'chatservicedb'
var userdataservicedbName = 'userdataservicedb'
var cacheForRedisName = 'szachmaty'
var cachePrivateLinkName = 'cachePrivateLink'

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: postgresServerName
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    createMode: 'Default'
    version: '16'
    administratorLogin: postgresAdminLogin
    administratorLoginPassword: postgresAdminPassword
    storage: {
      iops: 120
      tier: 'P4'
      storageSizeGB: 32
      autoGrow: 'Enabled'
    }
    network: {
      delegatedSubnetResourceId: databaseSubnetId
      privateDnsZoneArmResourceId: privateDNSZoneId
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
      tenantId: tenant().tenantId
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    dataEncryption: {
      type: 'SystemManaged'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    maintenanceWindow: {
      customWindow: 'Disabled'
      dayOfWeek: 0
      startHour: 0
      startMinute: 0
    }
  }
}

resource chatServiceDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  parent: postgresServer
  name: chatservicedbName
}

resource userDataServiceDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  parent: postgresServer
  name: userdataservicedbName
}

resource cacheForRedis 'Microsoft.Cache/redis@2024-04-01-preview' = {
  name: cacheForRedisName
  location: location
  properties: {
    redisVersion: '6'
    sku: {
      name: 'Standard'
      family: 'C'
      capacity: 0
    }
    redisConfiguration: {
      'aad-enabled': 'false'
    }
    enableNonSslPort: true 
    publicNetworkAccess: 'Disabled'
    zonalAllocationPolicy: 'Automatic'
    disableAccessKeyAuthentication: false
  }
}

resource cachePrivateLink 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: cachePrivateLinkName
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'privateLinkRedis'
        properties: {
          privateLinkServiceId: cacheForRedis.id
          groupIds: [
            'redisCache'
          ]
        }
      }
    ]
    subnet: {
      id: cacheSubnetId
    }
  }
}

resource cachePrivateLinkDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: cachePrivateLink
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-redis-cache-windows-net'
        properties: {
          privateDnsZoneId: cachePrivateDnsZoneId
        }
      }
    ]
  }
}

output chatServiceDbName string = chatServiceDatabase.name
output userDataServiceDbName string = userDataServiceDatabase.name
output postgresServerName string = postgresServer.name
output cacheForRedisName string = cacheForRedis.name
