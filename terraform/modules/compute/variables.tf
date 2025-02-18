###################################################################
# /amoebius/terraform/modules/compute/variables.tf
#
# This single module expects:
#   - cloud_provider: "aws" | "azure" | "gcp"
#   - region, vpc_cidr, availability_zones
#   - instance_groups
#   - instance_type_map
#   - arm_default_image, x86_default_image
#   - ssh_user, vault_role_name, no_verify_ssl
###################################################################

variable "cloud_provider" {
  type        = string
  description = "Must be one of: aws, azure, gcp"
}

variable "region" {
  type        = string
  description = "Cloud region (or project) e.g. us-east-1, eastus, us-central1"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC/vNet"
}

variable "availability_zones" {
  type        = list(string)
  description = "AZ or zone strings"
}

variable "instance_groups" {
  type = list(object({
    name           = string
    category       = string
    count_per_zone = number
    image          = optional(string, "")
  }))
  description = "List of instance group definitions"
}

variable "instance_type_map" {
  type        = map(string)
  description = "Map of category => instance type, e.g. \"arm_small\" => \"t4g.small\""
}

variable "arm_default_image" {
  type        = string
  description = "Default ARM image if none is specified in the group"
}

variable "x86_default_image" {
  type        = string
  description = "Default x86 image if none is specified in the group"
}

variable "ssh_user" {
  type        = string
  default     = "ubuntu"
  description = "SSH user for the created VMs"
}

variable "vault_role_name" {
  type        = string
  default     = "amoebius-admin-role"
  description = "Vault role name to store the SSH key"
}

variable "no_verify_ssl" {
  type        = bool
  default     = true
  description = "If true, skip SSL verification for Vault"
}

