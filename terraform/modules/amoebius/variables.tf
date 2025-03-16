variable "host" {
  description = "Kubernetes API endpoint"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "CA cert for the Kubernetes cluster"
  type        = string
  sensitive   = true
}

variable "client_certificate" {
  description = "Client cert for authenticating with cluster"
  type        = string
  sensitive   = true
}

variable "client_key" {
  description = "Client key for authenticating with cluster"
  type        = string
  sensitive   = true
}

variable "namespace" {
  description = "Namespace where Amoebius should be deployed"
  type        = string
  default     = "amoebius"
}

variable "amoebius_image" {
  description = "Docker image for the Amoebius container"
  type        = string
  default     = "tuee22/amoebius:latest"
}

variable "apply_linkerd_policy" {
  description = "Set to true if linkerd policy annotation is needed"
  type        = bool
  default     = false
}

variable "mount_docker_socket" {
  description = "Whether to mount /var/run/docker.sock into the Amoebius container"
  type        = bool
  default     = true
}
