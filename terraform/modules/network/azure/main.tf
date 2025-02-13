terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  # region must be matched if we do data or resource group logic
}

resource "azurerm_resource_group" "main" {
  name     = "${terraform.workspace}-rg"
  location = var.region
}

resource "azurerm_virtual_network" "main" {
  name                = "${terraform.workspace}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vpc_cidr]
}

resource "azurerm_subnet" "subnets" {
  count                = length(var.availability_zones)
  name                 = "${terraform.workspace}-subnet-${count.index}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vpc_cidr, 8, count.index)]
}

resource "azurerm_network_security_group" "ssh" {
  name                = "${terraform.workspace}-ssh-nsg"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow_ssh"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
