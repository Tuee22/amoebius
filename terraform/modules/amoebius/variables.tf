#####################################################################
# modules/amoebius/variables.tf
#####################################################################

variable "namespace" {
  description = "Namespace where Amoebius should be deployed (already exists)."
  type        = string
  default     = "amoebius"
}

variable "amoebius_image" {
  description = "Docker image for the Amoebius container"
  type        = string
  default     = "tuee22/amoebius:0.0.1"
}

variable "mount_docker_socket" {
  description = "Whether to mount /var/run/docker.sock into the Amoebius container"
  type        = bool
  default     = false
}

variable "dockerhub_username" {
  description = <<EOT
DockerHub username (leave blank for unauthenticated pulls).
If non-blank (and password is also set),
we install registry-creds and create a secret for in-container Docker CLI usage.
EOT
  type        = string
  sensitive   = true
  default     = ""
}

variable "dockerhub_password" {
  description = "DockerHub password/token (leave blank for unauthenticated pulls)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "registry_creds_chart_version" {
  description = "Which version of the registry-creds Helm chart to install."
  type        = string
  default     = "1.3.0"
}