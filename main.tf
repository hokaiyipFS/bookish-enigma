terraform {
  required_providers {
    azurerm = {
      # Specify what version of the provider we are going to utilise
      source = "hashicorp/azurerm"
      version = ">= 2.4.1"
    }
  }

  backend "azurerm" {
    resource_group_name = "fsdevops-infra"
    storage_account_name = "fsdevopststate"
    container_name = "tstate"
    key = "l3bDwx6Er+R0bHu5AsGKPMWIAsBYQE4doeavhmwnJZO2xqYcdoCXOVskXxCrPryDwyqLq3aQvtMg+AStwnFBxA=="
  }

  //  │ Error: checking for presence of existing resource group: resources.GroupsClient
  #Get: Failure responding to request: StatusCode=403 -- Original Error: autorest/azure: Service returned an error.
  // Status=403 Code="AuthorizationFailed" Message="The client 'ffb0aee1-7a3a-49ee-9f05-7fcfdac9a4df'
  // with object id 'ffb0aee1-7a3a-49ee-9f05-7fcfdac9a4df' does not have authorization to perform action 'Microsoft.Resources/subscriptions/resourcegroups/read' over scope
  // '/subscriptions/76e92d8f-9793-4ec6-b1a7-c13660ee5293/resourcegroups/fsdevops-app01' or
  // the scope is invalid. If access was recently granted, please refresh your credentials."
}
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}
data "azurerm_client_config" "current" {}
# Create our Resource Group - FSdevops-RG
resource "azurerm_resource_group" "rg" {
  name = "fsdevops-app01"
  location = "eastus"
}
# Create our Virtual Network - FSdevops-VNET
resource "azurerm_virtual_network" "vnet" {
  name = "fsdevopsvnet"
  address_space = [
    "10.0.0.0/16"]
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
# Create our Subnet to hold our VM - Virtual Machines
resource "azurerm_subnet" "sn" {
  name = "VM"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = [
    "10.0.1.0/24"]
}
# Create our Azure Storage Account - fsdevopssa
resource "azurerm_storage_account" "fsdevopssa" {
  name = "fsdevopssa"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  account_tier = "Standard"
  account_replication_type = "LRS"
  tags = {
    environment = "fsdevopsrox"
  }
}
# Create our vNIC for our VM and assign it to our Virtual Machines Subnet
resource "azurerm_network_interface" "vmnic" {
  name = "fsdevopsvm01nic"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.sn.id
    private_ip_address_allocation = "Dynamic"
  }
}
# Create our Virtual Machine - FSdevops-VM01
resource "azurerm_virtual_machine" "fsdevopsvm01" {
  name = "fsdevopsvm01"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  network_interface_ids = [
    azurerm_network_interface.vmnic.id]
  vm_size = "Standard_B2s"
  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer = "WindowsServer"
    sku = "2016-Datacenter-Server-Core-smalldisk"
    version = "latest"
  }
  storage_os_disk {
    name = "fsdevopsvm01os"
    caching = "ReadWrite"
    create_option = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name = "fsdevopsvm01"
    admin_username = "fsdevops"
    admin_password = "Password123$"
  }
  os_profile_windows_config {
  }


}
