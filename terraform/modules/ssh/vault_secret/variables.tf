variable "vault_role_name" {
  type        = string
  description = "Vault Kubernetes auth role name."
}

variable "path" {
  type        = string
  description = "Vault path for storing SSH keys"
}

variable "user" {
  type        = string
}

variable "hostname" {
  type        = string
}

variable "port" {
  type    = number
  default = 22
}

variable "private_key" {
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "no_verify_ssl" {
  type    = bool
  default = true
}
