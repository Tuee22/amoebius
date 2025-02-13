###############################################################################
# main.tf - Azure Multi-Zone ARM64 VM Deploy with Vault SSH Storage
# Using Kubernetes backend for state, plus an explicitly-managed Network Watcher.
###############################################################################

###############################################################################
# 1) Variables
###############################################################################
variable "location" {
  type    = string
  default = "eastus" # A region that supports Ampere Altra ARM64 VMs and 3 AZs
}

variable "availability_zones" {
  type    = list(string)
  default = ["1", "2", "3"] # eastus has 3 AZs
}

variable "resource_group_name" {
  type    = string
  default = "test-azure-rg"
}

variable "ssh_user" {
  type    = string
  default = "azureuser"
}

variable "vault_role_name" {
  type    = string
  default = "amoebius-admin-role"
}

variable "no_verify_ssl" {
  type    = bool
  default = false
}

###############################################################################
# 2) Terraform Settings & Provider
###############################################################################
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "kubernetes" {
    secret_suffix     = "test-azure-deploy-standalone"
    load_config_file  = false
    namespace         = "amoebius"
    in_cluster_config = true
  }
}

provider "azurerm" {
  features {}
}

###############################################################################
# 3) Resource Groups
###############################################################################
# Main resource group for your VMs, network, etc.
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# Separate resource group for Network Watcher, so Terraform manages it explicitly
resource "azurerm_resource_group" "network_watcher" {
  name     = "${terraform.workspace}-NetworkWatcherRG"
  location = var.location
}

###############################################################################
# 4) Network Watcher (explicitly managed)
###############################################################################
resource "azurerm_network_watcher" "main" {
  name                = "NetworkWatcher_${var.location}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network_watcher.name
}

###############################################################################
# 5) Virtual Network & Subnets
###############################################################################
resource "azurerm_virtual_network" "main" {
  name                = "${terraform.workspace}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "public_subnets" {
  count                = length(var.availability_zones)
  name                 = "${terraform.workspace}-subnet-${count.index}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.${count.index}.0/24"]
}

###############################################################################
# 6) Network Security Group
###############################################################################
resource "azurerm_network_security_group" "ssh" {
  name                = "${terraform.workspace}-ssh-nsg"
  location            = azurerm_resource_group.main.location
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

###############################################################################
# 7) Public IPs & NICs
###############################################################################
resource "azurerm_public_ip" "main" {
  count               = length(var.availability_zones)
  name                = "${terraform.workspace}-publicip-${count.index}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  # Use 'Standard' so we can place IPs in zones
  sku               = "Standard"
  allocation_method = "Static"
  
  # Pin each public IP to the same zone as its corresponding VM
  zones = [var.availability_zones[count.index]]
}

resource "azurerm_network_interface" "main" {
  count               = length(var.availability_zones)
  name                = "${terraform.workspace}-nic-${count.index}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.public_subnets[count.index].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main[count.index].id
  }
}

resource "azurerm_network_interface_security_group_association" "main" {
  count = length(var.availability_zones)

  network_interface_id      = azurerm_network_interface.main[count.index].id
  network_security_group_id = azurerm_network_security_group.ssh.id
}

###############################################################################
# 8) Generate SSH Keys
###############################################################################
resource "tls_private_key" "ssh_keys" {
  count    = length(var.availability_zones)
  algorithm = "RSA"
  rsa_bits  = 4096
}

###############################################################################
# 9) ARM64 Ubuntu Virtual Machines
###############################################################################
resource "azurerm_linux_virtual_machine" "vm" {
  count               = length(var.availability_zones)
  name                = "${terraform.workspace}-vm-${count.index}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Small and relatively inexpensive ARM64 instance
  size = "Standard_D2ps_v5"

  admin_username = var.ssh_user

  network_interface_ids = [
    azurerm_network_interface.main[count.index].id
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.ssh_user
    public_key = tls_private_key.ssh_keys[count.index].public_key_openssh
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-arm64"
    version   = "latest"
  }

  zone = var.availability_zones[count.index]

  os_disk {
    name                 = "${terraform.workspace}-osdisk-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 30
  }
}

###############################################################################
# 10) Outputs
###############################################################################
output "vm_public_ips" {
  description = "Public IP addresses of the created Azure VMs."
  value       = [for ip in azurerm_public_ip.main : ip.ip_address]
}

output "vm_names" {
  description = "List of VM names."
  value       = [for vm in azurerm_linux_virtual_machine.vm : vm.name]
}