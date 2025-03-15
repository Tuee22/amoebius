terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.2.1"
    }
  }
}

locals {
  default_mounts = [
    {
      host_path      = pathexpand(var.data_dir)
      container_path = "/persistent-data"
    },
    {
      host_path      = pathexpand(var.amoebius_dir)
      container_path = "/amoebius"
    }
  ]

  docker_socket_mount = [
    {
      host_path      = "/var/run/docker.sock"
      container_path = "/var/run/docker.sock"
    }
  ]

  combined_mounts = var.mount_docker_socket ? concat(local.default_mounts, local.docker_socket_mount) : local.default_mounts
}

resource kind_cluster default {
  name           = var.cluster_name
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role         = "control-plane"
      extra_mounts = local.combined_mounts
    }
  }
}