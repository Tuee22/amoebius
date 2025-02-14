#!/usr/bin/env bash

set -e

echo "Overwriting compute and cluster modules with new final layout..."

###############################################################################
# 1) Recreate /compute subfolders: aws, azure, gcp, plus top-level .tf
###############################################################################

mkdir -p amoebius/terraform/modules/compute/aws
mkdir -p amoebius/terraform/modules/compute/azure
mkdir -p amoebius/terraform/modules/compute/gcp

###############################################################################
# 1A) Minimal provider subfolders
###############################################################################

#################### AWS ####################
cat <<'EOF' > amoebius/terraform/modules/compute/aws/main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  # region from environment or root
}

# This module expects variables to be passed from the top-level compute module:
#   vm_name, public_key_openssh, ssh_user, image, instance_type, subnet_id, security_group_id, zone, workspace

resource "aws_key_pair" "this" {
  key_name   = "${var.workspace}-${var.vm_name}"
  public_key = var.public_key_openssh
}

resource "aws_instance" "this" {
  ami           = var.image
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = aws_key_pair.this.key_name

  tags = {
    Name = "${var.workspace}-${var.vm_name}"
  }
}
EOF

cat <<'EOF' > amoebius/terraform/modules/compute/aws/variables.tf
# Minimal variables - only what's needed for the raw AWS resource.
variable "vm_name" {}
variable "public_key_openssh" {}
variable "ssh_user" {}
variable "image" {}
variable "instance_type" {}
variable "subnet_id" {}
variable "security_group_id" {}
variable "zone" {}
variable "workspace" {}
EOF

cat <<'EOF' > amoebius/terraform/modules/compute/aws/outputs.tf
output "vm_name" {
  value = aws_instance.this.tags["Name"]
}

output "private_ip" {
  value = aws_instance.this.private_ip
}

output "public_ip" {
  value = aws_instance.this.public_ip
}
EOF

#################### AZURE ####################
cat <<'EOF' > amoebius/terraform/modules/compute/azure/main.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_public_ip" "this" {
  name                = "${var.workspace}-${var.vm_name}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [var.zone]
}

resource "azurerm_network_interface" "this" {
  name                = "${var.workspace}-${var.vm_name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.this.id
    subnet_id                     = var.subnet_id
  }
}

resource "azurerm_network_interface_security_group_association" "sg_assoc" {
  network_interface_id      = azurerm_network_interface.this.id
  network_security_group_id = var.security_group_id
}

resource "azurerm_linux_virtual_machine" "this" {
  name                = "${var.workspace}-${var.vm_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.instance_type
  zone                = var.zone

  admin_username                  = var.ssh_user
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.this.id]

  admin_ssh_key {
    username   = var.ssh_user
    public_key = var.public_key_openssh
  }

  source_image_id = var.image

  os_disk {
    name                 = "${var.workspace}-${var.vm_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 30
  }
}
EOF

cat <<'EOF' > amoebius/terraform/modules/compute/azure/variables.tf
variable "vm_name" {}
variable "public_key_openssh" {}
variable "ssh_user" {}
variable "image" {}
variable "instance_type" {}
variable "subnet_id" {}
variable "security_group_id" {}
variable "zone" {}
variable "workspace" {}

variable "resource_group_name" {}
variable "location" {
  default = "eastus"
}
EOF

cat <<'EOF' > amoebius/terraform/modules/compute/azure/outputs.tf
output "vm_name" {
  value = azurerm_linux_virtual_machine.this.name
}

output "private_ip" {
  value = azurerm_network_interface.this.ip_configuration[0].private_ip_address
}

output "public_ip" {
  value = azurerm_public_ip.this.ip_address
}
EOF

#################### GCP ####################
cat <<'EOF' > amoebius/terraform/modules/compute/gcp/main.tf
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  # project or region from environment or root
}

resource "google_compute_instance" "this" {
  name         = "${var.workspace}-${var.vm_name}"
  zone         = var.zone
  machine_type = var.instance_type

  network_interface {
    subnetwork   = var.subnet_id
    access_config {}
  }

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.public_key_openssh}"
  }

  tags = ["allow-ssh"]
}
EOF

cat <<'EOF' > amoebius/terraform/modules/compute/gcp/variables.tf
variable "vm_name" {}
variable "public_key_openssh" {}
variable "ssh_user" {}
variable "image" {}
variable "instance_type" {}
variable "subnet_id" {}
variable "security_group_id" {}
variable "zone" {}
variable "workspace" {}
EOF

cat <<'EOF' > amoebius/terraform/modules/compute/gcp/outputs.tf
output "vm_name" {
  value = google_compute_instance.this.name
}

output "private_ip" {
  value = google_compute_instance.this.network_interface[0].network_ip
}

output "public_ip" {
  value = google_compute_instance.this.network_interface[0].access_config[0].nat_ip
}
EOF


###############################################################################
# 1B) The top-level /amoebius/terraform/modules/compute/* for single VM,
#     but provider-agnostic logic
###############################################################################

# We'll create (or overwrite) variables.tf, main.tf, outputs.tf here
mkdir -p amoebius/terraform/modules/compute

cat <<'EOF' > amoebius/terraform/modules/compute/variables.tf
variable "provider" {
  type        = string
  description = "Which provider (aws, azure, gcp)?"
}

variable "vm_name" {
  type        = string
  description = "Name for the VM instance"
}

variable "public_key_openssh" {
  type        = string
  description = "SSH public key in OpenSSH format"
}

variable "ssh_user" {
  type        = string
  default     = "ubuntu"
}

variable "image" {
  type        = string
  description = "Image/AMI to use"
}

variable "instance_type" {
  type        = string
}

variable "subnet_id" {
  type        = string
  description = "Subnet or subnetwork to place this VM"
}

variable "security_group_id" {
  type        = string
  description = "Security group or firewall ID"
}

variable "zone" {
  type        = string
  description = "Which zone or AZ"
}

variable "workspace" {
  type        = string
  default     = "default"
}

# For Azure only, we might need a resource_group_name, location
variable "resource_group_name" {
  type        = string
  default     = ""
}

variable "location" {
  type        = string
  default     = ""
}

EOF

cat <<'EOF' > amoebius/terraform/modules/compute/main.tf
terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# We do minimal single-VM logic here, referencing the subfolder for actual resources
locals {
  provider_paths = {
    "aws"   = "./aws"
    "azure" = "./azure"
    "gcp"   = "./gcp"
  }
}

module "single_vm" {
  source = local.provider_paths[var.provider]

  vm_name            = var.vm_name
  public_key_openssh = var.public_key_openssh
  ssh_user           = var.ssh_user
  image              = var.image
  instance_type      = var.instance_type
  subnet_id          = var.subnet_id
  security_group_id  = var.security_group_id
  zone               = var.zone
  workspace          = var.workspace

  resource_group_name = var.resource_group_name
  location            = var.location
}
EOF

cat <<'EOF' > amoebius/terraform/modules/compute/outputs.tf
output "vm_name" {
  description = "VM name or ID"
  value       = module.single_vm.vm_name
}

output "private_ip" {
  description = "VM private IP"
  value       = module.single_vm.private_ip
}

output "public_ip" {
  description = "VM public IP"
  value       = module.single_vm.public_ip
}
EOF


###############################################################################
# 2) /amoebius/terraform/modules/cluster - the multi-VM fan-out
###############################################################################

mkdir -p amoebius/terraform/modules/cluster

cat <<'EOF' > amoebius/terraform/modules/cluster/variables.tf
variable "provider" {
  type = string
}

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
    image          = optional(string, "")
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

# For azure usage
variable "resource_group_name" {
  type    = string
  default = ""
}

variable "location" {
  type    = string
  default = ""
}
EOF

cat <<'EOF' > amoebius/terraform/modules/cluster/main.tf
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

# Create a private key for each VM
resource "tls_private_key" "all" {
  count     = length(local.final_list)
  algorithm = "RSA"
  rsa_bits  = 4096
}

# For each item, we look up the instance type from var.instance_type_map
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
  count  = length(local.all_specs)
  source = "/amoebius/terraform/modules/compute"

  provider           = var.provider
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

  vault_prefix = "/amoebius/ssh/${var.provider}/${terraform.workspace}"
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
      for r in results : r if r.group_name == g.name
    ]
  }
}
EOF

cat <<'EOF' > amoebius/terraform/modules/cluster/outputs.tf
output "instances_by_group" {
  description = "Map of group_name => list of VM objects (name, private_ip, public_ip, vault_path)"
  value       = local.instances_by_group
}
EOF

echo "Done! /amoebius/terraform/modules/compute/* now has single-VM logic in main. The minimal code for each provider is in subfolders. The /amoebius/terraform/modules/cluster module does fan-out."
