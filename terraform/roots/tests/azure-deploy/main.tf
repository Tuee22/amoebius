###############################################################################
# main.tf - Azure Multi-Zone ARM64 VM Deploy with Vault SSH Storage
###############################################################################

###############################################################################
# 1) Variables
###############################################################################
variable "location" {
  type    = string
  # Must be a region that supports Ampere Altra VMs and zones, e.g. eastus
  default = "eastus"
}

variable "availability_zones" {
  type    = list(string)
  # For example: ["1", "2", "3"] if the region has three zones
  default = ["1", "2", "3"]
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
  backend "kubernetes" {
    secret_suffix     = "test-azure-deploy"
    load_config_file  = false
    namespace         = "amoebius"
    in_cluster_config = true
  }

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
}

provider "azurerm" {
  features {}
  # This provider will read from environment variables:
  #   ARM_CLIENT_ID
  #   ARM_CLIENT_SECRET
  #   ARM_TENANT_ID
  #   ARM_SUBSCRIPTION_ID
}

###############################################################################
# 3) Resource Group
###############################################################################
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

###############################################################################
# 4) Virtual Network & Multiple Subnets (One per Availability Zone)
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
  # For each subnet, pick a /24 block 10.0.<index>.0/24
  address_prefixes     = ["10.0.${count.index}.0/24"]
}

###############################################################################
# 5) Network Security Group & Association (Allow SSH)
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

resource "azurerm_subnet_network_security_group_association" "public_subnets_assoc" {
  count = length(var.availability_zones)

  subnet_id                 = azurerm_subnet.public_subnets[count.index].id
  network_security_group_id = azurerm_network_security_group.ssh.id
}

###############################################################################
# 6) TLS Key Pairs (If you want each VM to have a unique key)
###############################################################################
resource "tls_private_key" "ssh_keys" {
  count     = length(var.availability_zones)
  algorithm = "RSA"
  rsa_bits  = 2048
}

###############################################################################
# 7) Public IPs & Network Interfaces (One per Zone)
###############################################################################
resource "azurerm_public_ip" "main" {
  count               = length(var.availability_zones)
  name                = "${terraform.workspace}-public-ip-${count.index}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "main" {
  count               = length(var.availability_zones)
  name                = "${terraform.workspace}-nic-${count.index}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "${terraform.workspace}-nic-ipcfg-${count.index}"
    subnet_id                     = azurerm_subnet.public_subnets[count.index].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main[count.index].id
  }
}

###############################################################################
# 8) Linux VMs in 3 Zones (ARM64 - Ampere Altra)
###############################################################################
resource "azurerm_linux_virtual_machine" "vm" {
  count               = length(var.availability_zones)
  name                = "${terraform.workspace}-vm-${count.index}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # For an Ampere Altra-based ARM64 instance:
  size                = "Standard_D2plsv5"

  admin_username      = var.ssh_user
  network_interface_ids = [
    azurerm_network_interface.main[count.index].id
  ]

  disable_password_authentication = true

  # Provide the SSH public key from the matching index
  admin_ssh_key {
    username   = var.ssh_user
    public_key = tls_private_key.ssh_keys[count.index].public_key_openssh
  }

  # Use an ARM64 Ubuntu image
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy-arm64"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # Pin each VM to the specified zone index
  zone = var.availability_zones[count.index]
}

###############################################################################
# 9) Store the Private Keys in Vault (Once per VM)
###############################################################################
module "ssh_vault_secret" {
  source = "/amoebius/terraform/modules/ssh_vault_secret"

  count            = length(var.availability_zones)
  vault_role_name  = var.vault_role_name
  user             = var.ssh_user
  hostname         = azurerm_public_ip.main[count.index].ip_address
  port             = 22
  private_key      = tls_private_key.ssh_keys[count.index].private_key_pem
  no_verify_ssl    = var.no_verify_ssl

  path = "amoebius/tests/azure-test-deploy/ssh/${terraform.workspace}-vm-key-${count.index}"

  depends_on = [
    azurerm_linux_virtual_machine.vm
  ]
}

###############################################################################
# 10) Outputs
###############################################################################
output "vm_public_ips" {
  description = "Public IP addresses of the created Azure VMs."
  value       = [for ip in azurerm_public_ip.main : ip.ip_address]
}

output "vm_names" {
  description = "List of the VM names."
  value       = [for vm in azurerm_linux_virtual_machine.vm : vm.name]
}

output "vault_ssh_key_paths" {
  description = "Vault paths where each SSH key is stored."
  value       = [for item in module.ssh_vault_secret : item.vault_path]
}