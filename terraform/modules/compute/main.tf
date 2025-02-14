terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

locals {
  # Table lookup for submodule folder path
  provider_subfolders = {
    "aws"   = "./aws"
    "azure" = "./azure"
    "gcp"   = "./gcp"
  }
}

# 1) expand instance groups
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

  final_list = flatten([
    for item in local.expanded_groups : [
      for i in range(item.count_per_zone) : {
        group_name   = item.group_name
        category     = item.category
        zone         = item.zone
        custom_image = item.custom_image
      }
    ]
  ])
}

resource "tls_private_key" "all" {
  count     = length(local.final_list)
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 2) For each item, pick instance_type from var.instance_type_map
#    If var.instance_type_map does not contain the category, it fails or returns blank
locals {
  item_specs = [
    for idx, i in local.final_list : {
      group_name    = i.group_name
      zone          = i.zone
      instance_type = lookup(var.instance_type_map, i.category, "MISSING_TYPE")
      image         = i.custom_image
      # The rest is used directly
    }
  ]
}

module "provider_vm" {
  count = length(local.item_specs)

  source = local.provider_subfolders[var.provider]

  vm_name            = "${terraform.workspace}-${local.item_specs[count.index].group_name}-${count.index}"
  public_key_openssh = tls_private_key.all[count.index].public_key_openssh
  ssh_user           = var.ssh_user

  image         = local.item_specs[count.index].image
  instance_type = local.item_specs[count.index].instance_type
  zone          = local.item_specs[count.index].zone
  workspace     = terraform.workspace

  subnet_id = element(var.subnet_ids, index(var.availability_zones, local.item_specs[count.index].zone))
  security_group_id = var.security_group_id

  # If azure, we likely also need resource_group_name. That is typically from the root, or from the network module output
  # We'll handle that in the root if needed (by making 'subnet_id' be a data reference?). 
}

module "vm_secret" {
  count = length(local.item_specs)
  source = "../ssh/vm_secret"

  vm_name         = module.provider_vm[count.index].vm_name
  public_ip       = module.provider_vm[count.index].public_ip
  private_key_pem = tls_private_key.all[count.index].private_key_pem
  ssh_user        = var.ssh_user
  vault_role_name = var.vault_role_name
  no_verify_ssl   = var.no_verify_ssl

  vault_prefix = "/amoebius/ssh/${var.provider}/${terraform.workspace}"
}

locals {
  # Combine results
  all_results = [
    for idx, s in local.item_specs : {
      group_name = local.final_list[idx].group_name
      name       = module.provider_vm[idx].vm_name
      private_ip = module.provider_vm[idx].private_ip
      public_ip  = module.provider_vm[idx].public_ip
      vault_path = module.vm_secret[idx].vault_path
    }
  ]

  instances_by_group = {
    for i in local.final_list : i.group_name => [
      for x in all_results : x if x.group_name == i.group_name
    ]
  }
}
