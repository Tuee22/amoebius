###################################################################
# provider_root/variables.tf
###################################################################
variable "provider" {
  type        = string
  description = "One of: aws, azure, gcp"
}

variable "region" {
  type        = string
  description = "Cloud region / location"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC / vNet"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of AZs (or zones)."
}

variable "instance_groups" {
  type = list(object({
    name           = string
    category       = string
    count_per_zone = number
    image          = optional(string, "")
  }))
  description = "List of instance groups (like in each provider root)."
}

variable "arm_default_image" {
  type        = string
  description = "Default ARM image to use if group doesn't define an image."
}

variable "x86_default_image" {
  type        = string
  description = "Default x86 image to use if group doesn't define an image."
}

variable "instance_type_map" {
  type        = map(string)
  description = "Map of category => instance type, e.g. 'arm_small' => 't4g.small'"
}

variable "ssh_user" {
  type        = string
  description = "SSH username for the VM"
  default     = "ubuntu"
}

variable "vault_role_name" {
  type        = string
  description = "Vault role name for storing SSH secrets"
  default     = "amoebius-admin-role"
}

variable "no_verify_ssl" {
  type        = bool
  description = "If true, skip SSL verification for Vault"
  default     = true
}

# For Azure sub-module usage, or at least doesn't fail
variable "resource_group_name" {
  type        = string
  default     = ""
  description = "Used by Azure sub-module (ignored by others)."
}

variable "location" {
  type        = string
  default     = ""
  description = "Azure location fallback"
}
