###############################################################################
# main.tf - Example Azure VM Deploy with Vault SSH Storage
###############################################################################

###############################################################################
# 1) Variables
###############################################################################
variable "location" {
  type    = string
  default = "eastus"
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

# The azurerm provider will look for environment variables:
#   ARM_CLIENT_ID
#   ARM_CLIENT_SECRET
#   ARM_TENANT_ID
#   ARM_SUBSCRIPTION_ID
provider "azurerm" {
  features {}
}

###############################################################################
# 3) Resource Group
###############################################################################
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

###############################################################################
# 4) Virtual Network & Subnet
###############################################################################
resource "azurerm_virtual_network" "main" {
  name                = "${terraform.workspace}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "main" {
  name                 = "${terraform.workspace}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
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

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.ssh.id
}

###############################################################################
# 6) TLS Key Pair
###############################################################################
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

###############################################################################
# 7) Public IP & Network Interface
###############################################################################
resource "azurerm_public_ip" "main" {
  name                = "${terraform.workspace}-public-ip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "main" {
  name                = "${terraform.workspace}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "${terraform.workspace}-nic-ipcfg"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

###############################################################################
# 8) Linux VM with SSH Key
###############################################################################
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${terraform.workspace}-vm"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = "Standard_B1s"
  admin_username      = var.ssh_user
  network_interface_ids = [
    azurerm_network_interface.main.id
  ]
  disable_password_authentication = true

  # Use our generated SSH public key
  admin_ssh_key {
    username   = var.ssh_user
    public_key = tls_private_key.ssh.public_key_openssh
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

###############################################################################
# 9) Store the Private Key in Vault
###############################################################################
module "ssh_vault_secret" {
  source          = "/amoebius/terraform/modules/ssh_vault_secret"

  vault_role_name = var.vault_role_name
  user            = var.ssh_user
  hostname        = azurerm_public_ip.main.ip_address
  port            = 22
  private_key     = tls_private_key.ssh.private_key_pem
  no_verify_ssl   = var.no_verify_ssl

  # Example path in Vault
  path = "amoebius/tests/azure-test-deploy/ssh/${terraform.workspace}-vm-key"

  depends_on = [
    azurerm_linux_virtual_machine.vm
  ]
}

###############################################################################
# 10) Outputs
###############################################################################
output "vm_public_ip" {
  description = "Public IP of the created Azure VM."
  value       = azurerm_public_ip.main.ip_address
}

output "resource_group_name" {
  description = "Name of the Resource Group."
  value       = azurerm_resource_group.main.name
}

output "vault_ssh_key_path" {
  description = "Path in Vault where the SSH key is stored."
  value       = module.ssh_vault_secret.vault_path
}