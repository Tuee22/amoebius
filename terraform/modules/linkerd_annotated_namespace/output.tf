#####################################################################
# outputs.tf
#####################################################################
output "namespace" {
  description = "The namespace name used by this module."
  value       = var.namespace
}

output "server_name" {
  description = "Name of the Linkerd Server resource."
  value       = var.server_name
}