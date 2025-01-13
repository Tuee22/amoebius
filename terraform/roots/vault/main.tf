terraform {
  backend "kubernetes" {
    secret_suffix     = "vault"
    load_config_file  = false
    namespace         = "amoebius"
    in_cluster_config = true
  }
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }  
}

provider "kubernetes" {
  host                   = ""
  cluster_ca_certificate = ""
  token                  = ""
}

resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.vault_namespace
  }
}

resource "kubernetes_storage_class" "hostpath_storage_class" {
  metadata {
    name = var.storage_class_name
  }
  storage_provisioner = "kubernetes.io/no-provisioner"
  volume_binding_mode  = "WaitForFirstConsumer"
  reclaim_policy       = "Retain"
}

resource "kubernetes_persistent_volume" "vault_storage" {
  for_each = { for idx in range(var.vault_replicas) : idx => idx }

  metadata {
    name = "${var.vault_namespace}-pv-${each.key}"
    labels = {
      pvIndex = "${each.key}"
    }
  }

  spec {
    capacity = {
      storage = var.vault_storage_size
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.hostpath_storage_class.metadata[0].name

    claim_ref {
      name      = "${var.pvc_name_prefix}-${each.key}"
      namespace = var.vault_namespace
    }

    persistent_volume_source {
      host_path {
        path = "/persistent-data/vault/vault-${each.key}"
        type = "DirectoryOrCreate"
      }
    }

    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key      = "kubernetes.io/hostname"
            operator = "In"
            values   = ["${var.cluster_name}-control-plane"]
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_storage_class.hostpath_storage_class
  ]
}

resource "kubernetes_service_account_v1" "vault_service_account" {
  metadata {
    name      = "${var.vault_service_name}-service-account"
    namespace = kubernetes_namespace.vault.metadata[0].name
    labels = {
      "app.kubernetes.io/managed-by" = "Helm"
    }
    annotations = {
      "meta.helm.sh/release-name"      = "vault"
      "meta.helm.sh/release-namespace" = "vault"
    }
  }
  automount_service_account_token = true
}

resource "kubernetes_cluster_role" "vault_cluster_role" {
  metadata {
    name = "${var.vault_service_name}-cluster-role"
  }

  rule {
    api_groups = ["authentication.k8s.io"]
    resources  = ["tokenrequests","tokenreviews"]
    verbs      = ["create"]
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get"]
  }
}

resource "kubernetes_cluster_role_binding" "vault_cluster_role_binding" {
  metadata {
    name = "${var.vault_service_name}-cluster-role-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.vault_cluster_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.vault_service_account.metadata[0].name
    namespace = kubernetes_namespace.vault.metadata[0].name
  }
}

resource "kubernetes_manifest" "vault_root_issuer" {
  # This Issuer is purely for generating a one-off self-signed root.
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "Issuer"
    "metadata" = {
      "name"      = "vault-root-selfsigned"
      "namespace" = var.vault_namespace
    }
    "spec" = {
      "selfSigned" = {}
    }
  }
}

resource "kubernetes_manifest" "vault_root_ca_cert" {
  # This is the "root CA" certificate, self-signed.
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "Certificate"
    "metadata" = {
      "name"      = "vault-root-ca-cert"
      "namespace" = var.vault_namespace
    }
    "spec" = {
      "secretName" = "vault-root-ca-secret"
      "isCA"       = true

      # The root is signed by our selfSigned Issuer:
      "issuerRef" = {
        "name" = "vault-root-selfsigned"
        "kind" = "Issuer"
      }

      # Common Name (optional, but recommended):
      "commonName" = "Vault Root CA"
    }
  }

  depends_on = [
    kubernetes_manifest.vault_root_issuer
  ]
}

resource "kubernetes_manifest" "vault_ca_issuer" {
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "Issuer"
    "metadata" = {
      "name"      = "vault-ca-issuer"
      "namespace" = var.vault_namespace
    }
    "spec" = {
      "ca" = {
        # The secret from step #2
        "secretName" = "vault-root-ca-secret"
      }
    }
  }

  depends_on = [
    kubernetes_manifest.vault_root_ca_cert
  ]
}

resource "kubernetes_manifest" "vault_leaf_certificate" {
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "Certificate"
    "metadata"   = {
      "name"      = "vault-leaf-certificate"
      "namespace" = var.vault_namespace
    }
    "spec" = {
      "secretName" = "vault-tls"
      "isCA"        = false

      "issuerRef" = {
        # The CA Issuer from step #3
        "name" = "vault-ca-issuer"
        "kind" = "Issuer"
      }

      # All the DNS names needed for Vault
      "dnsNames" = concat(
        [
          "${var.vault_service_name}.${var.vault_namespace}.svc",
          "${var.vault_service_name}.${var.vault_namespace}.svc.cluster.local"
        ],
        [
          for i in range(var.vault_replicas) : 
          "${var.vault_service_name}-${i}.${var.vault_service_name}-internal.${var.vault_namespace}"
        ],
        [
          for i in range(var.vault_replicas) : 
          "${var.vault_service_name}-${i}.${var.vault_service_name}-internal.${var.vault_namespace}.svc"
        ],
        [
          for i in range(var.vault_replicas) : 
          "${var.vault_service_name}-${i}.${var.vault_service_name}-internal.${var.vault_namespace}.svc.cluster.local"
        ]
      )
    }
  }

  depends_on = [
    kubernetes_manifest.vault_ca_issuer
  ]
}


resource "helm_release" "vault" {
  name       = var.vault_service_name
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = var.vault_helm_chart_version
  namespace  = kubernetes_namespace.vault.metadata[0].name

  dynamic "set" {
    for_each = var.vault_values
    content {
      name  = set.key
      value = set.value
    }
  }

  set {
    name  = "server.dataStorage.size"
    value = var.vault_storage_size
  }

  set {
    name  = "server.dataStorage.storageClass"
    value = kubernetes_storage_class.hostpath_storage_class.metadata[0].name
  }

  set {
    name  = "server.serviceAccount.name"
    value = kubernetes_service_account_v1.vault_service_account.metadata[0].name
  }

  set {
    name  = "server.ha.replicas"
    value = tostring(var.vault_replicas)
  }

  set {
    name  = "global.tlsDisable"
    value = "false"
  }

  set {
    name  = "server.volumes[0].name"
    value = "vault-tls"
  }

  set {
    name  = "server.volumes[0].secret.secretName"
    value = "vault-tls"
  }

  set {
    name  = "server.volumeMounts[0].name"
    value = "vault-tls"
  }

  set {
    name  = "server.volumeMounts[0].mountPath"
    value = "/vault/userconfig/tls"
  }

  set {
    name  = "server.volumeMounts[0].readOnly"
    value = "true"
  }

  set {
    name  = "injector.enabled"
    value = "true"
  }

  set {
    name  = "injector.certs.secretName"
    value = "vault-tls"
  }

  set {
    name  = "server.ha.raft.config"
    value = <<-EOT
      ui = true
      listener "tcp" {
        address          = "[::]:8200"
        cluster_address  = "[::]:8201"
        tls_cert_file    = "/vault/userconfig/tls/tls.crt"
        tls_key_file     = "/vault/userconfig/tls/tls.key"
        tls_client_ca_file = "/vault/userconfig/tls/ca.crt"
      }
      storage "raft" {
        path    = "/vault/data"
        node_id = "{{ .NodeID }}"
        %{for i in range(var.vault_replicas)}
        retry_join {
          leader_api_addr = "https://${var.vault_service_name}-${i}.${var.vault_service_name}-internal.vault.svc.cluster.local:8200"
        }
        %{endfor}
      }
      service_registration "kubernetes" {}
    EOT
  }

  wait = true

  depends_on = [
    kubernetes_persistent_volume.vault_storage,
    kubernetes_namespace.vault,
    kubernetes_manifest.vault_leaf_certificate
  ]
}
