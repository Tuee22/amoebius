terraform {
  required_providers {
    tls = {
      source = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

locals {
  # 1) Flatten
  expanded_instances_list = flatten([
    for group_name, groupDef in var.deployment : [
      for z in var.availability_zones : [
        for i in range(groupDef.count_per_zone) : {
          key        = "${group_name}_${z}_${i}",
          group_name = group_name,
          zone       = z,
          image      = groupDef.image,
          category   = groupDef.category
        }
      ]
    ]
  ])

  # 2) Map from key => { group_name, zone, ... }
  expanded_instances_map = {
    for inst in local.expanded_instances_list :
    inst.key => {
      group_name = inst.group_name
      zone       = inst.zone
      image      = inst.image
      category   = inst.category
    }
  }

  # Step A: Convert underscores to hyphens + lowercase
  pre_names = {
    for k, v in local.expanded_instances_map :
    k => lower(replace("${v.group_name}-${k}", "_", "-"))
  }

  # Step B: Keep only [a-z0-9-]
  only_valid_chars = {
    for k, nm in local.pre_names :
    k => join("", regexall("[a-z0-9-]", nm))
  }

  # Step C: Ensure starts with letter
  ensure_letter_prefix = {
    for k, nm in local.only_valid_chars :
    k => length(regexall("^[a-z]", nm)) > 0 ? nm : "x${nm}"
  }

  # Step D: Truncate to 63 chars
  truncated = {
    for k, nm in local.ensure_letter_prefix :
    k => substr(nm, 0, 63)
  }

  # Step E: Remove single trailing hyphen if present
  no_trailing_hyphen = {
    for k, nm in local.truncated :
    k => length(regexall("-$", nm)) == 0 ? nm : substr(nm, 0, length(nm) - 1)
  }

  # Final map => validated names
  validated_names = local.no_trailing_hyphen
}

resource "tls_private_key" "all" {
  for_each = local.expanded_instances_map

  algorithm = "RSA"
  rsa_bits  = 4096
}

module "compute_single" {
  for_each = local.expanded_instances_map

  source = "/amoebius/terraform/modules/providers/aws/compute"

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

  vault_prefix = "amoebius/ssh/aws/${var.workspace}"
}

locals {
  compute_results = [
    for k, comp in module.compute_single : {
      key        = k
      group_name = local.expanded_instances_map[k].group_name
      name       = comp.vm_name
      private_ip = comp.private_ip
      public_ip  = comp.public_ip
      vault_path = module.vm_secret[k].vault_path
    }
  ]

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
