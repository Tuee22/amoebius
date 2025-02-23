variable "storage_class_name" {
  type        = string
  description = "Name of the storage class to create."
}

variable "pvc_name_prefix" {
  type        = string
  default     = "data-vault"
  description = "Prefix for the PVC names referenced by claim_ref in each PV."
}

variable "volume_binding_mode" {
  type        = string
  default     = "WaitForFirstConsumer"
  description = "Volume binding mode for the storage class."
}

variable "reclaim_policy" {
  type        = string
  default     = "Retain"
  description = "Reclaim policy for the storage class."
}

variable "volumes_count" {
  type        = number
  default     = 3
  description = "Number of persistent volumes to create."
}

variable "namespace" {
  type        = string
  default     = "vault"
  description = "Namespace where the PVC lives (claimRef.namespace)."
}

variable "storage_size" {
  type        = string
  default     = "1Gi"
  description = "Size of each persistent volume."
}

variable "base_host_path" {
  type        = string
  default     = "/persistent-data"
  description = "Base path on the host for local PVs."
}

variable "node_affinity_key" {
  type        = string
  default     = "kubernetes.io/hostname"
  description = "Node label key for PV node affinity."
}

variable "node_affinity_values" {
  type        = list(string)
  default     = ["kind-cluster-control-plane"]
  description = "List of node label values for PV node affinity."
}
