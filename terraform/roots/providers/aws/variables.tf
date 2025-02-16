variable "region" {
  type        = string
  description = "AWS region (no default)."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block."
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones."
}

variable "instance_type_map" {
  type = map(string)
  description = "Map of category => instance type."
}

variable "arm_default_image" {
  type        = string
  description = "Default ARM image if not set in instance_groups."
}

variable "x86_default_image" {
  type        = string
  description = "Default x86 image if not set in instance_groups."
}

variable "instance_groups" {
  type = list(object({
    name           = string
    category       = string
    count_per_zone = number
    image          = optional(string, "")
  }))
  description = "All instance groups."
}

variable "ssh_user" {
  type        = string
  description = "SSH username."
}

variable "vault_role_name" {
  type        = string
  description = "Vault role name for storing SSH secrets."
}

variable "no_verify_ssl" {
  type        = bool
  description = "If true, skip Vault SSL verification."
}
