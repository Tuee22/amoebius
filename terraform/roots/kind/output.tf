output "vault_api_addr" {
  value       = "http://localhost:8200"
  description = "Vault API address accessible from the local machine"
}

output "vault_ui_url" {
  value       = "http://localhost:8200/ui"
  description = "URL for accessing the Vault UI"
}

output "vault_cluster_address" {
  value       = "http://${var.vault_service_name}.${var.vault_namespace}.svc.cluster.local:8200"
  description = "Vault service address within the Kubernetes cluster"
}

output "kubeconfig" {
  value       = kind_cluster.default.kubeconfig
  sensitive   = true
  description = "Kubeconfig for accessing the Kind cluster"
}

output "kind_cluster_endpoint" {
  value       = kind_cluster.default.endpoint
  sensitive   = true
  description = "API server endpoint of the Kind cluster"
}

output "kind_cluster_cluster_ca_certificate" {
  value       = kind_cluster.default.cluster_ca_certificate
  sensitive   = true
  description = "Cluster CA certificate for the Kind cluster"
}

output "kind_cluster_client_certificate" {
  value       = kind_cluster.default.client_certificate
  sensitive   = true
  description = "Client certificate for accessing the Kind cluster"
}

output "kind_cluster_client_key" {
  value       = kind_cluster.default.client_key
  sensitive   = true
  description = "Client key for accessing the Kind cluster"
}

output "port_forwarding_details" {
  value = {
    for pf in var.port_forwards :
    "${pf.local_port}->${pf.remote_port}" => {
      service_name = pf.service_name
      namespace    = pf.namespace
      local_port   = pf.local_port
      remote_port  = pf.remote_port
    }
  }
  description = "Details of the port forwarding configurations"
}

output "vault_raft_pod_dns_names" {
  value = [
    for i in range(var.vault_replicas) :
    "${var.vault_service_name}-${i}.${var.vault_service_name}-internal.${var.vault_namespace}.svc.cluster.local"
  ]
  description = "DNS names of the Vault Raft pods"
}