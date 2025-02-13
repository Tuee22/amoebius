output "vm_name" {
  value = azurerm_linux_virtual_machine.vm.name
}

output "private_ip" {
  value = azurerm_network_interface.nic.ip_configuration[0].private_ip_address
}

output "public_ip" {
  value = azurerm_public_ip.pip.ip_address
}
