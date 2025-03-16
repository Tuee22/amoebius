#########################################
# Variables for the Kind cluster module
#########################################

variable "cluster_name" {
  description = "Name of the Kind cluster"
  type        = string
}

variable "data_dir" {
  description = "Data directory for Kind's persistent data"
  type        = string
}

variable "amoebius_dir" {
  description = "Path to mount the Amoebius project dir into the Kind node"
  type        = string
}

variable "mount_docker_socket" {
  description = "If true, mount /var/run/docker.sock into the Kind container"
  type        = bool
}
