#####################################################################
# variables.tf
#####################################################################
variable "cluster_name" {
  description = "Name of the Kind cluster"
  type        = string
  default     = "kind-cluster"
}

variable "data_dir" {
  description = "Path on the host for persistent data"
  type        = string
  default     = "../../../../data/kind-data"
}

variable "amoebius_dir" {
  description = "Path to mount the Amoebius project dir into the Kind node"
  type        = string
  default     = "../../../../"
}

variable "mount_docker_socket" {
  description = "If true, mount /var/run/docker.sock into the Kind container"
  type        = bool
  default     = false
}

variable "dockerhub_username" {
  description = "DockerHub username (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "dockerhub_password" {
  description = "DockerHub password/token (optional)"
  type        = string
  sensitive   = true
  default     = ""
}