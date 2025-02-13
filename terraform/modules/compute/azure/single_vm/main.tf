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
}

locals {
  default_image_x86 = {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "20_04-lts"
    version   = "latest"
  }
  default_image_arm = {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "20_04-lts-arm64"
    version   = "latest"
  }
}

# We'll create an RG for each VM or rely on a common RG. Usually you'd pass it in, but for simplicity:
resource "azurerm_resource_group" "vm_rg" {
  name     = "${terraform.workspace}-${var.vm_name}-rg"
  location = var.region
}

resource "azurerm_public_ip" "pip" {
  name                = "${terraform.workspace}-${var.vm_name}-pip"
  resource_group_name = azurerm_resource_group.vm_rg.name
  location            = var.region
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = []
}

resource "azurerm_network_interface" "nic" {
  name                = "${terraform.workspace}-${var.vm_name}-nic"
  resource_group_name = azurerm_resource_group.vm_rg.name
  location            = var.region

  ip_configuration {
    name                          = "ipconfig"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
    subnet_id                     = var.subnet_id
  }
}

resource "azurerm_network_interface_security_group_association" "sg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = var.security_group_id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${terraform.workspace}-${var.vm_name}"
  resource_group_name = azurerm_resource_group.vm_rg.name
  location            = var.region
  size                = var.instance_type

  admin_username                  = "azureuser"
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.public_key_openssh
  }

  dynamic "source_image_reference" {
    for_each = [1]
    content {
      publisher = var.architecture == "arm" ? local.default_image_arm.publisher : local.default_image_x86.publisher
      offer     = var.architecture == "arm" ? local.default_image_arm.offer     : local.default_image_x86.offer
      sku       = var.architecture == "arm" ? local.default_image_arm.sku       : local.default_image_x86.sku
      version   = var.architecture == "arm" ? local.default_image_arm.version   : local.default_image_x86.version
    }
  }

  os_disk {
    name                 = "${terraform.workspace}-${var.vm_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.disk_size_gb
  }
}
