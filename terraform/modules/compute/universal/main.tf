terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

#
# 1) Polymorphic submodule path
#
locals {
  provider_submodule_path = {
    aws   = "/amoebius/terraform/modules/compute/aws"
    azure = "/amoebius/terraform/modules/compute/azure"
    gcp   = "/amoebius/terraform/modules/compute/gcp"
  }[var.provider]

  # Hard-coded default instance maps for each provider, Ubuntu 24.04
  provider_instance_map = {
    aws = {
      arm_small     = "t4g.micro"
      arm_medium    = "t4g.small"
      arm_large     = "t4g.large"
      x86_small     = "t3.micro"
      x86_medium    = "t3.small"
      x86_large     = "t3.large"
      nvidia_small  = "g4dn.xlarge"
      nvidia_medium = "g4dn.4xlarge"
      nvidia_large  = "g4dn.8xlarge"
    },
    azure = {
      arm_small      = "Standard_D2ps_v5"
      arm_medium     = "Standard_D4ps_v5"
      arm_large      = "Standard_D8ps_v5"
      x86_small      = "Standard_D2s_v5"
      x86_medium     = "Standard_D4s_v5"
      x86_large      = "Standard_D8s_v5"
      nvidia_small   = "Standard_NC4as_T4_v3"
      nvidia_medium  = "Standard_NC8as_T4_v3"
      nvidia_large   = "Standard_NC16as_T4_v3"
    },
    gcp = {
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
  instance_type_map = local.provider_instance_map[var.provider]
}

#
# 2) Expand instance_groups => a flat list
#
locals {
  expanded_groups = flatten([
    for g in var.instance_groups : [
      for z in var.availability_zones : {
        group_name     = g.name
        category       = g.category
        zone           = z
        count_per_zone = g.count_per_zone
        image_override = try(g.image, "")  # if present
      }
    ]
  ])

  all_items = flatten([
    for item in local.expanded_groups : [
      for i in range(item.count_per_zone) : {
        group_name    = item.group_name
        category      = item.category
        zone          = item.zone
        image_override = item.image_override
      }
    ]
  ])
}

#
# 3) TLS private keys
#
resource "tls_private_key" "keys" {
  count     = length(local.all_items)
  algorithm = "RSA"
  rsa_bits  = 4096
}

#
# 4) For each item, call the provider submodule
#
module "provider_vm" {
  count = length(local.all_items)
  source = local.provider_submodule_path

  vm_name         = "${terraform.workspace}-${local.all_items[count.index].group_name}-${count.index}"
  instance_type   = local.instance_type_map[local.all_items[count.index].category]
  public_key_openssh = tls_private_key.keys[count.index].public_key_openssh

  # If GCP => pass as 'image'
  # If AWS => pass as 'image'
  # If Azure => pass as 'image'
  # So we unify the variable name as "image" in each module
  image      = local.all_items[count.index].image_override

  subnet_id        = element(var.subnet_ids, index(var.availability_zones, local.all_items[count.index].zone))
  security_group_id = var.security_group_id
  ssh_user         = var.ssh_user
  zone             = local.all_items[count.index].zone
  workspace        = terraform.workspace
}

#
# 5) SSH wrapper
#
module "ssh_wrapper" {
  count  = length(local.all_items)
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
# 6) Build final output structure
#
locals {
  all_results_flat = [
    for idx, it in local.all_items : {
      group_name = it.group_name
      name       = module.provider_vm[idx].vm_name
      private_ip = module.provider_vm[idx].private_ip
      public_ip  = module.provider_vm[idx].public_ip
      vault_path = module.ssh_wrapper[idx].vault_path
    }
  ]

  instances_by_group = {
    for g in var.instance_groups : g.name => [
      for r in all_results_flat : r if r.group_name == g.name
    ]
  }
}

output "instances_by_group" {
  value = local.instances_by_group
}
