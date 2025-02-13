variable "provider" {
  type        = string
  description = "aws, azure, or gcp"
}

variable "availability_zones" {
  type        = list(string)
  default     = []
  description = "Which zones to use."
}

variable "subnet_ids" {
  type        = list(string)
  description = "One subnet per zone index."
}

variable "security_group_id" {
  type        = string
}

variable "instance_groups" {
  type = list(object({
    name           = string
    category       = string   # e.g. 'arm_small','x86_small','nvidia_medium'
    count_per_zone = number
    image          = optional(string, "")
  }))
  default = []
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
  default = false
}

variable "instance_type_map" {
  type = map(string)
  default = {}
  description = "Map from category => instance_type. Provided by the root."
}
