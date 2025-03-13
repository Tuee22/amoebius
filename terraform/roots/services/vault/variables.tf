variable "cluster_name" {
  description = "Kubernetes cluster name (used for node_affinity)."
  type        = string
  default     = "kind-cluster"
}

variable "vault_namespace" {
  description = "Kubernetes namespace for Vault"
  type        = string
  default     = "vault"
}

variable "vault_service_name" {
  description = "Name of the Vault service (Helm release name)."
  type        = string
  default     = "vault"
}

variable "storage_class_name" {
  description = "Name of the Kubernetes storage class"
  type        = string
  default     = "vault"
}

variable "pvc_name_prefix" {
  description = "Prefix for the Vault PVC name each PV will bind to (e.g. data-vault-0)."
  type        = string
  default     = "data-vault"
}

variable "vault_storage_size" {
  description = "Size of each Vault persistent volume"
  type        = string
  default     = "1Gi"
}

variable "vault_helm_chart_version" {
  description = "Version of the Vault Helm chart"
  type        = string
  default     = "0.29.1"
}

variable "vault_replicas" {
  description = "Number of Vault replicas to run (raft HA)."
  type        = number
  default     = 3
}

variable "vault_values" {
  description = "Key/value map for dynamic 'helm_release.vault' .set blocks"
  type        = map(any)
  default     = {
    "server.ha.enabled"             = "true"
    "server.ha.raft.enabled"        = "true"
    "server.dataStorage.enabled"    = "true"
    "injector.enabled"              = "false"
    "server.serviceAccount.create"  = "false"
    "server.dataStorage.accessMode" = "ReadWriteOnce"
    "server.affinity"               = ""
    "global.tlsDisable"             = "true"
  }
}
