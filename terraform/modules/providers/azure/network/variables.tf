variable "region" {
  type        = string
  description = "Azure region, e.g. eastus"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for Azure vnet"
}

variable "availability_zones" {
  type        = list(string)
  default     = []
}
