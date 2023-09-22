targetScope = 'subscription'

@minLength(3)
@maxLength(24)
param namingPrefix string

@description('The application environment to be deployed')
@allowed([
  'dev'
  'qa'
  'prod'
])
param environmentName string

@minLength(3)
@maxLength(15)
param location string

@description('The number of VMs to be deployed')
@allowed([
  2
  3
  4
])
param numberOfVMs int = 2

@description('The admin username for the VMs')
@minLength(6)
@maxLength(24)
param adminUsername string

@description('The type of authentication type for the azure virtual machine')
@allowed([
  'sshPublicKey'
  'password'
])
param authType string

@description('The Administator password or SSH Key (the latter is recommended)')
@secure()
param adminPasswordOrKey string

@description('The Windows Server Offer e.g. dotnet ')
param windowsOsOffer string
@description('The exact Windows Server version e.g. 2019')
param windowsOsSku string
@description('The type of disks to attach to the VM')
param osDiskType string
@description('The size of the VM including the memory and cpu instances')
param vmSize string

@description('Tag object that will be applied to every resource created in the current environment')
param globalTags object = {}

// Creates the main resource group that will contain the infrastructure resources
resource resource_group 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${namingPrefix}-${environmentName}-rg'
  location: location
  tags: globalTags
  managedBy: 'string'
}

// The main module that will create all the resources and the virtual network they will reside in
module resources 'modules/app-vm-sql-vm.bicep' = {
  name: '${namingPrefix}-${environmentName}'
  scope: resource_group
  params: {
    name: format('${namingPrefix}-${environmentName}')
    location: location
    numberOfVMs: numberOfVMs
    adminUsername: adminUsername
    authType: authType
    adminPasswordOrKey: adminPasswordOrKey
    windowsOsOffer: windowsOsOffer
    windowsOsSku: windowsOsSku
    osDiskType: osDiskType
    vmSize: vmSize
    globalTags: globalTags
  }
}
