variable "provider" {
  type        = string
  description = "Which cloud provider: 'aws', 'azure', or 'gcp'?"
}

variable "availability_zones" {
  type        = list(string)
  default     = []
  description = "List of zones. E.g. [\"us-east-1a\",\"us-east-1b\"] or [\"1\",\"2\",\"3\"], etc."
}

variable "subnet_ids" {
  type        = list(string)
  description = "One subnet per zone index, from the network module."
}

variable "security_group_id" {
  type        = string
  description = "Security group or firewall that allows SSH."
}

variable "instance_groups" {
  type = list(object({
    name           = string
    category       = string   # e.g. 'arm_small','x86_small','nvidia_medium', etc.
    count_per_zone = number
    image          = optional(string, "")
  }))
  default = []
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "vault_role_name" {
  type    = string
  default = "amoebius-admin-role"
}

variable "no_verify_ssl" {
  type    = bool
  default = false
}
