variable "vault_addr" {
  description = "Address of the Vault server"
  type        = string
}

variable "vault_token" {
  description = "A Vault token with permissions to create policies, roles, etc."
  type        = string
  sensitive   = true
  ephemeral   = true
}