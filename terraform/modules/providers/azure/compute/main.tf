terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# 🔹 Detect if the image is a custom image or a Marketplace image
locals {
  is_custom_image = length(regexall("^/subscriptions/.*/resourceGroups/.*/providers/Microsoft.Compute/images/.*", var.image)) > 0
  image_parts     = split(":", var.image) # For Marketplace images
}

# 🔹 Create Public IP
resource "azurerm_public_ip" "this" {
  name                = "${var.workspace}-${var.vm_name}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [var.zone]
}

# 🔹 Create Network Interface
resource "azurerm_network_interface" "this" {
  name                = "${var.workspace}-${var.vm_name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.this.id
    subnet_id                     = var.subnet_id
  }
}

# 🔹 Associate NIC with Security Group
resource "azurerm_network_interface_security_group_association" "sg_assoc" {
  network_interface_id      = azurerm_network_interface.this.id
  network_security_group_id = var.security_group_id
}

# 🔹 Create Virtual Machine
resource "azurerm_linux_virtual_machine" "this" {
  name                = "${var.workspace}-${var.vm_name}"
  computer_name = substr(var.vm_name, 0, 15)
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.instance_type
  zone                = var.zone

  admin_username                  = var.ssh_user
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.this.id]

  admin_ssh_key {
    username   = var.ssh_user
    public_key = var.public_key_openssh
  }

  # 🔹 Conditionally set the image type
  dynamic "source_image_reference" {
    for_each = local.is_custom_image ? [] : [1] # Empty if custom image
    content {
      publisher = local.image_parts[0]
      offer     = local.image_parts[1]
      sku       = local.image_parts[2]
      version   = local.image_parts[3]
    }
  }

  source_image_id = local.is_custom_image ? var.image : null # Only set if custom image

  os_disk {
    name                 = "${var.workspace}-${var.vm_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 30
  }
}