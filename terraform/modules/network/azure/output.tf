output "vpc_id" {
  value = azurerm_virtual_network.main.id
}

output "subnet_ids" {
  value = [for s in azurerm_subnet.subnets : s.id]
}

output "subnet_cidrs" {
  value = [for s in azurerm_subnet.subnets : s.address_prefixes[0]]
}

output "security_group_id" {
  value = azurerm_network_security_group.ssh.id
}
