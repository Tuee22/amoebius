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
variable "script_runner_image" {
  description = "Docker image for the script runner"
  type        = string
  default     = "python:3.11-alpine"
}
variable "vault_service_name" {
  description = "Name of the Vault service"
  type        = string
  default     = "vault"
}
variable "port_forwards" {
  description = "List of port forwarding configurations"
  type = list(object({
    service_name = string
    namespace    = string
    local_port   = number
    remote_port  = number
  }))
  default = [
    {
      service_name = "vault"
      namespace    = "vault"
      local_port   = 8200
      remote_port  = 8200
    }
    # Add more port forwards as needed
  ]
}