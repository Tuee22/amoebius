variable "region" {
  type        = string
  description = "GCP region (or project). No default."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR for GCP VPC."
}

variable "availability_zones" {
  type        = list(string)
  description = "List of GCP zones."
}

variable "instance_type_map" {
  type        = map(string)
  description = "Map of category => instance type for GCP."
}

variable "arm_default_image" {
  type        = string
  description = "ARM image if not set in group."
}

variable "x86_default_image" {
  type        = string
  description = "x86 image if not set in group."
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
  description = "SSH user for GCP VM."
}

variable "vault_role_name" {
  type        = string
  description = "Vault role name for storing SSH secrets."
}

variable "no_verify_ssl" {
  type        = bool
  description = "Skip SSL verify for Vault if true."
}
