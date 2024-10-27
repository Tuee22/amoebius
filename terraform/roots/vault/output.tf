output "vault_raft_pod_dns_names" {
  value = [
    for i in range(var.vault_replicas) :
    "${var.vault_service_name}-${i}.${var.vault_service_name}-internal.${var.vault_namespace}.svc.cluster.local"
  ]
  description = "DNS names of the Vault Raft pods"
}