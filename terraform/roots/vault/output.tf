# Outputs
output "vault_raft_pod_dns_names" {
  value = [
    for i in range(var.vault_replicas) :
    "http://${var.vault_service_name}-${i}.${var.vault_service_name}-internal.${var.vault_namespace}.svc.cluster.local:8200"
  ]
  description = "DNS names of the Vault Raft pods"
}

output "vault_namespace" {
  value       = kubernetes_namespace.vault.metadata[0].name
  description = "The namespace where Vault is deployed"
}

output "vault_service_account_name" {
  value       = "${var.vault_service_name}"
  description = "Name of the Vault service account"
}

output "vault_service_name" {
  value       = helm_release.vault.name
  description = "The name of the Vault service"
}

output "vault_role" {
  value       = "${helm_release.vault.name}-role"
  description = "Role name dynamically generated for Kubernetes auth in Vault"
}

output "vault_policy_name" {
  value       = "${helm_release.vault.name}-policy"
  description = "Policy name dynamically generated for Vault"
}

output "vault_secret_path" {
  value       = "secret/${helm_release.vault.name}/config"
  description = "Dynamic path for storing application secrets in Vault"
}

output "vault_common_name" {
  value       = "http://${var.vault_service_name}.${var.vault_namespace}.svc.cluster.local:8200"
  description = "FQDN for vault service"
}