variable "vm_name" {
  type        = string
  description = "Friendly name for logs."
}

variable "public_ip" {
  type = string
}

variable "private_key_pem" {
  type      = string
  sensitive = true
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "port" {
  type    = number
  default = 22
}

variable "vault_role_name" {
  type    = string
  default = "amoebius-admin-role"
}

variable "no_verify_ssl" {
  type    = bool
  default = false
}

variable "vault_prefix" {
  type        = string
  description = "Prefix for the vault path, e.g. /amoebius/ssh/aws/<workspace>"
}
