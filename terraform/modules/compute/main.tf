###############################################
# /amoebius/terraform/modules/compute/main.tf
###############################################
terraform {
  required_providers {
    # You might also define others if needed
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# We cannot do "source = dynamicValue" in a module block. 
# Instead, define 3 static module blocks (aws, azure, gcp) with count=1 or 0.

module "aws_single_vm" {
  source = "./aws"
  count  = var.cloud_provider == "aws" ? 1 : 0

  vm_name            = var.vm_name
  public_key_openssh = var.public_key_openssh
  ssh_user           = var.ssh_user
  image              = var.image
  instance_type      = var.instance_type
  subnet_id          = var.subnet_id
  security_group_id  = var.security_group_id
  zone               = var.zone
  workspace          = var.workspace
}

module "azure_single_vm" {
  source = "./azure"
  count  = var.cloud_provider == "azure" ? 1 : 0

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

module "gcp_single_vm" {
  source = "./gcp"
  count  = var.cloud_provider == "gcp" ? 1 : 0

  vm_name            = var.vm_name
  public_key_openssh = var.public_key_openssh
  ssh_user           = var.ssh_user
  image              = var.image
  instance_type      = var.instance_type
  subnet_id          = var.subnet_id
  security_group_id  = var.security_group_id
  zone               = var.zone
  workspace          = var.workspace
}

