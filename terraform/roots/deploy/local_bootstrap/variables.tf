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
  default     = "../../../../data/kind-data"
}

variable "amoebius_dir" {
  description = "Amoebius directory path"
  type        = string
  default     = "../../../../"
}

variable "amoebius_image" {
  description = "Docker image for Amoebius"
  type        = string
  default     = "tuee22/amoebius:0.0.1"
}

variable "namespace" {
  description = "Kubernetes namespace to deploy Amoebius"
  type        = string
  default     = "amoebius"
}

variable "apply_linkerd_policy" {
  description = "Whether to apply Linkerd policy in the namespace"
  type        = bool
  default     = false
}

#######################################
# LOCAL BUILD LOGIC
#######################################
variable "local_build_enabled" {
  type        = bool
  default     = false
  description = "If true, load a local Docker image into Kind"
}

variable "local_docker_image_tag" {
  type        = string
  default     = "amoebius:local"
  description = "Local Docker image tag if local_build_enabled is true"
}

#######################################
# DOCKER SOCKET MOUNT
#######################################
variable "mount_docker_socket" {
  type        = bool
  default     = false
  description = "Whether to mount /var/run/docker.sock in the container that runs Kind."
}

#######################################
# REGISTRY CREDS
#######################################
variable "dockerhub_username" {
  type        = string
  sensitive   = true
  default     = ""
  description = "DockerHub username (leave blank for anonymous)."
}

variable "dockerhub_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "DockerHub password/token (leave blank for anonymous)."
}
