#!/usr/bin/env bash
#
# remove_default_images_and_make_image_required.sh
#
# 1) Removes all references to arm_default_image and x86_default_image from the
#    AWS/Azure/GCP *root* modules in /amoebius/terraform/roots/providers/.
# 2) Changes "instance_groups" so that "image" is mandatory (no longer optional).
# 3) Removes any fallback references to "try(g.image, '')" or
#    "startswith(...) ? var.arm_default_image : var.x86_default_image"
#    in the /amoebius/terraform/modules/providers/{aws,azure,gcp}/cluster code.
#
# Run from /amoebius directory:
#   ./remove_default_images_and_make_image_required.sh
#

set -e

###############################################################################
# PART 1: Overwrite the *root* modules to remove references to arm_default_image/x86_default_image
#         and make "image" mandatory in instance_groups.
###############################################################################

#############################
# AWS root - main.tf
#############################
cat > terraform/roots/providers/aws/main.tf <<'EOF'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.region
}

module "network" {
  source             = "/amoebius/terraform/modules/providers/aws/network"
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "cluster" {
  source = "/amoebius/terraform/modules/providers/aws/cluster"

  availability_zones  = var.availability_zones
  subnet_ids          = module.network.subnet_ids
  security_group_id   = module.network.security_group_id
  instance_groups     = var.instance_groups
  instance_type_map   = var.instance_type_map
  ssh_user            = var.ssh_user
  vault_role_name     = var.vault_role_name
  no_verify_ssl       = var.no_verify_ssl

  # For AWS, resource_group_name is typically unused, but we keep them for consistency
  resource_group_name = ""
  location            = var.region
}
EOF

#############################
# AWS root - variables.tf
#############################
cat > terraform/roots/providers/aws/variables.tf <<'EOF'
variable "region" {
  type        = string
  description = "Cloud region (e.g. us-west-1)."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block."
}

variable "availability_zones" {
  type        = list(string)
  description = "List of zones/AZs."
}

variable "instance_type_map" {
  type        = map(string)
  description = "Map of category => instance type."
}

# 'image' is now mandatory
variable "instance_groups" {
  type = list(object({
    name           = string
    category       = string
    count_per_zone = number
    image          = string
  }))
  description = "All instance group definitions (image is now required)."
}

variable "ssh_user" {
  type        = string
  description = "SSH username."
}

variable "vault_role_name" {
  type        = string
  description = "Vault role name for storing SSH keys."
}

variable "no_verify_ssl" {
  type        = bool
  description = "If true, skip SSL verification for Vault calls."
}
EOF


#############################
# Azure root - main.tf
#############################
cat > terraform/roots/providers/azure/main.tf <<'EOF'
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

module "network" {
  source             = "/amoebius/terraform/modules/providers/azure/network"
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "cluster" {
  source = "/amoebius/terraform/modules/providers/azure/cluster"

  availability_zones  = var.availability_zones
  subnet_ids          = module.network.subnet_ids
  security_group_id   = module.network.security_group_id
  instance_groups     = var.instance_groups
  instance_type_map   = var.instance_type_map
  ssh_user            = var.ssh_user
  vault_role_name     = var.vault_role_name
  no_verify_ssl       = var.no_verify_ssl

  resource_group_name = module.network.resource_group_name
  location            = var.region
}
EOF

#############################
# Azure root - variables.tf
#############################
cat > terraform/roots/providers/azure/variables.tf <<'EOF'
variable "region" {
  type        = string
  description = "Cloud region (e.g. eastus)."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block."
}

variable "availability_zones" {
  type        = list(string)
  description = "List of zones/AZs."
}

variable "instance_type_map" {
  type        = map(string)
  description = "Map of category => instance type."
}

# 'image' is mandatory now
variable "instance_groups" {
  type = list(object({
    name           = string
    category       = string
    count_per_zone = number
    image          = string
  }))
  description = "All instance group definitions (image is now required)."
}

variable "ssh_user" {
  type        = string
  description = "SSH username."
  default     = "azureuser"
}

variable "vault_role_name" {
  type        = string
  description = "Vault role name for storing SSH keys."
}

variable "no_verify_ssl" {
  type        = bool
  description = "If true, skip SSL verification for Vault calls."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the Azure resource group."
}
EOF


#############################
# GCP root - main.tf
#############################
cat > terraform/roots/providers/gcp/main.tf <<'EOF'
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "google" {
  project = var.region
}

module "network" {
  source             = "/amoebius/terraform/modules/providers/gcp/network"
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "cluster" {
  source = "/amoebius/terraform/modules/providers/gcp/cluster"

  availability_zones  = var.availability_zones
  subnet_ids          = module.network.subnet_ids
  security_group_id   = module.network.security_group_id
  instance_groups     = var.instance_groups
  instance_type_map   = var.instance_type_map
  ssh_user            = var.ssh_user
  vault_role_name     = var.vault_role_name
  no_verify_ssl       = var.no_verify_ssl

  resource_group_name = ""
  location            = var.region
}
EOF

#############################
# GCP root - variables.tf
#############################
cat > terraform/roots/providers/gcp/variables.tf <<'EOF'
variable "region" {
  type        = string
  description = "GCP region (e.g. us-central1)."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block."
}

variable "availability_zones" {
  type        = list(string)
  description = "List of zones/AZs."
}

variable "instance_type_map" {
  type        = map(string)
  description = "Map of category => instance type."
}

# 'image' is mandatory now
variable "instance_groups" {
  type = list(object({
    name           = string
    category       = string
    count_per_zone = number
    image          = string
  }))
  description = "All instance group definitions (image is now required)."
}

variable "ssh_user" {
  type        = string
  description = "SSH username."
}

variable "vault_role_name" {
  type        = string
  description = "Vault role name for storing SSH keys."
}

variable "no_verify_ssl" {
  type        = bool
  description = "If true, skip SSL verification for Vault calls."
}
EOF

###############################################################################
# PART 2: Overwrite the cluster modules to remove fallback logic and ensure we
#         just use 'g.image' directly, since it's now mandatory.
###############################################################################

#############################
# AWS cluster: variables.tf
#############################
cat > terraform/modules/providers/aws/cluster/variables.tf <<'EOF'
variable "availability_zones" {
  type    = list(string)
  default = []
}

variable "subnet_ids" {
  type        = list(string)
  description = "One subnet per zone"
}

variable "security_group_id" {
  type        = string
}

variable "instance_groups" {
  type = list(object({
    name           = string
    category       = string
    count_per_zone = number
    # image is mandatory
    image          = string
  }))
  default = []
}

variable "instance_type_map" {
  type    = map(string)
  default = {}
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "vault_role_name" {
  type    = string
  default = "amoebius-admin-role"
}

variable "no_verify_ssl" {
  type    = bool
  default = true
}

# For AWS, we might not need resource_group_name / location, but let's keep them for consistency
variable "resource_group_name" {
  type    = string
  default = ""
}

variable "location" {
  type    = string
  default = ""
}
EOF

#############################
# AWS cluster: main.tf
#############################
cat > terraform/modules/providers/aws/cluster/main.tf <<'EOF'
terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Flatten out instance groups (but no fallback for images)
locals {
  expanded = flatten([
    for g in var.instance_groups : [
      for z in var.availability_zones : {
        group_name     = g.name
        category       = g.category
        zone           = z
        count_per_zone = g.count_per_zone
        custom_image   = g.image
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

  source = "/amoebius/terraform/modules/providers/aws/compute"

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

  # Hardcode 'aws' here
  vault_prefix = "/amoebius/ssh/aws/${terraform.workspace}"
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
EOF


#############################
# Azure cluster: variables.tf
#############################
cat > terraform/modules/providers/azure/cluster/variables.tf <<'EOF'
variable "availability_zones" {
  type    = list(string)
  default = []
}

variable "subnet_ids" {
  type        = list(string)
  description = "One subnet per zone"
}

variable "security_group_id" {
  type        = string
}

variable "instance_groups" {
  type = list(object({
    name           = string
    category       = string
    count_per_zone = number
    # image required
    image          = string
  }))
  default = []
}

variable "instance_type_map" {
  type    = map(string)
  default = {}
}

variable "ssh_user" {
  type    = string
  default = "azureuser"
}

variable "vault_role_name" {
  type    = string
  default = "amoebius-admin-role"
}

variable "no_verify_ssl" {
  type    = bool
  default = true
}

variable "resource_group_name" {
  type    = string
  default = ""
}

variable "location" {
  type    = string
  default = ""
}
EOF

#############################
# Azure cluster: main.tf
#############################
cat > terraform/modules/providers/azure/cluster/main.tf <<'EOF'
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
        custom_image   = g.image
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
EOF


#############################
# GCP cluster: variables.tf
#############################
cat > terraform/modules/providers/gcp/cluster/variables.tf <<'EOF'
variable "availability_zones" {
  type    = list(string)
  default = []
}

variable "subnet_ids" {
  type        = list(string)
  description = "One subnet per zone"
}

variable "security_group_id" {
  type        = string
}

variable "instance_groups" {
  type = list(object({
    name           = string
    category       = string
    count_per_zone = number
    image          = string
  }))
  default = []
}

variable "instance_type_map" {
  type    = map(string)
  default = {}
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "vault_role_name" {
  type    = string
  default = "amoebius-admin-role"
}

variable "no_verify_ssl" {
  type    = bool
  default = true
}

variable "resource_group_name" {
  type    = string
  default = ""
}

variable "location" {
  type    = string
  default = ""
}
EOF

#############################
# GCP cluster: main.tf
#############################
cat > terraform/modules/providers/gcp/cluster/main.tf <<'EOF'
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
        custom_image   = g.image
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

  source = "/amoebius/terraform/modules/providers/gcp/compute"

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

  vault_prefix = "/amoebius/ssh/gcp/${terraform.workspace}"
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
EOF

echo "Done! All references to default images removed, and 'image' is now mandatory in instance_groups."