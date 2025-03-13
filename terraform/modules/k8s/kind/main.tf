# This module deploys a Kind cluster using the 'kind_cluster' resource
# from the 'tehcyx/kind' provider. Typically, you would define the
# provider block in the *root* module or pass it in via the "providers" argument.
# For self-containment, it is shown here; adapt to your usage as needed.

terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.2.1"
    }
  }
}

resource "kind_cluster" "default" {
  name           = var.cluster_name
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
      extra_mounts {
        host_path      = pathexpand(var.data_dir)
        container_path = "/persistent-data"
      }
      extra_mounts {
        host_path      = pathexpand(var.amoebius_dir)
        container_path = "/amoebius"
      }
    }
  }
}