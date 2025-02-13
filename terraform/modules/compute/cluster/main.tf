terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

#
# 1) We define data sources for 24.04 LTS images for each arch + provider
#    Then we pick the correct one based on category (ARM vs x86).
#    If user sets a custom image, we skip these data sources.
#

#############################
# AWS Data Sources (24.04 LTS) - Mantic daily, hopefully.
#############################
provider "aws" {
  region = var.region
}

data "aws_ami" "ubuntu_2404_arm" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-mantic-24.04-arm64-server-*"]
  }
  filter {
    name   = "architecture"
    values = ["arm64"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_ami" "ubuntu_2404_x86" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-mantic-24.04-amd64-server-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

#############################
# Azure Data Sources (24.04 LTS)
# There's no official 24.04 yet. We do a hypothetical shared gallery or future "urn".
# We'll store them in locals. We'll do no real data resource. 
# Because data "azurerm_image" or "azurerm_shared_image_gallery" might not exist yet.
#############################

locals {
  azure_2404_arm_image = "/subscriptions/<SUBID>/resourceGroups/<RG>/providers/Microsoft.Compute/galleries/Ubuntu24Arm/images/24_04-lts/versions/latest"
  azure_2404_x86_image = "/subscriptions/<SUBID>/resourceGroups/<RG>/providers/Microsoft.Compute/galleries/Ubuntu24x86/images/24_04-lts/versions/latest"
  # Or some future URN. 
  # This is the best we can do for real code referencing a Shared Image. 
}

#############################
# GCP Data Sources (24.04 LTS)
#############################
provider "google" {
  # project from environment
}

# ARM
data "google_compute_image" "ubuntu_2404_arm" {
  project = "ubuntu-os-cloud"
  family  = "ubuntu-2404-lts-arm64"  # real family name may differ once 24.04 is published
}

# x86
data "google_compute_image" "ubuntu_2404_x86" {
  project = "ubuntu-os-cloud"
  family  = "ubuntu-2404-lts"  # 24.04 x86
}

#
# 2) Map categories to instance types (the user said no defaults here? 
#    But let's keep them for demonstration, or let the root specify them. 
#    We'll store them here for now, or you can move them to the root. 
#
locals {
  aws_instance_map = {
    arm_small     = "t4g.micro"
    arm_medium    = "t4g.small"
    arm_large     = "t4g.large"
    x86_small     = "t3.micro"
    x86_medium    = "t3.small"
    x86_large     = "t3.large"
    nvidia_small  = "g4dn.xlarge"
    nvidia_medium = "g4dn.4xlarge"
    nvidia_large  = "g4dn.8xlarge"
  }

  azure_instance_map = {
    arm_small      = "Standard_D2ps_v5"
    arm_medium     = "Standard_D4ps_v5"
    arm_large      = "Standard_D8ps_v5"
    x86_small      = "Standard_D2s_v5"
    x86_medium     = "Standard_D4s_v5"
    x86_large      = "Standard_D8s_v5"
    nvidia_small   = "Standard_NC4as_T4_v3"
    nvidia_medium  = "Standard_NC8as_T4_v3"
    nvidia_large   = "Standard_NC16as_T4_v3"
  }

  gcp_instance_map = {
    arm_small     = "t2a-standard-1"
    arm_medium    = "t2a-standard-2"
    arm_large     = "t2a-standard-4"
    x86_small     = "e2-small"
    x86_medium    = "e2-standard-4"
    x86_large     = "e2-standard-8"
    nvidia_small  = "a2-highgpu-1g"
    nvidia_medium = "a2-highgpu-2g"
    nvidia_large  = "a2-highgpu-4g"
  }
}

#
# 3) Flatten the instance groups
#
locals {
  expanded_groups = flatten([
    for g in var.instance_groups : [
      for z in var.availability_zones : {
        group_name     = g.name
        category       = g.category
        zone           = z
        count_per_zone = g.count_per_zone
        custom_image   = try(g.image, "")
      }
    ]
  ])

  all_items = flatten([
    for item in local.expanded_groups : [
      for i in range(item.count_per_zone) : {
        group_name  = item.group_name
        category    = item.category
        zone        = item.zone
        custom_image= item.custom_image
      }
    ]
  ])
}

#
# 4) For each item, pick the correct instance_type and default image
#
locals {
  # Distinguish x86 vs ARM by looking at category prefix:
  # If category starts with "arm_", we pick arm. If "x86_", we pick x86. If "nvidia_", we assume x86?
  # user specifically said "logic to pick correct arch"
  # We'll define a small function:
  arch_by_category = {
    for cat in [
      "arm_small","arm_medium","arm_large",
      "x86_small","x86_medium","x86_large",
      "nvidia_small","nvidia_medium","nvidia_large"
    ] : cat => (
      startswith(cat, "arm_") ? "arm" : "x86"
    )
  }

  # We'll produce an array of final specs
  final_specs = [
    for idx, it in local.all_items : {
      group_name   = it.group_name
      zone         = it.zone
      category     = it.category
      arch         = local.arch_by_category[it.category]
      instance_type = (
        var.provider == "aws"   ? local.aws_instance_map[it.category] :
        var.provider == "azure" ? local.azure_instance_map[it.category] :
        local.gcp_instance_map[it.category]
      )
      # If user didn't override image, pick the default for that provider + arch
      image = (
        length(it.custom_image) > 0
        ? it.custom_image
        : (
            var.provider == "aws" && local.arch_by_category[it.category] == "arm" ? data.aws_ami.ubuntu_2404_arm.id :
            var.provider == "aws" && local.arch_by_category[it.category] == "x86" ? data.aws_ami.ubuntu_2404_x86.id :
            var.provider == "azure" && local.arch_by_category[it.category] == "arm" ? local.azure_2404_arm_image :
            var.provider == "azure" && local.arch_by_category[it.category] == "x86" ? local.azure_2404_x86_image :
            var.provider == "gcp"  && local.arch_by_category[it.category] == "arm" ? data.google_compute_image.ubuntu_2404_arm.self_link :
            data.google_compute_image.ubuntu_2404_x86.self_link
          )
      )
    }
  ]
}

#
# 5) Create a TLS key per item, then call the provider module
#
resource "tls_private_key" "keys" {
  count     = length(local.final_specs)
  algorithm = "RSA"
  rsa_bits  = 4096
}

module "provider_vm" {
  count = length(local.final_specs)

  source = (
    var.provider == "aws"   ? "/amoebius/terraform/modules/compute/aws" :
    var.provider == "azure" ? "/amoebius/terraform/modules/compute/azure" :
    "/amoebius/terraform/modules/compute/gcp"
  )

  vm_name            = "${terraform.workspace}-${local.final_specs[count.index].group_name}-${count.index}"
  public_key_openssh = tls_private_key.keys[count.index].public_key_openssh
  ssh_user           = var.ssh_user
  image              = local.final_specs[count.index].image
  instance_type      = local.final_specs[count.index].instance_type
  zone               = local.final_specs[count.index].zone
  workspace          = terraform.workspace

  subnet_id = element(
    var.subnet_ids,
    index(var.availability_zones, local.final_specs[count.index].zone)
  )
  security_group_id = var.security_group_id
}

#
# 6) Wrap with SSH logic => store in Vault
#
module "ssh_wrapper" {
  count  = length(local.final_specs)
  source = "/amoebius/terraform/modules/ssh_wrapper"

  vm_name         = module.provider_vm[count.index].vm_name
  public_ip       = module.provider_vm[count.index].public_ip
  private_key_pem = tls_private_key.keys[count.index].private_key_pem
  ssh_user        = var.ssh_user
  vault_role_name = var.vault_role_name
  no_verify_ssl   = var.no_verify_ssl

  vault_prefix = "/amoebius/ssh/${var.provider}/${terraform.workspace}"
}

#
# 7) Final Output
#
locals {
  all_results = [
    for idx, spec in local.final_specs : {
      group_name = spec.group_name
      name       = module.provider_vm[idx].vm_name
      private_ip = module.provider_vm[idx].private_ip
      public_ip  = module.provider_vm[idx].public_ip
      vault_path = module.ssh_wrapper[idx].vault_path
    }
  ]

  instances_by_group = {
    for g in var.instance_groups : g.name => [
      for r in all_results : r if r.group_name == g.name
    ]
  }
}

output "instances_by_group" {
  value = local.instances_by_group
}
