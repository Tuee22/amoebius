output "namespace" {
  description = "Namespace where Amoebius was deployed"
  value       = module.amoebius_namespace.namespace
}

output "service_account_name" {
  description = "Service account for Amoebius"
  value       = kubernetes_service_account_v1.amoebius_admin.metadata[0].name
}