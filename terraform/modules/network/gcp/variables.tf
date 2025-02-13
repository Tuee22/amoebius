variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  default     = ["us-central1-a", "us-central1-b", "us-central1-f"]
}
