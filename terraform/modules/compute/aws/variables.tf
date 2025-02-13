variable "vm_name" {
  type = string
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

# Each group may have an optional image override
# If empty, we default to Ubuntu 24.04 in us-east-1
variable "image" {
  type    = string
  default = ""
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "zone" {
  type    = string
  default = "us-east-1a"
}

variable "workspace" {
  type    = string
  default = "default"
}
