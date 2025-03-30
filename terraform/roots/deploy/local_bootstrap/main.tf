#####################################################################
# main.tf (Root Module)
#####################################################################
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9.0"
    }
  }
}

###########################################
# 1) KIND CLUSTER MODULE
###########################################
module "kind" {
  source = "../../../modules/k8s/kind"

  cluster_name        = var.cluster_name
  data_dir            = var.data_dir
  amoebius_dir        = var.amoebius_dir
  mount_docker_socket = var.mount_docker_socket

  dockerhub_username  = var.dockerhub_username
  dockerhub_password  = var.dockerhub_password
}

###########################################
# 2) (Optional) KUBERNETES PROVIDER in Root
###########################################
provider "kubernetes" {
  host                   = module.kind.host
  cluster_ca_certificate = module.kind.cluster_ca_certificate
  client_certificate     = module.kind.client_certificate
  client_key             = module.kind.client_key
}

###########################################
# 3) CONFIGURE HELM PROVIDER
###########################################
provider "helm" {
  kubernetes {
    host                   = module.kind.host
    cluster_ca_certificate = module.kind.cluster_ca_certificate
    client_certificate     = module.kind.client_certificate
    client_key             = module.kind.client_key
  }
}

###########################################
# 4) DETERMINE WHICH IMAGE TO USE
###########################################
locals {
  effective_image = var.local_build_enabled ? var.local_docker_image_tag : var.amoebius_image
}

###########################################
# 5) (Optional) LOAD LOCAL IMAGE TAR INTO KIND
###########################################
resource "null_resource" "load_local_image_tar" {
  count = var.local_build_enabled ? 1 : 0

  depends_on = [module.kind]

  provisioner "local-exec" {
    command = <<EOT
kind load image-archive ../../../../data/images/amoebius.tar --name ${var.cluster_name}
EOT
  }
}

###########################################
# 6) CREATE NAMESPACE (LINKERD OPTIONAL) 
###########################################
module "amoebius_namespace" {
  source = "../../../modules/linkerd_annotated_namespace"

  namespace            = var.namespace
  apply_linkerd_policy = var.apply_linkerd_policy
}

###########################################
# 7) DEPLOY AMOEBIUS (ALSO INSTALLS REGISTRY-CREDS)
###########################################
module "amoebius" {
  source = "../../../modules/amoebius"

  amoebius_image      = local.effective_image
  namespace           = var.namespace
  mount_docker_socket = var.mount_docker_socket

  dockerhub_username  = var.dockerhub_username
  dockerhub_password  = var.dockerhub_password

  depends_on = [
    null_resource.load_local_image_tar,
    module.amoebius_namespace
  ]
}
