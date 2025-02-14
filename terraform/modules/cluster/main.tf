terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

locals {
  # We'll do a small table to pick the sub-folder for the single VM
  compute_subfolder = {
    aws   = "/amoebius/terraform/modules/compute/aws"
    azure = "/amoebius/terraform/modules/compute/azure"
    gcp   = "/amoebius/terraform/modules/compute/gcp"
  }
}

# 1) expand instance_groups => final list
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

# 2) For each item, we find its instance_type in instance_type_map
locals {
  item_specs = [
    for idx, it in local.final_list : {
      group_name    = it.group_name
      zone          = it.zone
      instance_type = lookup(var.instance_type_map, it.category, "UNKNOWN")
      image         = it.custom_image
    }
  ]
}

module "vms" {
  count = length(local.item_specs)
  source = local.compute_subfolder[var.provider]

  vm_name            = "${terraform.workspace}-${local.item_specs[count.index].group_name}-${count.index}"
  public_key_openssh = tls_private_key.all[count.index].public_key_openssh
  ssh_user           = var.ssh_user

  image         = local.item_specs[count.index].image
  instance_type = local.item_specs[count.index].instance_type
  zone          = local.item_specs[count.index].zone
  workspace     = terraform.workspace

  subnet_id        = element(var.subnet_ids, index(var.availability_zones, local.item_specs[count.index].zone))
  security_group_id= var.security_group_id

  # If Azure, pass resource_group_name
  resource_group_name = var.azure_resource_group_name
}

module "ssh_vm_secret" {
  count  = length(local.item_specs)
  source = "/amoebius/terraform/modules/ssh/vm_secret"

  vm_name         = module.vms[count.index].vm_name
  public_ip       = module.vms[count.index].public_ip
  private_key_pem = tls_private_key.all[count.index].private_key_pem
  ssh_user        = var.ssh_user
  vault_role_name = var.vault_role_name
  no_verify_ssl   = var.no_verify_ssl

  vault_prefix = "/amoebius/ssh/${var.provider}/${terraform.workspace}"
}

locals {
  all_results = [
    for idx, i in local.item_specs : {
      group_name = local.final_list[idx].group_name
      name       = module.vms[idx].vm_name
      private_ip = module.vms[idx].private_ip
      public_ip  = module.vms[idx].public_ip
      vault_path = module.ssh_vm_secret[idx].vault_path
    }
  ]

  instances_by_group = {
    for grp in var.instance_groups : grp.name => [
      for x in all_results : x if x.group_name == grp.name
    ]
  }
}
