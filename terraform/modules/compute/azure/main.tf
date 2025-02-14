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

resource "azurerm_public_ip" "this" {
  name                = "${var.workspace}-${var.vm_name}-pip"
  resource_group_name = var.resource_group_name
  location            = "eastus"
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [var.zone]
}

resource "azurerm_network_interface" "this" {
  name                = "${var.workspace}-${var.vm_name}-nic"
  location            = "eastus"
  resource_group_name = var.resource_group_name

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
  location            = "eastus"
  size                = var.instance_type
  zone                = var.zone

  admin_username                  = var.ssh_user
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.this.id]

  admin_ssh_key {
    username   = var.ssh_user
    public_key = var.public_key_openssh
  }

  # We assume var.image is an ID of a managed or gallery image
  source_image_id = var.image

  os_disk {
    name                 = "${var.workspace}-${var.vm_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 30
  }
}
