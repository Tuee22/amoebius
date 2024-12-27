variable "cluster_name" {
  description = "Kubernetes namespace for Vault"
  type        = string
  default     = "kind-cluster"
}

variable "vault_namespace" {
  description = "Kubernetes namespace for Vault"
  type        = string
  default     = "vault"
}

variable "vault_service_name" {
  description = "Name of the Vault service"
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
  default     = "0.29.1"
}

variable "vault_replicas" {
  description = "Number of Vault replicas"
  type        = number
  default     = 1
}

variable "vault_values" {
  description = "Values for the Vault Helm chart"
  type        = map(any)
  default     = {
    "server.ha.enabled"             = "true"
    "server.ha.raft.enabled"        = "true"
    "server.dataStorage.enabled"    = "true"
    "injector.enabled"              = "true"
    "server.serviceAccount.create"  = "false"
    "server.dataStorage.accessMode" = "ReadWriteOnce"
    "server.affinity"               = ""
  }
}