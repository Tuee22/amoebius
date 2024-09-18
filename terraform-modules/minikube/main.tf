terraform {
  required_providers {
    minikube = {
      source  = "scott-the-programmer/minikube"
      version = "0.4.0"
    }
  }
}

provider "minikube" {
  kubernetes_version = "v1.31.0"
}

# Main Minikube cluster resource
resource "minikube_cluster" "terraform-cluster" {
  driver       = "docker"
  cluster_name = var.cluster_name
  addons       = ["default-storageclass", "storage-provisioner"]
}

# This resource starts Minikube and mounts storage into the minikube container (idempotent after restart)
# NB: the stop/start is to ensure a previous mount isn't still active when we create a new mount 
resource "null_resource" "start_minikube" {
  depends_on = [minikube_cluster.terraform-cluster]

  provisioner "local-exec" {
    command = <<-EOF
      minikube -p ${var.cluster_name} stop
      minikube -p ${var.cluster_name} start
      nohup minikube mount -p ${var.cluster_name} ${var.local_folder}:${var.mount_folder} > minikube-mount.log 2>&1 &
    EOF
  }
  
  // trigger so we always restart and mount minikube on terraform apply
  triggers = {
    start_minikube = "${timestamp()}"
  }
}