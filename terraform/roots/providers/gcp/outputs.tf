output "instances" {
  description = "Nested map: group_name => (instance_key => VM info)."
  value       = module.cluster.instances
}
