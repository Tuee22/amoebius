variable "region" {
  type    = string
  default = "eastus"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["1","2","3"]
}

variable "instance_type_map" {
  type = map(string)
  default = {
    "arm_small"   = "Standard_D2ps_v5",
    "x86_small"   = "Standard_D2s_v5",
    "nvidia_small"= "Standard_NC4as_T4_v3"
  }
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
  default = false
}
