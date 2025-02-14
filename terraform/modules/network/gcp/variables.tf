variable "region" {
  type        = string
  description = "GCP region, e.g. us-central1"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  default     = []
}
