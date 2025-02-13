variable "provider" {
  type        = string
  description = "Which provider: aws, azure, gcp"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "If empty, use zones_by_provider[provider]."
  default     = []
}

variable "region" {
  type        = string
  description = "If empty, use region_by_provider[provider]."
  default     = ""
}

variable "zones_by_provider" {
  type = map(list(string))
  default = {
    aws   = ["us-east-1a","us-east-1b","us-east-1c"]
    azure = ["1","2","3"]
    gcp   = ["us-central1-a","us-central1-b","us-central1-f"]
  }
}

variable "region_by_provider" {
  type = map(string)
  default = {
    aws   = "us-east-1"
    azure = "eastus"
    gcp   = "us-central1"
  }
}

variable "instance_type_maps" {
  type = map(map(string))
  default = {
    aws = {
      "x86_small"  = "t3.micro"
      "x86_medium" = "t3.small"
      "x86_large"  = "t3.large"
      "arm_small"  = "t4g.micro"
      "arm_medium" = "t4g.small"
      "arm_large"  = "t4g.large"
    },
    azure = {
      "x86_small"  = "Standard_D2s_v5"
      "x86_medium" = "Standard_D4s_v5"
      "x86_large"  = "Standard_D8s_v5"
      "arm_small"  = "Standard_D2ps_v5"
      "arm_medium" = "Standard_D4ps_v5"
      "arm_large"  = "Standard_D8ps_v5"
    },
    gcp = {
      "x86_small"  = "e2-small"
      "x86_medium" = "e2-standard-4"
      "x86_large"  = "e2-standard-8"
      "arm_small"  = "t2a-standard-1"
      "arm_medium" = "t2a-standard-2"
      "arm_large"  = "t2a-standard-4"
    }
  }
}

variable "instance_groups" {
  type = list(object({
    name           = string
    architecture   = string
    size           = string
    count_per_zone = number
  }))
  description = "A list of instance groups to create. Has a default single group."
  default = [
    {
      name           = "default_group"
      architecture   = "x86"
      size           = "small"
      count_per_zone = 1
    }
  ]
}

variable "disk_size_gb" {
  type    = number
  default = 30
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
