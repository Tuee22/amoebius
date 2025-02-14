variable "region" {
  type    = string
  default = "us-central1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-central1-a","us-central1-b","us-central1-f"]
}

variable "instance_type_map" {
  type = map(string)
  default = {
    "arm_small"    = "t2a-standard-1",
    "x86_small"    = "e2-small",
    "nvidia_small" = "a2-highgpu-1g"
  }
}

variable "arm_default_image" {
  type    = string
  default = "projects/ubuntu-os-cloud/global/images/ubuntu-2404-lts-arm64"
}

variable "x86_default_image" {
  type    = string
  default = "projects/ubuntu-os-cloud/global/images/ubuntu-2404-lts"
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
