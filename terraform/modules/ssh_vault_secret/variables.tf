variable "vault_role_name" {
  type        = string
  description = "Vault Kubernetes auth role name."
}

variable "path" {
  type        = string
  description = "Vault path where the SSH config will be stored."
}

variable "user" {
  type        = string
  description = "SSH username."
}

variable "hostname" {
  type        = string
  description = "SSH server hostname or IP."
}

variable "port" {
  type        = number
  default     = 22
}

variable "private_key" {
  type        = string
  sensitive   = true
  ephemeral   = true
  description = <<EOT
SSH private key (PEM) content. ephemeral=true + sensitive=true so Terraform
won't store it in plan or state in plain text (Terraform 1.10+).
EOT
}

variable "no_verify_ssl" {
  type        = bool
  default     = true
  description = "Disable SSL cert verification to Vault."
}
