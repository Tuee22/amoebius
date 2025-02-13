variable "region" {
  type        = string
  description = "Azure region."
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  default     = []
}
