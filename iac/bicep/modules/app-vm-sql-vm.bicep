@description('Naming prefix for resources')
param name string

@minLength(3)
@maxLength(15)
@description('The Azure region in which the resource will be deployed')
param location string

@description('The total number of Azure Virtual Machines to be provisioned')
@allowed([
    2
    3
    4
  ]
)
param numberOfVMs int

@minLength(6)
@maxLength(24)
param adminUsername string

@description('The Azure region in which the Application Service Plan will be deployed')
@allowed([
  'sshPublicKey'
  'password'
])
param authType string

@description('The Administator password or SSH Key (the latter is recommended)')
@secure()
param adminPasswordOrKey string

@description('The OS version of the VM Image')
param windowsOsOffer string

@description('The Sku of the Windows VM Image')
param windowsOsSku string

@description('The type of disk attached to the VM')
param osDiskType string

@description('The size of the VM, CPU, Memory, Bandwidth')
param vmSize string

@description('Tag object that will be applied to every resource created in the current environment')
param globalTags object = {}

// Creates the primary virtual network resource with the address space
resource virtual_network 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: '${name}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/27'
      ]
    }
    subnets: [
      {
        name: '${name}-subnet1'
        properties: {
          addressPrefix: '10.0.0.0/28'
          networkSecurityGroup: {
            id: primaryNsg.id
          }
        }
      }
    ]
  }
  tags: globalTags
}

// Creates the primary network security group
resource primaryNsg 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: '${name}-nsg1'
  location: location
  tags: globalTags
  properties: {
    securityRules: [
      {
        name: 'RDP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Create public IPs based on the number of VMs requested
resource publicIPVm 'Microsoft.Network/publicIPAddresses@2022-05-01' = [for p in range(0, numberOfVMs): {
  name: '${name}-publicip-vm${p}'
  location: location
  tags: globalTags
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
}]

// Create Network Interfaces based on the number of VMs requested, assigns a public IP to each VMs Network Interface
resource nicVm 'Microsoft.Network/networkInterfaces@2022-05-01' = [for n in range(0, numberOfVMs): {
  name: '${name}-nic-vm${n}'
  location: location
  tags: globalTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: virtual_network.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPVm[n].id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: primaryNsg.id
    }
  }
}]

// Create Virtual Machines base number requested and connects an Network Interface
resource virtual_machine 'Microsoft.Compute/virtualMachines@2022-08-01' = [for v in range(0, numberOfVMs): {
  name: '${name}-vm${padLeft(v, 2, '0')}'
  location: location
  tags: globalTags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: windowsOsOffer
        sku: windowsOsSku
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicVm[v].id
        }
      ]
    }
    osProfile: {
      computerName: take('${padLeft(v, 2, '0')}-${uniqueString(name, string(v), resourceGroup().name)}', 15)
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
    }
  }
}]

