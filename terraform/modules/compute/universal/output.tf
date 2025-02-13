output "instances_by_group" {
  description = "Map group_name => list of { name, private_ip, public_ip, vault_path }"
  value       = local.instances_by_group
}
