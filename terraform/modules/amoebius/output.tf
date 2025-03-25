#####################################################################
# modules/amoebius/outputs.tf
#####################################################################

output "registry_creds_name" {
  description = "The name of the registry-creds Helm release"
  value       = helm_release.registry_creds.name
}

output "amoebius_service_account" {
  description = "ServiceAccount used by the Amoebius pods"
  value       = kubernetes_service_account_v1.amoebius_admin.metadata[0].name
}

output "amoebius_service_name" {
  description = "The name of the Service that exposes Amoebius"
  value       = kubernetes_service_v1.amoebius.metadata[0].name
}