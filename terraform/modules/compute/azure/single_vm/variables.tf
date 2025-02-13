variable "vm_name" {
  type = string
}

variable "architecture" {
  type    = string
  default = "x86"
  validation {
    condition     = can(regex("^(x86|arm)$", var.architecture))
    error_message = "architecture must be 'x86' or 'arm'"
  }
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "public_key_openssh" {
  type = string
}

variable "disk_size_gb" {
  type    = number
  default = 30
}

variable "region" {
  type        = string
  description = "Azure region must be passed in."
}
