output "namespace" {
  value = module.vault_test_namespace.namespace
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