#####################################################################
# outputs.tf (Root)
#####################################################################
output "kind_cluster_endpoint" {
  description = "Host endpoint for the Kind cluster"
  value       = module.kind.host
}

output "amoebius_namespace" {
  description = "The namespace used by the linkerd_annotated_namespace module"
  value       = module.amoebius_namespace.namespace
}