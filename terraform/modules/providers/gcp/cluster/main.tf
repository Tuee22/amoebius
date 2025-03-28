terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

locals {
  # 1) Flatten each group_name => groupDef into multiple instances
  expanded_instances_list = flatten([
    for group_name, def in var.deployment : [
      for z in var.availability_zones : [
        for i in range(def.count_per_zone) : {
          key        = "${group_name}_z${z}_${i}"
          group_name = group_name
          zone       = z
          image      = def.image
          category   = def.category
        }
      ]
    ]
  ])

  # 2) Convert to a map for for_each usage
  expanded_instances_map = {
    for inst in local.expanded_instances_list :
    inst.key => {
      group_name = inst.group_name
      zone       = inst.zone
      image      = inst.image
      category   = inst.category
    }
  }
}

resource "tls_private_key" "all" {
  for_each = local.expanded_instances_map

  algorithm = "RSA"
  rsa_bits  = 4096
}

module "compute_single" {
  for_each = local.expanded_instances_map

  source = "/amoebius/terraform/modules/providers/gcp/compute"

  vm_name            = lower(replace("${terraform.workspace}-${each.value.group_name}-${each.key}", "_", "-"))
  public_key_openssh = tls_private_key.all[each.key].public_key_openssh
  ssh_user           = var.ssh_user
  image              = each.value.image
  instance_type      = lookup(var.instance_type_map, each.value.category, "UNDEFINED_TYPE")
  zone               = each.value.zone
  workspace          = terraform.workspace

  subnet_id         = var.subnet_ids_by_zone[each.value.zone]
  security_group_id = var.security_group_id

  resource_group_name = var.resource_group_name
  location            = var.location
}

module "vm_secret" {
  for_each = module.compute_single

  source = "/amoebius/terraform/modules/ssh/vm_secret"

  vm_name         = each.value.vm_name
  public_ip       = each.value.public_ip
  private_key_pem = tls_private_key.all[each.key].private_key_pem
  ssh_user        = var.ssh_user
  vault_role_name = var.vault_role_name
  no_verify_ssl   = var.no_verify_ssl

  vault_prefix = "amoebius/ssh/gcp/${terraform.workspace}"
}

locals {
  compute_results = [
    for k, comp_mod in module.compute_single : {
      key        = k
      group_name = local.expanded_instances_map[k].group_name
      name       = comp_mod.vm_name
      private_ip = comp_mod.private_ip
      public_ip  = comp_mod.public_ip
      vault_path = module.vm_secret[k].vault_path
    }
  ]

  # 3) Nested map: group_name => instance_key => details
  instances = {
    for group_name, _unused in var.deployment :
    group_name => {
      for r in local.compute_results :
      r.key => {
        name       = r.name
        private_ip = r.private_ip
        public_ip  = r.public_ip
        vault_path = r.vault_path
      }
      if r.group_name == group_name
    }
  }
}
