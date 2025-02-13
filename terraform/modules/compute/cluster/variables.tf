variable "provider" {
  type        = string
  description = "Which cloud provider: 'aws', 'azure', or 'gcp'?"
}

variable "region" {
  type        = string
  default     = ""
  description = "Optional region (if needed) for data sources. Or read from env. For AWS or Azure."
}

variable "availability_zones" {
  type        = list(string)
  default     = []
  description = "List of zones (like [\"us-east-1a\",\"us-east-1b\"] or [\"1\",\"2\",\"3\"] or [\"us-central1-a\"])."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs (AWS/Azure) or self_links (GCP). Must match availability_zones order."
}

variable "security_group_id" {
  type        = string
  description = "Security group or firewall allowing SSH."
}

variable "instance_groups" {
  type = list(object({
    name           = string
    category       = string   # e.g. 'arm_small','x86_small','nvidia_medium', etc.
    count_per_zone = number

    # Optional custom image override
    image = optional(string, "")
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
