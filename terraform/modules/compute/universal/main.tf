terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

locals {
  expanded_groups = flatten([
    for g in var.instance_groups : [
      for z in var.availability_zones : {
        group_name     = g.name
        architecture   = g.architecture
        size           = g.size
        zone           = z
        count_per_zone = g.count_per_zone
      }
    ]
  ])

  all_items = flatten([
    for item in local.expanded_groups : [
      for i in range(item.count_per_zone) : {
        group_name   = item.group_name
        architecture = item.architecture
        size         = item.size
        zone         = item.zone
      }
    ]
  ])
}

resource "tls_private_key" "keys" {
  count     = length(local.all_items)
  algorithm = "RSA"
  rsa_bits  = 4096
  sensitive = true
  ephemeral = true
}

module "single_vm" {
  count = length(local.all_items)

  source = "/amoebius/terraform/modules/compute/${var.provider}/single_vm"

  vm_name       = "${terraform.workspace}-${local.all_items[count.index].group_name}-${count.index}"
  architecture  = local.all_items[count.index].architecture
  instance_type = lookup(
    var.instance_type_map,
    "${local.all_items[count.index].architecture}_${local.all_items[count.index].size}",
    "t3.micro" # fallback
  )
  subnet_id         = element(var.subnet_ids, index(var.availability_zones, local.all_items[count.index].zone))
  security_group_id = var.security_group_id
  public_key_openssh = tls_private_key.keys[count.index].public_key_openssh
  disk_size_gb       = var.disk_size_gb
  region             = var.region
}

module "ssh_vm_secret" {
  count = length(local.all_items)
  source = "/amoebius/terraform/modules/ssh/vm_secret"

  public_ip       = module.single_vm[count.index].public_ip
  private_key_pem = tls_private_key.keys[count.index].private_key_pem
  ssh_user        = var.ssh_user
  vault_role_name = var.vault_role_name
  no_verify_ssl   = var.no_verify_ssl
  provider        = var.provider
}

locals {
  all_results_flat = [
    for idx, it in local.all_items : {
      group_name = it.group_name
      name       = module.single_vm[idx].vm_name
      private_ip = module.single_vm[idx].private_ip
      public_ip  = module.single_vm[idx].public_ip
      vault_path = module.ssh_vm_secret[idx].vault_path
    }
  ]

  instances_by_group = {
    for grp in var.instance_groups : grp.name => [
      for r in local.all_results_flat : r if r.group_name == grp.name
    ]
  }
}
