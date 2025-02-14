output "vm_name" {
  description = "Name of this Azure VM"
  value       = azurerm_linux_virtual_machine.this.name
}

output "private_ip" {
  description = "Private IP address of this VM"
  value       = azurerm_network_interface.this.ip_configuration[0].private_ip_address
}

output "public_ip" {
  description = "Public IP address of this VM"
  value       = azurerm_public_ip.this.ip_address
}
