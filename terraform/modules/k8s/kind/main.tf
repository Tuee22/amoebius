#####################################################################
# main.tf
#####################################################################
terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      # Example pinned version that supports containerd_config_patches at cluster level
      version = "0.8.0"
    }
  }
}

locals {
  # Default mounts for data + amoebius dir
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

  # Optional Docker socket mount
  docker_socket_mount = [
    {
      host_path      = "/var/run/docker.sock"
      container_path = "/var/run/docker.sock"
    }
  ]

  # Single-line ternary to avoid parser issues
  combined_mounts = var.mount_docker_socket ? concat(local.default_mounts, local.docker_socket_mount) : local.default_mounts

  # True if DockerHub creds are provided
  dockerhub_enabled = var.dockerhub_username != "" && var.dockerhub_password != ""
}

resource "kind_cluster" "default" {
  name           = var.cluster_name
  wait_for_ready = true

  # Optionally specify a node_image for a certain K8s version:
  node_image = "kindest/node:v1.27.3"

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    ###################################################################
    # containerd_config_patches at the cluster level
    ###################################################################
    containerd_config_patches = local.dockerhub_enabled ? [
      <<-TOML
[plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
  endpoint = ["https://registry-1.docker.io"]

[plugins."io.containerd.grpc.v1.cri".registry.configs."registry-1.docker.io".auth]
  username = "${var.dockerhub_username}"
  password = "${var.dockerhub_password}"
TOML
    ] : []

    node {
      role = "control-plane"

      dynamic "extra_mounts" {
        for_each = local.combined_mounts
        content {
          host_path      = extra_mounts.value.host_path
          container_path = extra_mounts.value.container_path
        }
      }
    }
  }
}