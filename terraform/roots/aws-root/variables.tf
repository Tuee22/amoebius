variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a","us-east-1b","us-east-1c"]
}

# For each category we might have: arm_small, x86_small, x86_medium, nvidia_small, etc.
variable "instance_type_map" {
  type = map(string)
  default = {
    "arm_small"     = "t4g.micro"
    "arm_medium"    = "t4g.small"
    "x86_small"     = "t3.micro"
    "x86_medium"    = "t3.small"
    "nvidia_small"  = "g4dn.xlarge"
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
