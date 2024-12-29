variable "vault_addr" {
  description = "Address of the Vault server"
  type        = string
}

variable "vault_token" {
  description = "Root token or a token with sufficient permissions to create policies and roles"
  type        = string
  sensitive   = true
  ephemeral   = true
}