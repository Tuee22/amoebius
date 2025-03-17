#######################################
# KIND + AMOEBIUS VARIABLES
#######################################

variable "cluster_name" {
  description = "Name of the Kind cluster"
  type        = string
  default     = "kind-cluster"
}

variable "data_dir" {
  description = "Data directory for Kind"
  type        = string
  default     = "/amoebius/data/kind-in-amoebius-data"
}

variable "amoebius_dir" {
  description = "Amoebius directory path"
  type        = string
  default     = "/amoebius"
}

variable "amoebius_image" {
  description = "Docker image for Amoebius (DockerHub path if not local build)"
  type        = string
  default     = "tuee22/amoebius:latest"
}

variable "namespace" {
  description = "Kubernetes namespace to deploy Amoebius into"
  type        = string
  default     = "amoebius"
}

variable "apply_linkerd_policy" {
  description = "Whether to apply Linkerd policy annotation in the namespace"
  type        = bool
  default     = false
}

#######################################
# LOCAL BUILD LOGIC
#######################################
variable "local_build_enabled" {
  description = <<EOT
If true, we assume a local Docker image tag 'amoebius:local' has been built.
We will load that image into Kind using `kind load docker-image`.
EOT
  type    = bool
  default = true
}

variable "local_docker_image_tag" {
  description = "Local Docker image tag to use if local_build_enabled is true"
  type        = string
  default     = "amoebius:local"
}

#######################################
# DOCKER SOCKET MOUNT
#######################################
variable "mount_docker_socket" {
  description = "Whether to mount /var/run/docker.sock in the container that runs Kind."
  type        = bool
  default     = true
}