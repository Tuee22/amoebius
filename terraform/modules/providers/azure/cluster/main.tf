terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

locals {
  ###############################
  # 1. Build a list of instances
  ###############################
  expanded_instances_list = flatten([
    for g in var.instance_groups : [
      for z in var.availability_zones : [
        for i in range(g.count_per_zone) : {
          key        = "${g.name}_z${z}_${i}"
          group_name = g.name
          zone       = z
          image      = g.image
          category   = g.category
        }
      ]
    ]
  ])

  ###########################################
  # 2. Convert that list to a map keyed by `key`
  ###########################################
  # e.g. {
  #   "app-servers_z1_0" = {
  #       group_name = "app-servers"
  #       zone       = "1"
  #       image      = "Canonical:..."
  #       category   = "arm_small"
  #   },
  #   ...
  # }
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

##########################################
# 3. Create one SSH key per instance
##########################################
resource "tls_private_key" "all" {
  for_each = local.expanded_instances_map

  algorithm = "RSA"
  rsa_bits  = 4096
}

#####################################
# 4. Create VM modules using for_each
#####################################
module "compute_single" {
  for_each = local.expanded_instances_map

  source = "/amoebius/terraform/modules/providers/azure/compute"

  # Use each.key in the VM name, plus we store group_name in each.value
  vm_name            = "${terraform.workspace}-${each.value.group_name}-${each.key}"
  public_key_openssh = tls_private_key.all[each.key].public_key_openssh
  ssh_user           = var.ssh_user
  image              = each.value.image
  instance_type      = lookup(var.instance_type_map, each.value.category, "UNDEFINED_TYPE")
  zone               = each.value.zone
  workspace          = terraform.workspace

  # Simple example: relies on matching index() in availability_zones vs. subnet_ids
  # (If you want a more robust approach, see notes about maps: var.subnet_ids_by_zone)
  subnet_id = var.subnet_ids_by_zone[each.value.zone]

  security_group_id   = var.security_group_id
  resource_group_name = var.resource_group_name
  location            = var.location
}

#################################################
# 5. Create SSH secrets for each VM (Vault, etc.)
#################################################
module "vm_secret" {
  for_each = module.compute_single

  source = "/amoebius/terraform/modules/ssh/vm_secret"

  vm_name         = each.value.vm_name
  public_ip       = each.value.public_ip
  private_key_pem = tls_private_key.all[each.key].private_key_pem
  ssh_user        = var.ssh_user
  vault_role_name = var.vault_role_name
  no_verify_ssl   = var.no_verify_ssl

  vault_prefix = "amoebius/ssh/azure/${terraform.workspace}"
}

####################################
# 6. Gather results for outputs
####################################
locals {
  # Grab data from each compute module and get group_name from local.expanded_instances_map
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

  # Summarize in a map: group_name => list of instance info
  instances_by_group = {
    for g in var.instance_groups : g.name => [
      for r in local.compute_results : r if r.group_name == g.name
    ]
  }
}
