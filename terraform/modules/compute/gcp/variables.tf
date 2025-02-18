variable "vm_name" {
  description = "The name to assign the VM."
  type        = string
}

variable "public_key_openssh" {
  description = "Public key in OpenSSH format."
  type        = string
}

variable "ssh_user" {
  description = "SSH username."
  type        = string
}

variable "image" {
  description = "AMI / Image reference for the VM."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type, Azure size, or GCP machine type."
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet/vNet subnetwork to place this VM in."
  type        = string
}

variable "security_group_id" {
  description = "ID of the security group / NSG / firewall to use."
  type        = string
}

variable "zone" {
  description = "AZ or zone in which to place the VM."
  type        = string
}

variable "workspace" {
  description = "Terraform workspace name, used to generate resource names."
  type        = string
}

variable "resource_group_name" {
  description = "For Azure usage; can be ignored by AWS/GCP."
  type        = string
  default     = ""
}

variable "location" {
  description = "For Azure usage (location); can be ignored by AWS/GCP."
  type        = string
  default     = ""
}

