variable "vault_addr" {
  description = "Address of the Vault server"
  type        = string
  default     = "http://vault.vault.svc.cluster.local:8200/"
}

variable "vault_token" {
  description = "Root token or a token with sufficient permissions to create policies and roles"
  type        = string
  sensitive   = true
  ephemeral   = true
}