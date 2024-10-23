
variable "kind_version" {
  description = "Version of the Kind provider"
  type        = string
  default     = "~> 0.2.0"
}

variable "kubernetes_version" {
  description = "Version of the Kubernetes provider"
  type        = string
  default     = "~> 2.20.0"
}

variable "helm_version" {
  description = "Version of the Helm provider"
  type        = string
  default     = "~> 2.9.0"
}

variable "cluster_name" {
  description = "Name of the Kind cluster"
  type        = string
  default     = "kind-cluster"
}

variable "data_dir" {
  description = "Data directory for Kind"
  type        = string
  default     = "~/.local/share/kind-data"
}

variable "amoebius_dir" {
  description = "Amoebius directory path"
  type        = string
  default     = "~/amoebius"
}

variable "amoebius_image" {
  description = "Docker image for the script runner"
  type        = string
  default     = "tuee22/amoebius:latest"
}