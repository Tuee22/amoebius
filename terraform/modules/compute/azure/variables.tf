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
  description = "Custom or default image ID"
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

# For real usage, we need the resource group name, so let's accept that:
variable "resource_group_name" {
  type        = string
  description = "Azure resource group name to place this VM"
}
