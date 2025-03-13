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
  description = "Amoebius directory path to mount into the container"
  type        = string
  default     = "~/amoebius"
}