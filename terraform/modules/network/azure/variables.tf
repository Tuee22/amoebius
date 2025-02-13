variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "Azure zones, e.g. [\"1\",\"2\",\"3\"]."
}

variable "region" {
  type        = string
  description = "Azure region, e.g. eastus. Must be set explicitly."
}
