variable "availability_zones" {
  type    = list(string)
  default = []
}

variable "subnet_ids_by_zone" {
  type        = map(string)
  description = "Map of zone => subnet ID"
  default     = {}
}

variable "security_group_id" {
  type        = string
  description = "Network security group ID"
}

variable "deployment" {
  type = map(object({
    category       = string
    count_per_zone = number
    image          = string
  }))
  default = {}
  description = <<EOT
Map of group_name => object({
  category       = string
  count_per_zone = number
  image          = string
})
EOT
}

variable "instance_type_map" {
  type    = map(string)
  default = {}
}

variable "ssh_user" {
  type    = string
  default = "azureuser"
}

variable "vault_role_name" {
  type    = string
  default = "amoebius-admin-role"
}

variable "no_verify_ssl" {
  type    = bool
  default = true
}

variable "resource_group_name" {
  type    = string
  default = ""
}

variable "location" {
  type    = string
  default = ""
}

variable "workspace" {
  type        = string
  description = "Terraform workspace name, passed from root."
}
