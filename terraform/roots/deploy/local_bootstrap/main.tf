terraform {
  # Keep providers in the root, so define them here.
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.1"
    }
  }
}

###########################################
# KIND CLUSTER MODULE
###########################################
module "kind" {
  source              = "../../../modules/k8s/kind"

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

  # If your Kind cluster uses a self-signed certificate and you get certificate
  # errors, set insecure = true (only if needed):
  # insecure = true
}

###########################################
# DETERMINE WHICH IMAGE TO USE
###########################################
locals {
  # If local_build_enabled = true, we use 'amoebius:local'
  # otherwise we use DockerHub image from var.amoebius_image
  effective_image = var.local_build_enabled ? var.local_docker_image_tag : var.amoebius_image
}


###########################################
# (Optional) LOAD LOCAL IMAGE TAR INTO KIND
###########################################
resource "null_resource" "load_local_image_tar" {
  # Typically you'd only do EITHER tar or direct docker-image approach, not both
  count = (var.local_build_enabled ? 1 : 0)

  depends_on = [
    module.kind
  ]

  provisioner "local-exec" {
    command = <<EOT
kind load image-archive ../../../../data/images/amoebius.tar --name ${var.cluster_name}
EOT
  }
}

###########################################
# DEPLOY AMOEBIUS
###########################################
module "amoebius" {
  source = "../../../modules/amoebius"

  # Auth - referencing Kind module outputs
  host                   = module.kind.host
  cluster_ca_certificate = module.kind.cluster_ca_certificate
  client_certificate     = module.kind.client_certificate
  client_key             = module.kind.client_key

  # Use our effective image: either 'amoebius:local' or DockerHub
  amoebius_image         = local.effective_image

  namespace              = var.namespace
  apply_linkerd_policy   = var.apply_linkerd_policy
  mount_docker_socket    = var.mount_docker_socket

  depends_on = [
    null_resource.load_local_image_tar
  ]
}