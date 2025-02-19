variable "region" {
  type        = string
  description = "Cloud region (e.g. us-west-1)."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block."
}

variable "availability_zones" {
  type        = list(string)
  description = "List of zones/AZs."
}

variable "instance_type_map" {
  type        = map(string)
  description = "Map of category => instance type."
}

variable "arm_default_image" {
  type        = string
  description = "Default ARM image if none is specified."
}

variable "x86_default_image" {
  type        = string
  description = "Default x86 image if none is specified."
}

variable "instance_groups" {
  type = list(object({
    name           = string
    category       = string
    count_per_zone = number
    image          = optional(string, null)
  }))
  description = "All instance group definitions."
}

variable "ssh_user" {
  type        = string
  description = "SSH username."
}

variable "vault_role_name" {
  type        = string
  description = "Vault role name for storing SSH keys."
}

variable "no_verify_ssl" {
  type        = bool
  description = "If true, skip SSL verification for Vault calls."
}

