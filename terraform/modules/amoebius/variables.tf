variable "namespace" {
  description = "Namespace where Amoebius should be deployed (already exists)."
  type        = string
  default     = "amoebius"
}

variable "amoebius_image" {
  description = "Docker image for the Amoebius container"
  type        = string
  default     = "tuee22/amoebius:latest"
}

variable "mount_docker_socket" {
  description = "Whether to mount /var/run/docker.sock into the Amoebius container"
  type        = bool
  default     = true
}