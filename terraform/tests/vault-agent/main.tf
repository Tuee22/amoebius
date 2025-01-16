terraform {
  backend "kubernetes" {
    secret_suffix     = "test-vault-agent"
    load_config_file  = false
    namespace         = "amoebius"
    in_cluster_config = true
  }
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.10"
    }
  }
}

provider "vault" {
  address = var.vault_addr
  token   = var.vault_token
}

provider "kubernetes" {
  host                   = ""
  cluster_ca_certificate = ""
  token                  = ""
}

module "vault_test_namespace" {
  source = "/amoebius/terraform/modules/linkerd_annotated_namespace"
  namespace_name = "vault-agent-test"
}


# Create a service account for the app
resource "kubernetes_service_account" "app_sa" {
  metadata {
    name      = "vault-test-sa"
    namespace = module.vault_test_namespace.namespace
  }
}

# Define the Vault policy
resource "vault_policy" "app_policy" {
  name   = "vault-test-policy"
  policy = <<EOT
path "secret/data/vault-test/*" {
    capabilities = ["read", "list"]
}
EOT
}

# Write a secret to the specified path
resource "vault_kv_secret_v2" "app_secret" {
  mount = "secret" # Mount path of the KV engine
  name  = "vault-test/hello" # Secret path

  data_json = jsonencode({
    message = "hello world"
  })
}

resource "vault_kubernetes_auth_backend_role" "app_role" {
  backend               = "kubernetes"
  role_name             = "vault-test-role"
  bound_service_account_names      = [kubernetes_service_account.app_sa.metadata[0].name]
  bound_service_account_namespaces = [module.vault_test_namespace.namespace]
  token_policies                   = [vault_policy.app_policy.name]
}

resource "kubernetes_deployment" "app_deployment" {
  metadata {
    name      = "vault-test-app"
    namespace = module.vault_test_namespace.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "vault-test-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "vault-test-app"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.app_sa.metadata[0].name

        container {
          name  = "app"
          image = "alpine"
          command = [
            "/bin/sh",
            "-c",
            "while true; do cat /vault/secrets/config | grep message; sleep 5; done"
          ]
        }
      }
    }
  }
}