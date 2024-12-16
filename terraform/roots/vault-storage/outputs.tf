output "vault_namespace" {
  value       = var.vault_namespace
  description = "The namespace where Vault should be deployed"
}

output "vault_storage_class_name" {
  value       = var.storage_class_name
  description = "The name of the storage class for Vault"
}

output "vault_replicas" {
  value       = var.vault_replicas
  description = "Number of Vault replicas"
}

output "vault_replicas" {
  value       = var.vault_replicas
  description = "Number of Vault replicas"
}

variable "vault_storage_size" {
  value       = var.vault_storage_size
  description = "Size of the Vault storage"
}