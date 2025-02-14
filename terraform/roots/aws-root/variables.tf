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

# Default instance_type_map. The user can override if they want
variable "instance_type_map" {
  type = map(string)
  default = {
    "arm_small"  = "t4g.micro"
    "x86_small"  = "t3.micro"
    "x86_medium" = "t3.small"
    "nvidia_small" = "g4dn.xlarge"
  }
}

variable "arm_default_image" {
  type    = string
  default = "ami-0faefad027f3b5de6" # e.g. hypothetical Ubuntu 24.04 ARM for us-east-1
  # in reality you'll pick the official 24.04 once it's out
}

variable "x86_default_image" {
  type    = string
  default = "ami-0c8a4fc5fa843b2c2" # e.g. hypothetical Ubuntu 24.04 x86
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
  default = true
}
