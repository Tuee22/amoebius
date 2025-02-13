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
  type    = string
  default = ""
  # The cluster module sets a real default or passes a custom override
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

output "vm_name" {
  value = var.vm_name
}

output "private_ip" {
  value = "UNIMPLEMENTED"
}

output "public_ip" {
  value = "UNIMPLEMENTED"
}

