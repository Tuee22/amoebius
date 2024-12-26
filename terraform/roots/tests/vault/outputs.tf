output "namespace" {
  value = kubernetes_namespace.vault_test.metadata[0].name
}

output "service_account_name" {
  value = kubernetes_service_account.app_sa.metadata[0].name
}

output "vault_secret_path" {
  value = "secret/data/vault-test/hello"
}

output "deployment_name" {
  value = kubernetes_deployment.app_deployment.metadata[0].name
}