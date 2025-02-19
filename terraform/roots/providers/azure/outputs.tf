output "instances_by_group" {
  description = "Map of group_name => list of VM objects (name, private_ip, public_ip, vault_path)."
  value       = module.cluster.instances_by_group
}

