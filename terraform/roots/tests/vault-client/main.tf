#####################################################
# main.tf
#####################################################

terraform {
  backend "kubernetes" {
    secret_suffix     = "test-vault-client"
    load_config_file  = false
    namespace         = "amoebius"
    in_cluster_config = true
  }

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25.1"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.10"
    }
  }
}

# Let the Vault provider read VAULT_ADDR and VAULT_TOKEN from the environment
provider "vault" {
  # No explicit address/token – will use env vars: VAULT_ADDR, VAULT_TOKEN
}

# Same for Kubernetes – typically uses KUBECONFIG or in-cluster config.
provider "kubernetes" {
  host                   = ""
  token                  = ""
  cluster_ca_certificate = ""
}

module "vault_client_test_namespace" {
  source    = "/amoebius/terraform/modules/linkerd_annotated_namespace"
  namespace = "vault-client-test"
}

#####################################################
# Vault policy allowing read/list on secret/data/vault-client/*
#####################################################
resource "vault_policy" "app_policy" {
  name   = "vault-client-policy"
  policy = <<-HCL
path "secret/data/vault-client/*" {
  capabilities = ["read", "list"]
}
HCL
}

#####################################################
# Create a secret at secret/data/vault-client/hello
#####################################################
resource "vault_kv_secret_v2" "app_secret" {
  mount = "secret"
  name  = "vault-client/hello"

  data_json = jsonencode({
    message = "hello world client"
  })
}

#####################################################
# Create a Kubernetes auth role in Vault
#####################################################
resource "vault_kubernetes_auth_backend_role" "app_role" {
  backend               = "kubernetes"
  role_name             = "vault-client-role"

  bound_service_account_names      = [local.app_sa_name]
  bound_service_account_namespaces = [module.vault_client_test_namespace.namespace]

  token_policies = [
    vault_policy.app_policy.name
  ]
}

#####################################################
# Create the service account
#####################################################
locals {
  app_sa_name = "vault-client-sa"
}

resource "kubernetes_service_account" "app_sa" {
  metadata {
    name      = local.app_sa_name
    namespace = module.vault_client_test_namespace.namespace
  }

  // Insert your secrets here as well
  image_pull_secret {
    name = "gcr-secret"
  }
  image_pull_secret {
    name = "awsecr-cred"
  }
  image_pull_secret {
    name = "dpr-secret"
  }
  image_pull_secret {
    name = "acr-secret"
  }

}

#####################################################
# Deploy the container that runs the vault_client test daemon
#####################################################
resource "kubernetes_deployment" "app_deployment" {
  metadata {
    name      = "vault-client-app"
    namespace = module.vault_client_test_namespace.namespace
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "vault-client-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "vault-client-app"
        }
      }
      spec {
        service_account_name = local.app_sa_name

        volume {
          name = "amoebius-volume"
          host_path {
            path = "/amoebius"
            type = "Directory"
          }
        }

        container {
          name  = "app"
          image = "tuee22/amoebius:latest"

          command = [
            "python",
            "-m",
            "amoebius.tests.vault_client",
            "--daemon"
          ]

          volume_mount {
            name       = "amoebius-volume"
            mount_path = "/amoebius"
            read_only  = false
          }
        }
      }
    }
  }
}