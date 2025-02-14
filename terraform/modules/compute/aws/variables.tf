variable "vm_name" {
  type = string
}

variable "public_key_openssh" {
  type = string
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "image" {
  type        = string
  description = "AMI override"
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

variable "zone" {
  type = string
}

variable "workspace" {
  type    = string
  default = "default"
}
