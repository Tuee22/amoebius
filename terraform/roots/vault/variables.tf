variable "vault_namespace" {
  default = "vault"
}
variable "cluster_name" {
  default = "kind-cluster"
}
variable "storage_class_name" {
  default = "vault-storage"
}
variable "vault_storage_size" {
  default = "1Gi"
}
variable "vault_replicas" {
  default = 3
}