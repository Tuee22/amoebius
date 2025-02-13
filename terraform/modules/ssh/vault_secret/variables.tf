variable "vault_role_name" {
  type        = string
  description = "Vault Kubernetes auth role name."
}

variable "path" {
  type        = string
  description = "Vault path to store SSH config"
}

variable "user" {
  type        = string
  description = "SSH username"
}

variable "hostname" {
  type        = string
  description = "IP or hostname"
}

variable "port" {
  type        = number
  default     = 22
}

variable "private_key" {
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "no_verify_ssl" {
  type    = bool
  default = false
}
