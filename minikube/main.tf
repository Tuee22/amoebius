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

# This resource starts Minikube (idempotent)
resource "null_resource" "start_minikube" {
  depends_on = [minikube_cluster.terraform-cluster]

  provisioner "local-exec" {
    # Start Minikube
    command = "minikube start -p ${var.cluster_name}"
  }

  triggers = {
    start_minikube = "${timestamp()}"
  }
}

# This resource ensures the minikube mount command is run after the cluster starts or restarts  (idempotent)
resource "null_resource" "minikube_mount" {
  depends_on = [
    minikube_cluster.terraform-cluster,
    null_resource.start_minikube
  ]

  provisioner "local-exec" {
    # Run the mount command after Minikube starts
    command = <<EOT
      nohup minikube mount -p ${var.cluster_name} ${var.local_folder}:${var.mount_folder} > minikube-mount.log 2>&1 &
    EOT
  }

  triggers = {
    mount = "${timestamp()}"
  }
}

provider "kubernetes" {
  host = minikube_cluster.terraform-cluster.host
  client_certificate     = minikube_cluster.terraform-cluster.client_certificate
  client_key             = minikube_cluster.terraform-cluster.client_key
  cluster_ca_certificate = minikube_cluster.terraform-cluster.cluster_ca_certificate
}
