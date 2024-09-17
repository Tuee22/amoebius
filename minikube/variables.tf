variable "cluster_name" {
  description = "The name of the Minikube cluster"
  type        = string
}

variable "local_folder" {
  description = "The local folder to mount into Minikube"
  type        = string
}
