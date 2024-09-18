variable "cluster_name" {
  description = "The name of the Minikube cluster"
  type        = string
  default     = "terraform-cluster"
}

variable "local_folder" {
  description = "The local folder to mount into Minikube"
  type        = string 
}

variable "mount_folder" {
  description = "The data folder within the minikube env"
  type        = string
  default     = "/data"
}