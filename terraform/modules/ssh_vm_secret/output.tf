output "vault_path" {
  description = "Vault path for this VM's SSH key."
  value       = module.ssh_vault_secret.vault_path
}
