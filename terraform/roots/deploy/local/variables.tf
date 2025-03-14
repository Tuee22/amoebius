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
  default     = "~/amoebius/data/kind-data"
}

variable "amoebius_dir" {
  description = "Amoebius directory path"
  type        = string
  default     = "~/amoebius"
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
If true, use 'amoebius:local' as the image and run 'kind load docker-image'
via a null_resource. The assumption is that you've already built the image
locally (e.g. via docker build -t amoebius:local ...).
EOT
  type    = bool
  default = false
}

variable "local_docker_image_tag" {
  description = "Local Docker image tag to use if local_build_enabled is true"
  type        = string
  default     = "amoebius:local"
}