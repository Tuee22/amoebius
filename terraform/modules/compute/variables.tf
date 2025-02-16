###############################################
# /amoebius/terraform/modules/compute/variables.tf
###############################################

# Rename 'provider' to 'cloud_provider'
variable "cloud_provider" {
  type = string
  description = "Which cloud provider to use: 'aws', 'azure', or 'gcp'."
}

variable "vm_name" {
  type        = string
  description = "Name for the VM instance."
}

variable "public_key_openssh" {
  type        = string
  description = "SSH public key in OpenSSH format."
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "image" {
  type        = string
  description = "AMI/image to use (passed from the cluster or root)."
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type        = string
  description = "Subnet or subnetwork to place this VM in."
}

variable "security_group_id" {
  type        = string
  description = "Security group or firewall ID."
}

variable "zone" {
  type        = string
  description = "Which AZ or zone to deploy in."
}

variable "workspace" {
  type    = string
  default = "default"
}

# If Azure, we might need these:
variable "resource_group_name" {
  type    = string
  default = ""
}

variable "location" {
  type    = string
  default = ""
}
