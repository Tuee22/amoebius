locals {
  chosen_zones = length(var.availability_zones) > 0
    ? var.availability_zones
    : lookup(var.zones_by_provider, var.provider, [])

  chosen_region = var.region != ""
    ? var.region
    : lookup(var.region_by_provider, var.provider, "")

  chosen_type_map = lookup(var.instance_type_maps, var.provider, {})
}

locals {
  network_source = {
    aws   = "/amoebius/terraform/modules/network/aws"
    azure = "/amoebius/terraform/modules/network/azure"
    gcp   = "/amoebius/terraform/modules/network/gcp"
  }[var.provider]
}

module "network" {
  source = local.network_source

  vpc_cidr          = var.vpc_cidr
  availability_zones = local.chosen_zones
  region            = local.chosen_region
}

module "compute" {
  source = "/amoebius/terraform/modules/compute/universal"

  provider          = var.provider
  availability_zones = local.chosen_zones
  instance_groups    = var.instance_groups
  instance_type_map  = local.chosen_type_map

  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.security_group_id

  disk_size_gb    = var.disk_size_gb
  ssh_user        = var.ssh_user
  vault_role_name = var.vault_role_name
  no_verify_ssl   = var.no_verify_ssl
  region          = local.chosen_region
}
