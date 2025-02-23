# Outputs
output "vault_common_name" {
  value       = "http://${var.vault_service_name}.${var.vault_namespace}.svc.cluster.local:8200"
  description = "FQDN for vault service"
}

output "vault_raft_pod_dns_names" {
  value = [
    for i in range(var.vault_replicas) :
    "http://${var.vault_service_name}-${i}.${var.vault_service_name}-internal.${var.vault_namespace}.svc.cluster.local:8200"
  ]
  description = "DNS names of the Vault Raft pods"
}

output "vault_service_name" {
  value       = helm_release.vault.name
  description = "The name of the Vault service"
}

output "vault_namespace" {
  value       = module.vault_namespace.namespace
  description = "The namespace where Vault is deployed"
}

output "vault_service_account_name" {
  value       = kubernetes_service_account_v1.vault_service_account.metadata[0].name
  description = "Name of the Vault service account"
}

output "vault_secret_path" {
  value       = "secret/${helm_release.vault.name}/config"
  description = "Path for storing application secrets in Vault (if needed)."
}
