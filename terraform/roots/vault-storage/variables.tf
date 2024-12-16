variable "vault_namespace" {
  description = "Kubernetes namespace for Vault"
  type        = string
  default     = "vault"
}

variable "cluster_name" {
  description = "Name of the cluster node for PV affinity"
  type        = string
  default     = "kind-cluster"
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

variable "vault_replicas" {
  description = "Number of Vault replicas"
  type        = number
  default     = 3
}
