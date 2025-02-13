variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "GCP zones, e.g. [\"us-central1-a\",\"us-central1-b\"]."
}

variable "region" {
  type        = string
  description = "GCP region, e.g. us-central1. Must be set explicitly."
}
