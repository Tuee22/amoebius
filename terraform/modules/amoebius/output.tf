output "namespace" {
  description = "Namespace where Amoebius was deployed"
  value       = var.namespace
}

output "service_account_name" {
  description = "Service account for Amoebius"
  value       = kubernetes_service_account_v1.amoebius_admin.metadata[0].name
}