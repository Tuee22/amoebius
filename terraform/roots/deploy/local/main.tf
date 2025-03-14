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
  }
}

###########################################
# KIND CLUSTER MODULE
###########################################
module "kind" {
  source       = "../../../modules/k8s/kind"
  cluster_name = var.cluster_name
  data_dir     = var.data_dir
  amoebius_dir = var.amoebius_dir
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
# LOAD LOCAL IMAGE INTO KIND (if enabled)
###########################################
resource "null_resource" "load_local_image" {
  count = var.local_build_enabled ? 1 : 0

  depends_on = [
    # Ensure the Kind cluster is created before loading the image
    module.kind
  ]

  provisioner "local-exec" {
    command = "kind load docker-image ${var.local_docker_image_tag} --name ${var.cluster_name}"
  }
}

###########################################
# DEPLOY AMOEBIUS
###########################################
module "amoebius" {
  source                  = "../../../modules/amoebius"

  # Auth to the cluster
  host                    = module.kind.host
  cluster_ca_certificate  = module.kind.cluster_ca_certificate
  client_certificate      = module.kind.client_certificate
  client_key              = module.kind.client_key

  # Use our effective image: either 'amoebius:local' or 'tuee22/amoebius:latest'
  amoebius_image          = local.effective_image

  namespace               = var.namespace
  apply_linkerd_policy    = var.apply_linkerd_policy

  # If you want to ensure that the image load step is definitely done
  # before creating Amoebius resources, you can add:
  #
  # depends_on = [
  #   null_resource.load_local_image
  # ]
  #
  # But this is typically not strictly necessary, because the Pod will
  # eventually fail if the image isn't loaded yet and terraform will
  # keep waiting. Up to your preference.
}