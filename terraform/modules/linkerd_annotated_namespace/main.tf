###################################################
# 1. (Optional) Create Namespace with Linkerd Injection
###################################################
resource "kubernetes_namespace" "this" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace_name

    # Annotate for Linkerd injection if enabled
    annotations = var.linkerd_inject ? {
      "linkerd.io/inject" = "enabled"
    } : {}

    labels = var.labels
  }
}

###################################################
# 2. (Optional) Create Server + ServerAuthorization (Policy)
###################################################
resource "kubernetes_manifest" "linkerd_server" {
  count = var.apply_linkerd_policy ? 1 : 0

  manifest = yamlencode({
    apiVersion = "policy.linkerd.io/v1beta1"
    kind       = "Server"
    metadata = {
      name      = var.server_name
      namespace = var.namespace_name
    }
    spec = {
      # matches all pods in this namespace (empty podSelector)
      podSelector    = {}
      port           = var.server_port
      proxyProtocol  = var.proxy_protocol
    }
  })

  depends_on = [
    # Make sure the namespace is created before applying this resource
    kubernetes_namespace.this
  ]
}

resource "kubernetes_manifest" "linkerd_server_authz" {
  count = var.apply_linkerd_policy ? 1 : 0

  manifest = yamlencode({
    apiVersion = "policy.linkerd.io/v1beta1"
    kind       = "ServerAuthorization"
    metadata = {
      name      = "mesh-only"
      namespace = var.namespace_name
    }
    spec = {
      server = {
        name = var.server_name
      }
      client = {
        meshTLS = {
          # identities = [] => empty means any Linkerd identity is allowed
          # i.e. only Linkerd-injected pods with valid identity are allowed
          identities = []
        }
      }
    }
  })

  depends_on = [
    kubernetes_manifest.linkerd_server
  ]
}
