variable "vm_name" {
  type = string
}

variable "public_ip" {
  type = string
}

variable "private_key_pem" {
  type        = string
  sensitive   = true
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
  default = true
}

variable "vault_prefix" {
  type = string
}
