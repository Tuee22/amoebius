variable "provider" {
  type        = string
  description = "Which provider (aws, azure, gcp)?"
}

variable "vm_name" {
  type        = string
  description = "Name for the VM instance"
}

variable "public_key_openssh" {
  type        = string
  description = "SSH public key in OpenSSH format"
}

variable "ssh_user" {
  type        = string
  default     = "ubuntu"
}

variable "image" {
  type        = string
  description = "Image/AMI to use"
}

variable "instance_type" {
  type        = string
}

variable "subnet_id" {
  type        = string
  description = "Subnet or subnetwork to place this VM"
}

variable "security_group_id" {
  type        = string
  description = "Security group or firewall ID"
}

variable "zone" {
  type        = string
  description = "Which zone or AZ"
}

variable "workspace" {
  type        = string
  default     = "default"
}

# For Azure only, we might need a resource_group_name, location
variable "resource_group_name" {
  type        = string
  default     = ""
}

variable "location" {
  type        = string
  default     = ""
}

