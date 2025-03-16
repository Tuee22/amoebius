#########################################
# Variables for the Kind cluster module
#########################################

variable "cluster_name" {
  description = "Name of the Kind cluster"
  type        = string
  default     = "kind-cluster"
}

variable "data_dir" {
  description = "Data directory for Kind's persistent data"
  type        = string
  default     = "~/amoebius/data/kind-data"
}

variable "amoebius_dir" {
  description = "Path to mount the Amoebius project dir into the Kind node"
  type        = string
  default     = "~/amoebius"
}

variable "mount_docker_socket" {
  description = "If true, mount /var/run/docker.sock into the Kind container"
  type        = bool
  default     = true
}
