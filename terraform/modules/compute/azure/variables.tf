variable "vm_name" {
  type = string
}

variable "public_key_openssh" {
  type = string
}

variable "ssh_user" {
  type    = string
  default = "azureuser"
}

variable "image" {
  type        = string
  description = "Azure image (or shared gallery ID)"
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

variable "resource_group_name" {
  type        = string
  description = "Resource group name in which to place this VM"
}
