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
  description = "Docker image for Amoebius"
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