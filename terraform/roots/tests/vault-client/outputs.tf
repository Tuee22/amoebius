#####################################################
# outputs.tf
#####################################################

output "namespace" {
  description = "The namespace where the Vault client app is deployed"
  value       = module.vault_client_test_namespace.namespace
}

output "service_account" {
  description = "The name of the service account for the Vault client app"
  value       = local.app_sa_name
}

output "vault_role_name" {
  description = "Name of role we created"
  value       = vault_kubernetes_auth_backend_role.app_role.role_name
}

output "deployment_name" {
  description = "The name of the Kubernetes Deployment"
  value       = kubernetes_deployment.app_deployment.metadata[0].name
}

output "vault_secret_path" {
  description = "The path of the secret created in Vault"
  value       = "secret/data/vault-client/hello"
}