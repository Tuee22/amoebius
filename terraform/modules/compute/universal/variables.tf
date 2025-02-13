variable "availability_zones" {
  type = list(string)
  description = "Must be passed from the cluster module or user."
}

variable "instance_groups" {
  type = list(object({
    name           = string
    architecture   = string
    size           = string
    count_per_zone = number
  }))
  description = "If empty, cluster might set a default. No defaults here."
}

variable "instance_type_map" {
  type = map(string)
  description = "Map from e.g. 'x86_small' => 't3.micro'. Must be passed in."
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "disk_size_gb" {
  type    = number
  default = 30
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
  default = true
}

variable "region" {
  type = string
  description = "Region for the single_vm modules."
}

variable "provider" {
  type = string
  description = "Used by the single_vm submodule path and by ssh_vm_secret."
}
