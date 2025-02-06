variable "vault_role_name" {
  type        = string
  description = "Vault Kubernetes auth role name."
}

variable "path" {
  type        = string
  description = "Vault path where the SSH config will be stored. Example: secrets/ssh/myserver"
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
  description = "SSH server port. Defaults to 22."
}

variable "private_key" {
  type        = string
  sensitive   = true
  ephemeral   = true
  description = <<EOT
SSH private key (PEM) content. With 'ephemeral = true', Terraform 1.10+ 
will avoid writing this value into state or plan outputs.
EOT
}

variable "no_verify_ssl" {
  type        = bool
  default     = false
  description = "Disable SSL certificate verification when talking to Vault."
}