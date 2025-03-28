variable "region" {
  type        = string
  description = "Cloud region (e.g. eastus)."
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

variable "deployment" {
  type = map(object({
    category       = string
    count_per_zone = number
    image          = string
  }))
  description = "Map of group_name => instance definitions (image is mandatory)."
}

variable "ssh_user" {
  type        = string
  description = "SSH username."
  default     = "azureuser"
}

variable "vault_role_name" {
  type        = string
  description = "Vault role name for storing SSH keys."
}

variable "no_verify_ssl" {
  type        = bool
  description = "If true, skip SSL verification for Vault calls."
}
