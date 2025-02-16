variable "region" {
  type        = string
  description = "Azure region (e.g. eastus). No default."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for vnet."
}

variable "availability_zones" {
  type        = list(string)
  description = "List of zones (e.g. 1,2,3)."
}

variable "instance_type_map" {
  type        = map(string)
  description = "Map of category => instance type for Azure."
}

variable "arm_default_image" {
  type        = string
  description = "Default ARM image if not specified in group."
}

variable "x86_default_image" {
  type        = string
  description = "Default x86 image if not specified in group."
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
  description = "SSH user for Azure VMs."
}

variable "vault_role_name" {
  type        = string
  description = "Vault role name for SSH secrets."
}

variable "no_verify_ssl" {
  type        = bool
  description = "Skip SSL verify for Vault if true."
}
