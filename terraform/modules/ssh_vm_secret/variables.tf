variable "public_ip" {
  type        = string
  description = "Public IP address for SSH."
}

variable "private_key_pem" {
  type        = string
  sensitive   = true
  ephemeral   = true
  description = "Private key (PEM) for SSH. ephemeral + sensitive."
}

variable "ssh_user" {
  type        = string
  default     = "ubuntu"
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

variable "provider" {
  type        = string
  description = "Which cloud provider: 'aws','azure','gcp'"
}
