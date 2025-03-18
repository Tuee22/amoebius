output "harbor_url" {
  description = "The external URL used by Harbor"
  value       = var.external_url
}

output "harbor_release_name" {
  description = "Helm release name used for Harbor"
  value       = helm_release.harbor.name
}

output "harbor_namespace" {
  description = "Kubernetes namespace where Harbor was deployed"
  value       = var.namespace
}
