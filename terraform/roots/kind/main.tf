terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20.0"
    }
  }
}

provider "kind" {}

locals {
  home_dir = pathexpand("~")
  data_dir = "${local.home_dir}/data/kind"
}

resource "kind_cluster" "default" {
  name           = "kind-cluster"  # Changed from "my-cluster" to "kind-cluster"
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
      extra_mounts {
        host_path      = local.data_dir
        container_path = "/mnt/data"
      }
    }
  }
}

provider "kubernetes" {
  host                   = kind_cluster.default.endpoint
  cluster_ca_certificate = kind_cluster.default.cluster_ca_certificate
  client_certificate     = kind_cluster.default.client_certificate
  client_key             = kind_cluster.default.client_key
}

resource "kubernetes_persistent_volume" "example" {
  metadata {
    name = "local-pv"
  }
  spec {
    capacity = {
      storage = "5Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_source {
      host_path {
        path = "/mnt/data"
        type = "DirectoryOrCreate"
      }
    }
    storage_class_name = "standard"
  }

  depends_on = [kind_cluster.default]
}

resource "kubernetes_persistent_volume_claim" "example" {
  metadata {
    name = "local-pvc"
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
    volume_name = kubernetes_persistent_volume.example.metadata[0].name
  }

  depends_on = [kubernetes_persistent_volume.example]
}

resource "kubernetes_pod" "ubuntu" {
  metadata {
    name = "ubuntu-pod"
  }
  spec {
    container {
      image = "ubuntu:22.04"
      name  = "ubuntu"
      
      command = ["/bin/sleep", "3650d"]
      
      volume_mount {
        name       = "local-storage"
        mount_path = "/home/ubuntu/data"
      }
    }

    volume {
      name = "local-storage"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.example.metadata[0].name
      }
    }
  }

  depends_on = [kubernetes_persistent_volume_claim.example]
}