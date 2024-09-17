terraform {
  required_providers {
    minikube = {
      source = "scott-the-programmer/minikube"
      version = "0.4.0"
    }
  }
}

provider "minikube" {
  kubernetes_version = "v1.30.0"
}

resource "minikube_cluster" "terraform-cluster" {
  driver       = "docker"
  cluster_name = var.cluster_name
}

resource "null_resource" "minikube_mount" {
  depends_on = [minikube_cluster.terraform-cluster]

  provisioner "local-exec" {
    command = "nohup minikube mount -p ${var.cluster_name} ${var.local_folder}:/data > minikube-mount.log 2>&1 &"
  }
}

provider "kubernetes" {
  host = minikube_cluster.terraform-cluster.host

  client_certificate     = minikube_cluster.terraform-cluster.client_certificate
  client_key             = minikube_cluster.terraform-cluster.client_key
  cluster_ca_certificate = minikube_cluster.terraform-cluster.cluster_ca_certificate
}