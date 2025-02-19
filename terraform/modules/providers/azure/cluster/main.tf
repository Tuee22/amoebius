terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

locals {
  expanded = flatten([
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
    for e in local.expanded : [
      for i in range(e.count_per_zone) : {
        group_name   = e.group_name
        category     = e.category
        zone         = e.zone
        custom_image = e.custom_image
      }
    ]
  ])
}

resource "tls_private_key" "all" {
  count     = length(local.final_list)
  algorithm = "RSA"
  rsa_bits  = 4096
}

locals {
  all_specs = [
    for idx, item in local.final_list : {
      group_name    = item.group_name
      zone          = item.zone
      instance_type = lookup(var.instance_type_map, item.category, "UNDEFINED_TYPE")
      image         = item.custom_image
    }
  ]
}

module "compute_single" {
  count = length(local.all_specs)

  source = "/amoebius/terraform/modules/providers/azure/compute"

  vm_name            = "${terraform.workspace}-${local.all_specs[count.index].group_name}-${count.index}"
  public_key_openssh = tls_private_key.all[count.index].public_key_openssh
  ssh_user           = var.ssh_user
  image              = local.all_specs[count.index].image
  instance_type      = local.all_specs[count.index].instance_type
  zone               = local.all_specs[count.index].zone
  workspace          = terraform.workspace

  subnet_id         = element(var.subnet_ids, index(var.availability_zones, local.all_specs[count.index].zone))
  security_group_id = var.security_group_id

  resource_group_name = var.resource_group_name
  location            = var.location
}

module "vm_secret" {
  count  = length(local.all_specs)
  source = "/amoebius/terraform/modules/ssh/vm_secret"

  vm_name         = module.compute_single[count.index].vm_name
  public_ip       = module.compute_single[count.index].public_ip
  private_key_pem = tls_private_key.all[count.index].private_key_pem
  ssh_user        = var.ssh_user
  vault_role_name = var.vault_role_name
  no_verify_ssl   = var.no_verify_ssl

  vault_prefix = "/amoebius/ssh/azure/${terraform.workspace}"
}

locals {
  results = [
    for idx, s in local.all_specs : {
      group_name = local.final_list[idx].group_name
      name       = module.compute_single[idx].vm_name
      private_ip = module.compute_single[idx].private_ip
      public_ip  = module.compute_single[idx].public_ip
      vault_path = module.vm_secret[idx].vault_path
    }
  ]

  instances_by_group = {
    for g in var.instance_groups : g.name => [
      for r in local.results : r if r.group_name == g.name
    ]
  }
}
