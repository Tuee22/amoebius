###################################################################
# /amoebius/terraform/modules/compute/outputs.tf
###################################################################

output "instances_by_group" {
  description = "Map of group_name => list of instances (name, private_ip, public_ip, vault_path)"
  value       = local.instances_by_group
}

