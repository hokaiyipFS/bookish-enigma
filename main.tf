terraform {
  required_providers {
    azurerm = {
      # Specify what version of the provider we are going to utilise
      source = "hashicorp/azurerm"
      version = ">= 3.31.0"
    }
  }

  backend "azurerm" {
    resource_group_name = "fsdevops-app01"
    storage_account_name = "fsdevopststate"
    container_name = "tstate"
    key = "terraform.tfstate"
  }

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

# Create the Linux App Service Plan
resource "azurerm_service_plan" "appserviceplan" {
  name = "azurerm_app_service_plan"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type = "Linux"
  sku_name = "B1"
}


# Create the web app, pass in the App Service Plan ID
resource "azurerm_linux_web_app" "webapp" {
  name = "fsdevopsWebapp2022"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id = azurerm_service_plan.appserviceplan.id
  https_only = true
  site_config {
    minimum_tls_version = "1.2"

  }
  app_settings = {
    "WEBSITE_DNS_SERVER": "168.63.129.16",
    "WEBSITE_VNET_ROUTE_ALL": "1"
  }
}

resource "azurerm_app_service_source_control" "sourcecontrol" {
  app_id = azurerm_linux_web_app.webapp.id
  repo_url = "https://github.com/hokaiyipFS/php-docs-hello-world"
  branch = "main"
  use_manual_integration = false
  use_mercurial = false
}
