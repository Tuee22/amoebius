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

variable "image" {
  type    = string
  default = ""
  # If empty, we'll use a default Ubuntu 24.04 for Azure
}

variable "ssh_user" {
  type    = string
  default = "azureuser"
}

variable "zone" {
  type    = string
  default = "1"
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "workspace" {
  type    = string
  default = "default"
}
