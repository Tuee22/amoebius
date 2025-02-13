output "vpc_id" {
  value = module.network.vpc_id
}

output "subnet_ids" {
  value = module.network.subnet_ids
}

output "subnet_cidrs" {
  value = module.network.subnet_cidrs
}

output "security_group_id" {
  value = module.network.security_group_id
}

output "instances_by_group" {
  description = "Map of group_name => array of { name, private_ip, public_ip, vault_path }"
  value       = module.compute.instances_by_group
}
