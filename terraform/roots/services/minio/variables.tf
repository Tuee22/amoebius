###############################################################################
# /amoebius/terraform/roots/minio/variables.tf
###############################################################################
variable "root_user" {
  type        = string
  description = "Minio root user"
}

variable "root_password" {
  type        = string
  description = "Minio root password"
  sensitive   = true
}