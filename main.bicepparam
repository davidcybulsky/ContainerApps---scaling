using 'main.bicep'

param szachmatyIdentityResourceGroup =  'containerRegistry'

param szachmatyIdentity =  'szachmaty-managed-identity'

param databaseSubnetAddressPrefix =  '10.0.0.0/24'

param defaultSubnetAddressPrefix =  '10.0.1.0/24'

param keyVaultName =  'kv1-szachmaty'

param postgresAdminLogin =  'szachmatypostgresadmin'

param projectName =  'szachmaty'

param vnetAddressPrefixes =  ['10.0.0.0/16']

param cacheSubnetAddressPrefix =  '10.0.2.0/24'

param containerRegistryName =  'szachmatypl'

param containersSubnetAddressPrefix =  '10.0.3.0/24'
