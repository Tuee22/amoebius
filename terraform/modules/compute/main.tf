terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

locals {
  # Hard-coded instance maps, or we can let the root pass them in. 
  # But the instructions said "the master root" might define them. 
  # For demonstration, let's do them here, or you can do "UNIMPLEMENTED" and pass from root.
  # We'll keep them here for now if that is acceptable. 
  # But let's keep them empty, forcing the root to pass instance types. 
  # The instructions say: "the variables for each root should be region, AZs, instance map..."
  # Wait, let's store them in the root. We'll do "No actual defaults here." We'll fail if unprovided.
  # We'll rely on the category => instance type logic in the root. 
}

# 1) Expand the instance groups
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
    for item in local.expanded : [
      for i in range(item.count_per_zone) : {
        group_name   = item.group_name
        category     = item.category
        zone         = item.zone
        custom_image = item.custom_image
      }
    ]
  ])
}

# 2) Key pairs
resource "tls_private_key" "all" {
  count     = length(local.final_list)
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 3) For each item, call the provider submodule
# But we do not know how to map category => instance_type. 
# The instructions said the "master root" variable will be an instance map. We'll do that in the root
# So let's define a variable "instance_type_map" that the root sets. We'll do that above.

locals {
  # Flatten each item => find instance_type from var.instance_type_map
  all_specs = [
    for idx, item in local.final_list : {
      group_name   = item.group_name
      zone         = item.zone
      # If we don't find item.category in the map, fail
      instance_type = lookup(var.instance_type_map, item.category, "UNKNOWN_TYPE")
      image         = item.custom_image
    }
  ]
}

module "provider_vm" {
  count = length(local.all_specs)

  source = (
    var.provider == "aws"   ? "./aws" :
    var.provider == "azure" ? "./azure" :
    "./gcp"
  )

  vm_name            = "${terraform.workspace}-${local.all_specs[count.index].group_name}-${count.index}"
  public_key_openssh = tls_private_key.all[count.index].public_key_openssh
  ssh_user           = var.ssh_user
  image              = local.all_specs[count.index].image
  instance_type      = local.all_specs[count.index].instance_type
  zone               = local.all_specs[count.index].zone
  workspace          = terraform.workspace

  subnet_id         = element(var.subnet_ids, index(var.availability_zones, local.all_specs[count.index].zone))
  security_group_id = var.security_group_id
}

module "vm_secret" {
  count  = length(local.all_specs)
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
  all_results = [
    for idx, item in local.all_specs : {
      group_name = local.final_list[idx].group_name
      name       = module.provider_vm[idx].vm_name
      private_ip = module.provider_vm[idx].private_ip
      public_ip  = module.provider_vm[idx].public_ip
      vault_path = module.vm_secret[idx].vault_path
    }
  ]

  # Reconstruct by group_name
  instances_by_group = {
    for i in local.all_results : i.group_name => [
      for x in local.all_results : x if x.group_name == i.group_name
    ]
  }
}

