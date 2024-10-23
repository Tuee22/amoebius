
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

variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "vault_namespace" {
  description = "Kubernetes namespace for Vault"
  type        = string
  default     = "vault"
}

variable "storage_class_name" {
  description = "Name of the Kubernetes storage class"
  type        = string
  default     = "vault-storage"
}

variable "vault_storage_size" {
  description = "Size of the Vault storage"
  type        = string
  default     = "1Gi"
}

variable "vault_helm_chart_version" {
  description = "Version of the Vault Helm chart"
  type        = string
  default     = "0.23.0"
}

variable "vault_replicas" {
  description = "Number of Vault replicas"
  type        = number
  default     = 3
}

variable "vault_service_name" {
  description = "Name of the Vault service"
  type        = string
  default     = "vault"
}

variable "vault_values" {
  description = "Values for the Vault Helm chart"
  type        = map(any)
  default     = {
    "server.ha.enabled"             = "true"
    "server.ha.raft.enabled"        = "true"
    "server.dataStorage.enabled"    = "true"
    "injector.enabled"              = "true"
    "server.dataStorage.accessMode" = "ReadWriteOnce"
    "server.affinity"               = ""
  }
}

