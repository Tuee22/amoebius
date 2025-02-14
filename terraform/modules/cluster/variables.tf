variable "provider" {
  type        = string
  description = "aws, azure, or gcp"
}

variable "subnet_ids" {
  type        = list(string)
  description = "One subnet per zone"
}

variable "availability_zones" {
  type        = list(string)
  default     = []
  description = "List of zones in the region."
}

variable "security_group_id" {
  type        = string
  description = "SG / firewall ID that allows SSH"
}

variable "instance_groups" {
  type = list(object({
    name           = string
    category       = string
    count_per_zone = number
    # optional custom image
    image          = optional(string, "")
  }))
  default = []
}

variable "instance_type_map" {
  type    = map(string)
  default = {}
  description = "Maps category => instance_type"
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "vault_role_name" {
  type    = string
  default = "amoebius-admin-role"
}

variable "no_verify_ssl" {
  type    = bool
  default = true
}

# If Azure, we might also need resource_group_name. We'll accept it here
variable "azure_resource_group_name" {
  type        = string
  default     = ""
  description = "If provider=azure, pass the RG name here, so we can feed the single VM module"
}
