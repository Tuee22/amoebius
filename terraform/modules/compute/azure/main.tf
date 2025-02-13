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
  # Hypothetical default for Ubuntu 24.04 LTS
  # We'll assume it's "Canonical / 24_04-lts / latest"
  # This is not real at the moment but we'll demonstrate.
  default_image_reference = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server"
    sku       = "24_04-lts"
    version   = "latest"
  }
}

resource "azurerm_public_ip" "this" {
  name                = "${var.workspace}-${var.vm_name}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [var.zone]
}

resource "azurerm_network_interface" "this" {
  name                = "${var.workspace}-${var.vm_name}-nic"
  resource_group_name = var.resource_group_name
  location            = var.location

  ip_configuration {
    name                          = "ipconfig"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.this.id
    subnet_id                     = var.subnet_id
  }
}

resource "azurerm_network_interface_security_group_association" "sg_assoc" {
  network_interface_id      = azurerm_network_interface.this.id
  network_security_group_id = var.security_group_id
}

resource "azurerm_linux_virtual_machine" "this" {
  name                = "${var.workspace}-${var.vm_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.instance_type
  zone                = var.zone

  admin_username                  = var.ssh_user
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.this.id
  ]

  admin_ssh_key {
    username   = var.ssh_user
    public_key = var.public_key_openssh
  }

  dynamic "source_image_reference" {
    for_each = length(var.image) > 0 ? [] : [1]
    content {
      publisher = local.default_image_reference.publisher
      offer     = local.default_image_reference.offer
      sku       = local.default_image_reference.sku
      version   = local.default_image_reference.version
    }
  }

  dynamic "source_image_id" {
    for_each = length(var.image) > 0 ? [1] : []
    content {
      id = var.image
    }
  }

  os_disk {
    name                 = "${var.workspace}-${var.vm_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 30
  }
}

output "vm_name" {
  value = azurerm_linux_virtual_machine.this.name
}

output "private_ip" {
  value = azurerm_network_interface.this.ip_configuration[0].private_ip_address
}

output "public_ip" {
  value = azurerm_public_ip.this.ip_address
}
