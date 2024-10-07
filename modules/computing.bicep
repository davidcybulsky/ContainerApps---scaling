param location string

param projectName string

param szachmatyIdentity string

param szachmatyIdentityResourceGroup string

param containerRegistryName string

param postresServerEndpoint string

param cacheEndpoint string

param postgresAdminLogin string

@secure()
param postgresAdminPassword string

param chatServiceDbName string

param userDataServiceDbName string

@secure()
param jwtKey string

param cacheForRedisName string

param containerEnvironmentSubnetId string


var postgresDbPort = '5432'
var redisCachePort = '6379'
var containerEnvironmentName = '${projectName}-environment-${uniqueString(projectName, location)}'
var containerRegistryLogin = containerRegistry.properties.loginServer
var frontendContainerName = 'web'
var proxyContainerName = 'proxy'
var authGatewayContainerName = 'gateway'
var gameLogicServiceContainerName = 'game-logic-service'
var chatServiceContainerName = 'chatservice'
var userDataServiceContainerName = 'user-data-service'
var aiServiceContainerName = 'minimal-python'
var gameLogicServiceCachePassword = cacheForRedis.listKeys().secondaryKey


resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: containerRegistryName
  scope: resourceGroup('containerRegistry')
}

resource cacheForRedis 'Microsoft.Cache/redis@2024-04-01-preview' existing = {
  name: cacheForRedisName
  scope: resourceGroup()
}

resource szachmatyContainerEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerEnvironmentName
  location: location
  properties: {
    zoneRedundant: false
    kedaConfiguration: {}
    daprConfiguration: {}
    customDomainConfiguration: {}
    workloadProfiles: [
      {
        workloadProfileType: 'Consumption'
        name: 'Consumption'
      }
    ]
    peerAuthentication: {
      mtls: {
        enabled: false
      }
    }
    peerTrafficConfiguration: {
      encryption: {
        enabled: false
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: containerEnvironmentSubnetId
    }
  }
}

resource chatServiceContainer 'Microsoft.App/containerapps@2024-03-01' = {
  name: chatServiceContainerName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${subscription().id}/resourcegroups/${szachmatyIdentityResourceGroup}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${szachmatyIdentity}' : {}
    }
  }
  properties: {
    managedEnvironmentId: szachmatyContainerEnvironment.id
    environmentId: szachmatyContainerEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 8124
        exposedPort: 0
        transport: 'Tcp'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        allowInsecure: false
        stickySessions: {
          affinity: 'none'
        }
      }
      registries: [
        {
          server: containerRegistryLogin
          identity: '${subscription().id}/resourcegroups/${szachmatyIdentityResourceGroup}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${szachmatyIdentity}'
        }
      ]
      secrets: [
        {
          name: 'postgrespassword'
          value: postgresAdminPassword
        }
      ]
      maxInactiveRevisions: 100
    }
    template: {
      containers: [
        {
          image: '${containerRegistryLogin}/${chatServiceContainerName}:latest'
          name: chatServiceContainerName
          env: [
            {
              name: 'SPRING_PROFILES_ACTIVE'
              value: 'prod'
            }
            {
              name: 'SPRING_DATASOURCE_URL'
              value: 'jdbc:postgresql://${postresServerEndpoint}:${postgresDbPort}/${chatServiceDbName}'
            }
            {
              name: 'SPRING_DATASOURCE_USERNAME'
              value: postgresAdminLogin
            }
            {
              name: 'SPRING_DATASOURCE_PASSWORD'
              secretRef: 'postgrespassword'
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

resource gameLogicServiceContainer 'Microsoft.App/containerapps@2024-03-01' = {
  name: gameLogicServiceContainerName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${subscription().id}/resourcegroups/${szachmatyIdentityResourceGroup}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${szachmatyIdentity}' : {}
    }
  }
  properties: {
    managedEnvironmentId: szachmatyContainerEnvironment.id
    environmentId: szachmatyContainerEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 8080
        exposedPort: 0
        transport: 'Tcp'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        allowInsecure: false
        stickySessions: {
          affinity: 'none'
        }
      }
      registries: [
        {
          server: containerRegistryLogin
          identity: '${subscription().id}/resourcegroups/${szachmatyIdentityResourceGroup}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${szachmatyIdentity}'
        }
      ]
      maxInactiveRevisions: 100
      secrets: [
        {
          name: 'cachepassword'
          value: gameLogicServiceCachePassword
        }
        {
          name: 'jwtkey'
          value: jwtKey
        }
      ]
    }
    template: {
      containers: [
        {
          image: '${containerRegistryLogin}/gamelogicservice:latest'
          name: gameLogicServiceContainerName
          env: [
            {
              name: 'REDIS_HOST_NAME'
              value: cacheEndpoint
            }
            {
              name: 'REDIS_PORT'
              value: redisCachePort
            }
            {
              name: 'REDIS_PASSWORD'
              secretRef: 'cachepassword'
            }
            {
              name: 'JWT_KEY'
              secretRef: 'jwtkey'
            }
            {
              name: 'AI_SERVICE_URL'
              value: 'http://minimal-python:8888'
            }
            {
              name: 'USER_SERVICE_URL'
              value: 'http://user-data-service:80'
            }
            {
              name: 'CHAT_SERVICE_URL'
              value: 'http://chatservice:8124'
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

resource authGatewayContainer 'Microsoft.App/containerapps@2024-03-01' = {
  name: authGatewayContainerName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${subscription().id}/resourcegroups/${szachmatyIdentityResourceGroup}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${szachmatyIdentity}' : {}
    }
  }
  properties: {
    managedEnvironmentId: szachmatyContainerEnvironment.id
    environmentId: szachmatyContainerEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 80
        exposedPort: 0
        transport: 'Tcp'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        allowInsecure: false
        stickySessions: {
          affinity: 'none'
        }
      }
      registries: [
        {
          server: containerRegistryLogin
          identity: '${subscription().id}/resourcegroups/${szachmatyIdentityResourceGroup}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${szachmatyIdentity}'
        }
      ]
      maxInactiveRevisions: 100
    }
    template: {
      containers: [
        {
          image: '${containerRegistryLogin}/${authGatewayContainerName}:latest'
          name: authGatewayContainerName
          env: [
            {
              name: 'ASPNETCORE_URLS'
              value: 'http://*:80;'
            }
          ]
          resources: {
            cpu: 1
            memory: '2Gi'
          }
          probes: []
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      volumes: []
    }
  }
  dependsOn: [
    aiServiceContainer
    userDataServiceContainer
    chatServiceContainer
    gameLogicServiceContainer
  ]
}

resource aiServiceContainer 'Microsoft.App/containerapps@2024-03-01' = {
  name: aiServiceContainerName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${subscription().id}/resourcegroups/${szachmatyIdentityResourceGroup}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${szachmatyIdentity}' : {}
    }
  }
  properties: {
    managedEnvironmentId: szachmatyContainerEnvironment.id
    environmentId: szachmatyContainerEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 8888
        exposedPort: 0
        transport: 'Tcp'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        allowInsecure: false
        stickySessions: {
          affinity: 'none'
        }
      }
      registries: [
        {
          server: containerRegistryLogin
          identity: '${subscription().id}/resourcegroups/${szachmatyIdentityResourceGroup}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${szachmatyIdentity}'
        }
      ]
      maxInactiveRevisions: 100
    }
    template: {
      containers: [
        {
          image: '${containerRegistryLogin}/aiservice:latest'
          name: aiServiceContainerName
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

resource proxyContainer 'Microsoft.App/containerapps@2024-03-01' = {
  name: proxyContainerName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${subscription().id}/resourcegroups/${szachmatyIdentityResourceGroup}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${szachmatyIdentity}' : {}
    }
  }
  properties: {
    managedEnvironmentId: szachmatyContainerEnvironment.id
    environmentId: szachmatyContainerEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        exposedPort: 0
        transport: 'Auto'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        allowInsecure: false
        stickySessions: {
          affinity: 'none'
        }
      }
      registries: [
        {
          server: containerRegistryLogin
          identity: '${subscription().id}/resourcegroups/${szachmatyIdentityResourceGroup}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${szachmatyIdentity}'
        }
      ]
      maxInactiveRevisions: 100
    }
    template: {
      containers: [
        {
          image: '${containerRegistryLogin}/${proxyContainerName}:latest'
          name: proxyContainerName
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          probes: []
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
      volumes: []
    }
  }
  dependsOn: [
    frontendContainer
    authGatewayContainer
  ]
}

resource userDataServiceContainer 'Microsoft.App/containerapps@2024-03-01' = {
  name: userDataServiceContainerName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${subscription().id}/resourcegroups/${szachmatyIdentityResourceGroup}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${szachmatyIdentity}' : {}
    }
  }
  properties: {
    managedEnvironmentId: szachmatyContainerEnvironment.id
    environmentId: szachmatyContainerEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 80
        exposedPort: 0
        transport: 'Tcp'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        allowInsecure: false
        stickySessions: {
          affinity: 'none'
        }
      }
      registries: [
        {
          server: containerRegistryLogin
          identity: '${subscription().id}/resourcegroups/${szachmatyIdentityResourceGroup}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${szachmatyIdentity}'
        }
      ]
      maxInactiveRevisions: 100
      secrets: [
        {
          name: 'dbconnectionstring'
          value: 'Server=${postresServerEndpoint};Database=${userDataServiceDbName};Port=${postgresDbPort};User Id=${postgresAdminLogin};Password=${postgresAdminPassword};'
        }
      ]
    }
    template: {
      containers: [
        {
          image: '${containerRegistryLogin}/userdataservice:latest'
          name: userDataServiceContainerName
          env: [
            {
              name: 'ConnectionStrings__Default'
              secretRef: 'dbconnectionstring'
            }
            {
              name: 'ASPNETCORE_URLS'
              value: 'http://*:80;'
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          probes: []
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      volumes: []
    }
  }
}

resource frontendContainer 'Microsoft.App/containerapps@2024-03-01' = {
  name: frontendContainerName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${subscription().id}/resourcegroups/${szachmatyIdentityResourceGroup}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${szachmatyIdentity}' : {}
    }
  }
  properties: {
    managedEnvironmentId: szachmatyContainerEnvironment.id
    environmentId: szachmatyContainerEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 80
        exposedPort: 0
        transport: 'Tcp'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        allowInsecure: false
        stickySessions: {
          affinity: 'none'
        }
      }
      registries: [
        {
          server: containerRegistryLogin
          identity: '${subscription().id}/resourcegroups/${szachmatyIdentityResourceGroup}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${szachmatyIdentity}'
        }
      ]
      maxInactiveRevisions: 100
    }
    template: {
      containers: [
        {
          image: '${containerRegistryLogin}/frontend:latest'
          name: frontendContainerName
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          probes: []
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      volumes: []
    }
  }
  dependsOn: [
    authGatewayContainer
  ]
}
