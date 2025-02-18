###################################################################
# provider_root/outputs.tf
###################################################################
output "instances_by_group" {
  description = "Map of group_name => list of VM objects from module.compute"
  value       = module.compute.instances_by_group
}
