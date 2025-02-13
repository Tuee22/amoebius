variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "AWS zones e.g. [\"us-east-1a\",\"us-east-1b\"]."
}

variable "region" {
  type        = string
  description = "AWS region, e.g. us-east-1. Must be set explicitly."
}
