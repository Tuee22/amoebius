variable "region" {
  type        = string
  description = "AWS region."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the AWS VPC."
}

variable "availability_zones" {
  type        = list(string)
  default     = []
  description = "List of AZs for AWS."
}
