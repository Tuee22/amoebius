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

variable "dockerhub_username" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Optional DockerHub username for registry-creds & in-pod Docker CLI"
}

variable "dockerhub_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Optional DockerHub password/token for registry-creds & in-pod Docker CLI"
}

variable "registry_creds_chart_version" {
  type        = string
  default     = "1.3.0"
  description = "Which version of the registry-creds Helm chart to install."
}

variable "dockerhub_secret_name" {
  type        = string
  default     = "amoebius-dockerhub-cred"
  description = <<EOT
Which name to give our Docker config secret for the amoebius namespace.
Must match volume->secret_name in the StatefulSet spec.
EOT
}