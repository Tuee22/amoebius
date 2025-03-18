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
# KIND CLUSTER MODULE
###########################################
module "kind" {
  source = "/amoebius/terraform/modules/k8s/kind"

  cluster_name        = var.cluster_name
  data_dir            = var.data_dir
  amoebius_dir        = var.amoebius_dir
  mount_docker_socket = var.mount_docker_socket
}

###########################################
# CONFIGURE KUBERNETES PROVIDER
###########################################
provider "kubernetes" {
  host                   = module.kind.host
  cluster_ca_certificate = module.kind.cluster_ca_certificate
  client_certificate     = module.kind.client_certificate
  client_key             = module.kind.client_key

  # Optionally set insecure = true if using self-signed cert:
  # insecure = true
}

###########################################
# CONFIGURE HELM PROVIDER
###########################################
provider "helm" {
  kubernetes {
    host                   = module.kind.host
    cluster_ca_certificate = module.kind.cluster_ca_certificate
    client_certificate     = module.kind.client_certificate
    client_key             = module.kind.client_key
    # insecure = true  # If self-signed
  }
}

###########################################
# DETERMINE WHICH IMAGE TO USE
###########################################
locals {
  effective_image = (
    var.local_build_enabled
    ? var.local_docker_image_tag
    : var.amoebius_image
  )
}

###########################################
# (Optional) LOAD LOCAL IMAGE TAR INTO KIND
###########################################
resource "null_resource" "load_local_image_tar" {
  count = var.local_build_enabled ? 1 : 0

  depends_on = [module.kind]

  provisioner "local-exec" {
    command = <<EOT
kind load image-archive /amoebius/data/images/amoebius.tar --name ${var.cluster_name}
EOT
  }
}

###########################################
# CREATE NAMESPACE (LINKERD OPTIONAL)
###########################################
module "amoebius_namespace" {
  source = "/amoebius/terraform/modules/linkerd_annotated_namespace"

  namespace            = var.namespace
  apply_linkerd_policy = var.apply_linkerd_policy

  host                   = module.kind.host
  cluster_ca_certificate = module.kind.cluster_ca_certificate
  client_certificate     = module.kind.client_certificate
  client_key             = module.kind.client_key
}

###########################################
# DEPLOY AMOEBIUS (ALSO INSTALLS REGISTRY-CREDS HELM CHART)
###########################################
module "amoebius" {
  source = "/amoebius/terraform/modules/amoebius"

  # The image is either local or DockerHub
  amoebius_image      = local.effective_image
  namespace           = var.namespace
  mount_docker_socket = var.mount_docker_socket

  # Pass DockerHub creds down to the module
  dockerhub_username  = var.dockerhub_username
  dockerhub_password  = var.dockerhub_password
  registry_creds_chart_version = var.registry_creds_chart_version

  depends_on = [
    null_resource.load_local_image_tar,
    module.amoebius_namespace
  ]
}