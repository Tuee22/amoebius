variable "availability_zones" {
  type    = list(string)
  default = []
}

variable "subnet_ids" {
  type        = list(string)
  description = "One subnet per zone"
}

variable "security_group_id" {
  type        = string
}

variable "instance_groups" {
  type = list(object({
    name           = string
    category       = string
    count_per_zone = number
    image          = optional(string, "")
  }))
  default = []
}

variable "instance_type_map" {
  type    = map(string)
  default = {}
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

# For AWS, we might not need resource_group_name / location, but let's keep them to stay consistent
variable "resource_group_name" {
  type    = string
  default = ""
}

variable "location" {
  type    = string
  default = ""
}
