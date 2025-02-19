variable "region" {
  type        = string
  description = "GCP region, e.g. us-central1"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for GCP VPC"
}

variable "availability_zones" {
  type        = list(string)
  default     = []
}
