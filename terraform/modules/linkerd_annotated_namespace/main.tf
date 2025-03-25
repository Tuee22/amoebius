#####################################################################
# main.tf
#####################################################################
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25.1"
    }
  }
}

# Local K8s provider (no load_config_file argument)
# provider "kubernetes" {
#   host                   = var.host
#   cluster_ca_certificate = var.cluster_ca_certificate
#   client_certificate     = var.client_certificate
#   client_key             = var.client_key

#   # If using self-signed cert, optionally:
#   # insecure = true
# }

#####################################################################
# 1) Possibly create the namespace
#####################################################################
resource "kubernetes_namespace" "this" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace

    annotations = var.linkerd_inject ? {
      "linkerd.io/inject" = "enabled"
    } : {}

    labels = var.labels
  }
}

#####################################################################
# 2) Linkerd Server resource
#####################################################################
resource "kubernetes_manifest" "linkerd_server" {
  count = var.apply_linkerd_policy ? 1 : 0

  manifest = {
    apiVersion = "policy.linkerd.io/v1beta1"
    kind       = "Server"
    metadata = {
      name      = var.server_name
      namespace = var.namespace
    }
    spec = {
      podSelector   = {}
      port          = var.server_port_range
      proxyProtocol = var.proxy_protocol
    }
  }

  depends_on = [
    kubernetes_namespace.this
  ]
}

#####################################################################
# 3) Linkerd ServerAuthorization
#####################################################################
resource "kubernetes_manifest" "linkerd_server_auth" {
  count = var.apply_linkerd_policy ? 1 : 0

  manifest = {
    apiVersion = "policy.linkerd.io/v1beta1"
    kind       = "ServerAuthorization"
    metadata = {
      name      = "mesh-only"
      namespace = var.namespace
    }
    spec = {
      server = {
        name = var.server_name
      }
      client = {
        meshTLS = {
          identities = []
        }
      }
    }
  }

  depends_on = [
    kubernetes_manifest.linkerd_server
  ]
}