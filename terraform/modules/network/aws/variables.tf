variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR for AWS VPC."
}

variable "availability_zones" {
  type        = list(string)
  default     = ["us-east-1a","us-east-1b","us-east-1c"]
  description = "List of AZs."
}
