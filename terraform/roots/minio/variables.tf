variable "cluster_name" {
  type    = string
  default = "kind-cluster"
}

variable "minio_namespace" {
  type    = string
  default = "minio"
}

variable "storage_class_name" {
  type    = string
  default = "minio"
}

variable "minio_storage_size" {
  type    = string
  default = "1Gi"
}

variable "minio_replicas" {
  type    = number
  default = 1
}

variable "minio_release_name" {
  type    = string
  default = "minio"
}

variable "minio_helm_chart_version" {
  type    = string
  default = "5.0.7"
}

variable "minio_root_user" {
  type    = string
  default = "minio"
}

variable "minio_root_password" {
  type    = string
  default = "minio123"
}

variable "vault_addr" {
  type        = string
  description = "Vault address for KMS (http://vault...:8200)"
  default     = "http://vault.amoebius.svc.cluster.local:8200"
}

variable "minio_vault_key" {
  type        = string
  description = "Name of the transit key in Vault for MinIO encryption"
  default     = "minio-key"
}
