output "vpc_id" {
  value = azurerm_virtual_network.main.id
}

output "subnet_ids" {
  value = [for s in azurerm_subnet.subnets : s.id]
}

output "security_group_id" {
  value = azurerm_network_security_group.ssh.id
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}
