terraform {
  required_version = ">= 1.11.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.10"
    }
  }

  # Uncomment and configure if you want an S3-compatible backend (e.g. MinIO)
  #
  # backend "s3" {
  #   endpoint                    = "minio.example.com"
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   bucket                      = "harbour"
  #   key                         = "terraform/harbor/terraform.tfstate"
  #   region                      = "us-east-1"
  #   access_key                  = "CHANGE_ME"
  #   secret_key                  = "CHANGE_ME"
  # }
}

provider "kubernetes" {
  load_config_file = true
  config_path      = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    load_config_file = true
    config_path      = var.kubeconfig_path
  }
}

provider "vault" {
  # token  = var.vault_token  # Or rely on VAULT_TOKEN env var
  address = var.vault_address
}
