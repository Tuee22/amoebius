output "vm_name" {
  description = "VM name or ID"
  value       = module.single_vm.vm_name
}

output "private_ip" {
  description = "VM private IP"
  value       = module.single_vm.private_ip
}

output "public_ip" {
  description = "VM public IP"
  value       = module.single_vm.public_ip
}
