output "vault_raft_pod_dns_names" {
  value = [
    for i in range(var.vault_replicas) :
    "${var.vault_service_name}-${i}.${var.vault_service_name}-internal.${var.vault_namespace}.svc.cluster.local"
  ]
  description = "DNS names of the Vault Raft pods"
}

output "vault_namespace" {
  value       = kubernetes_namespace.vault.metadata[0].name
  description = "The namespace where Vault is deployed"
}

output "vault_service_name" {
  value       = helm_release.vault.name
  description = "The name of the Vault service"
}

output "vault_common_name" {
  value = "${var.vault_service_name}.${var.vault_namespace}.svc.cluster.local"

}