terraform {
  required_providers {
    tls = {
      source = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

locals {
  expanded_instances_list = flatten([
    for group_name, def in var.deployment : [
      for z in var.availability_zones : [
        for i in range(def.count_per_zone) : {
          key        = "${group_name}_${z}_${i}",
          group_name = group_name,
          zone       = z,
          image      = def.image,
          category   = def.category
        }
      ]
    ]
  ])

  expanded_instances_map = {
    for inst in local.expanded_instances_list :
    inst.key => {
      group_name = inst.group_name
      zone       = inst.zone
      image      = inst.image
      category   = inst.category
    }
  }

  # Step A
  pre_names = {
    for k, v in local.expanded_instances_map :
    k => lower(replace("${v.group_name}-${k}", "_", "-"))
  }

  # Step B
  only_valid_chars = {
    for k, nm in local.pre_names :
    k => join("", regexall("[a-z0-9-]", nm))
  }

  # Step C
  ensure_letter_prefix = {
    for k, nm in local.only_valid_chars :
    k => length(regexall("^[a-z]", nm)) > 0 ? nm : "x${nm}"
  }

  # Step D
  truncated = {
    for k, nm in local.ensure_letter_prefix :
    k => substr(nm, 0, 63)
  }

  # Step E
  no_trailing_hyphen = {
    for k, nm in local.truncated :
    k => length(regexall("-$", nm)) == 0 ? nm : substr(nm, 0, length(nm) - 1)
  }

  validated_names = local.no_trailing_hyphen
}

resource "tls_private_key" "all" {
  for_each = local.expanded_instances_map

  algorithm = "RSA"
  rsa_bits  = 4096
}

module "compute_single" {
  for_each = local.expanded_instances_map

  source = "/amoebius/terraform/modules/providers/gcp/compute"

  vm_name            = local.validated_names[each.key]
  public_key_openssh = tls_private_key.all[each.key].public_key_openssh
  ssh_user           = var.ssh_user
  image              = each.value.image
  instance_type      = lookup(var.instance_type_map, each.value.category, "UNDEFINED_TYPE")
  zone               = each.value.zone
  workspace          = var.workspace

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

  vault_prefix = "amoebius/ssh/gcp/${var.workspace}"
}

locals {
  compute_results = [
    for k, comp_mod in module.compute_single : {
      key                = k
      group_name         = local.expanded_instances_map[k].group_name
      name               = comp_mod.vm_name
      private_ip         = comp_mod.private_ip
      public_ip          = comp_mod.public_ip
      vault_path         = module.vm_secret[k].vault_path
      is_nvidia_instance = length(regexall("^nvidia_", local.expanded_instances_map[k].category)) > 0 ? true : false
    }
  ]

  instances = {
    for group_name, _unused in var.deployment :
    group_name => {
      for r in local.compute_results :
      r.key => {
        name               = r.name
        private_ip         = r.private_ip
        public_ip          = r.public_ip
        vault_path         = r.vault_path
        is_nvidia_instance = r.is_nvidia_instance
      }
      if r.group_name == group_name
    }
  }
}
