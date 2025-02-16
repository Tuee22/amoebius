variable "cloud_provider" {
  type        = string
  description = "aws, azure, or gcp"
}

variable "vm_name" {
  type        = string
  description = "VM instance name"
}

variable "public_key_openssh" {
  type        = string
  description = "SSH public key"
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "image" {
  type        = string
  description = "Image/AMI"
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type        = string
  description = "Subnet or subnetwork"
}

variable "security_group_id" {
  type        = string
  description = "Security group / firewall"
}

variable "zone" {
  type        = string
  description = "AZ or zone"
}

variable "workspace" {
  type    = string
  default = "default"
}

variable "resource_group_name" {
  type    = string
  default = ""
}

variable "location" {
  type    = string
  default = ""
}
