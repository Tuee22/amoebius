output "instances" {
  description = "Nested map: group_name => (instance_key => { name, private_ip, public_ip, vault_path })"
  value       = local.instances
}
