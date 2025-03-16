output "host" {
  description = "API endpoint for the Kind cluster"
  value       = kind_cluster.default.endpoint
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate"
  value       = kind_cluster.default.cluster_ca_certificate
}

output "client_certificate" {
  description = "Client certificate for authenticating"
  value       = kind_cluster.default.client_certificate
}

output "client_key" {
  description = "Client key for authenticating"
  value       = kind_cluster.default.client_key
}
