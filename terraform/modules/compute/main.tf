terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# We do minimal single-VM logic here, referencing the subfolder for actual resources
locals {
  provider_paths = {
    "aws"   = "./aws"
    "azure" = "./azure"
    "gcp"   = "./gcp"
  }
}

module "single_vm" {
  source = local.provider_paths[var.provider]

  vm_name            = var.vm_name
  public_key_openssh = var.public_key_openssh
  ssh_user           = var.ssh_user
  image              = var.image
  instance_type      = var.instance_type
  subnet_id          = var.subnet_id
  security_group_id  = var.security_group_id
  zone               = var.zone
  workspace          = var.workspace

  resource_group_name = var.resource_group_name
  location            = var.location
}
