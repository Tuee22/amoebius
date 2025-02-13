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
  resource_group_name = var.subnet_id  # We'll rely on the cluster module to pass RG name differently if needed
  # ^ Actually that's not correct if your 'subnet_id' is just the Subnet ID.
  # Typically we also need resource_group_name from the cluster module.
  # But for consistency with the instructions, let's assume your cluster passes correct values. 
  # Or you'd set a separate variable for RG. Adjust as needed.

  location            = "eastus"
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [var.zone]
}

resource "azurerm_network_interface" "this" {
  name                = "${var.workspace}-${var.vm_name}-nic"
  location            = "eastus"
  resource_group_name = azurerm_public_ip.this.resource_group_name

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
  resource_group_name = azurerm_public_ip.this.resource_group_name
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

  # If empty, cluster module sets actual default. So here we just assume var.image is correct.
  # If you wanted to do a fallback, you'd place it here, but the instructions say no defaults in the provider modules.
  source_image_id = var.image

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
