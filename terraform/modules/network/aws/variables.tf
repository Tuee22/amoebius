variable "region" {
  type        = string
  description = "AWS region."
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  default     = []
  description = "List of AZs in this region."
}
