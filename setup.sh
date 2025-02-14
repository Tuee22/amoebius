#!/usr/bin/env bash

# Overwrite just the necessary files for the final refactor:
# 1) /amoebius/terraform/modules/compute/aws/* (single VM logic)
# 2) /amoebius/terraform/modules/compute/azure/* (single VM logic)
# 3) /amoebius/terraform/modules/compute/gcp/* (single VM logic)
# 4) new /amoebius/terraform/modules/cluster with variables.tf, main.tf, outputs.tf
#    containing the fan-out and flattening logic.


#######################################################
# 1) Overwrite "compute/aws" (SINGLE VM ONLY)
#######################################################
mkdir -p amoebius/terraform/modules/compute/aws

# variables.tf
cat <<'EOF' > amoebius/terraform/modules/compute/aws/variables.tf
variable "vm_name" {
  type = string
}

variable "public_key_openssh" {
  type = string
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "image" {
  type        = string
  description = "AMI to use"
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "zone" {
  type    = string
}

variable "workspace" {
  type    = string
  default = "default"
}
EOF

# main.tf
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
  # region is set at root or from environment
}

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

# outputs.tf
cat <<'EOF' > amoebius/terraform/modules/compute/aws/outputs.tf
output "vm_name" {
  description = "Name or ID of this AWS VM"
  value       = aws_instance.this.tags["Name"]
}

output "private_ip" {
  description = "Private IP address of this AWS VM"
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IP address of this AWS VM"
  value       = aws_instance.this.public_ip
}
EOF

#######################################################
# 2) Overwrite "compute/azure" (SINGLE VM ONLY)
#######################################################
mkdir -p amoebius/terraform/modules/compute/azure

cat <<'EOF' > amoebius/terraform/modules/compute/azure/variables.tf
variable "vm_name" {
  type = string
}

variable "public_key_openssh" {
  type = string
}

variable "ssh_user" {
  type    = string
  default = "azureuser"
}

variable "image" {
  type        = string
  description = "Azure image (or shared gallery ID)"
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "zone" {
  type = string
}

variable "workspace" {
  type    = string
  default = "default"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name in which to place this VM"
}
EOF

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
  location            = "PLACEHOLDER-LOCATION" # Typically you'd pass location if needed
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [var.zone]
}

resource "azurerm_network_interface" "this" {
  name                = "${var.workspace}-${var.vm_name}-nic"
  resource_group_name = var.resource_group_name
  location            = "PLACEHOLDER-LOCATION"

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
  location            = "PLACEHOLDER-LOCATION"
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

cat <<'EOF' > amoebius/terraform/modules/compute/azure/outputs.tf
output "vm_name" {
  description = "Name of this Azure VM"
  value       = azurerm_linux_virtual_machine.this.name
}

output "private_ip" {
  description = "Private IP address of this VM"
  value       = azurerm_network_interface.this.ip_configuration[0].private_ip_address
}

output "public_ip" {
  description = "Public IP address of this VM"
  value       = azurerm_public_ip.this.ip_address
}
EOF

#######################################################
# 3) Overwrite "compute/gcp" (SINGLE VM ONLY)
#######################################################
mkdir -p amoebius/terraform/modules/compute/gcp

cat <<'EOF' > amoebius/terraform/modules/compute/gcp/variables.tf
variable "vm_name" {
  type = string
}

variable "public_key_openssh" {
  type = string
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "image" {
  type        = string
  description = "Full image link for GCP"
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "zone" {
  type = string
}

variable "workspace" {
  type    = string
  default = "default"
}
EOF

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

cat <<'EOF' > amoebius/terraform/modules/compute/gcp/outputs.tf
output "vm_name" {
  description = "Name of this GCP VM instance"
  value       = google_compute_instance.this.name
}

output "private_ip" {
  description = "Private IP of this GCP VM"
  value       = google_compute_instance.this.network_interface[0].network_ip
}

output "public_ip" {
  description = "Public IP of this GCP VM"
  value       = google_compute_instance.this.network_interface[0].access_config[0].nat_ip
}
EOF


#######################################################
# 4) Create /amoebius/terraform/modules/cluster
#    This purely wraps the fan-out logic and references
#    the "compute/<provider>" modules plus the ssh/vm_secret
#######################################################
mkdir -p amoebius/terraform/modules/cluster

# variables.tf
cat <<'EOF' > amoebius/terraform/modules/cluster/variables.tf
variable "provider" {
  type        = string
  description = "aws, azure, or gcp"
}

variable "subnet_ids" {
  type        = list(string)
  description = "One subnet per zone"
}

variable "availability_zones" {
  type        = list(string)
  default     = []
  description = "List of zones in the region."
}

variable "security_group_id" {
  type        = string
  description = "SG / firewall ID that allows SSH"
}

variable "instance_groups" {
  type = list(object({
    name           = string
    category       = string
    count_per_zone = number
    # optional custom image
    image          = optional(string, "")
  }))
  default = []
}

variable "instance_type_map" {
  type    = map(string)
  default = {}
  description = "Maps category => instance_type"
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

# If Azure, we might also need resource_group_name. We'll accept it here
variable "azure_resource_group_name" {
  type        = string
  default     = ""
  description = "If provider=azure, pass the RG name here, so we can feed the single VM module"
}
EOF

# main.tf
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
  # We'll do a small table to pick the sub-folder for the single VM
  compute_subfolder = {
    aws   = "/amoebius/terraform/modules/compute/aws"
    azure = "/amoebius/terraform/modules/compute/azure"
    gcp   = "/amoebius/terraform/modules/compute/gcp"
  }
}

# 1) expand instance_groups => final list
locals {
  expanded_groups = flatten([
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
    for item in local.expanded_groups : [
      for i in range(item.count_per_zone) : {
        group_name   = item.group_name
        category     = item.category
        zone         = item.zone
        custom_image = item.custom_image
      }
    ]
  ])
}

resource "tls_private_key" "all" {
  count     = length(local.final_list)
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 2) For each item, we find its instance_type in instance_type_map
locals {
  item_specs = [
    for idx, it in local.final_list : {
      group_name    = it.group_name
      zone          = it.zone
      instance_type = lookup(var.instance_type_map, it.category, "UNKNOWN")
      image         = it.custom_image
    }
  ]
}

module "vms" {
  count = length(local.item_specs)
  source = local.compute_subfolder[var.provider]

  vm_name            = "${terraform.workspace}-${local.item_specs[count.index].group_name}-${count.index}"
  public_key_openssh = tls_private_key.all[count.index].public_key_openssh
  ssh_user           = var.ssh_user

  image         = local.item_specs[count.index].image
  instance_type = local.item_specs[count.index].instance_type
  zone          = local.item_specs[count.index].zone
  workspace     = terraform.workspace

  subnet_id        = element(var.subnet_ids, index(var.availability_zones, local.item_specs[count.index].zone))
  security_group_id= var.security_group_id

  # If Azure, pass resource_group_name
  resource_group_name = var.azure_resource_group_name
}

module "ssh_vm_secret" {
  count  = length(local.item_specs)
  source = "/amoebius/terraform/modules/ssh/vm_secret"

  vm_name         = module.vms[count.index].vm_name
  public_ip       = module.vms[count.index].public_ip
  private_key_pem = tls_private_key.all[count.index].private_key_pem
  ssh_user        = var.ssh_user
  vault_role_name = var.vault_role_name
  no_verify_ssl   = var.no_verify_ssl

  vault_prefix = "/amoebius/ssh/${var.provider}/${terraform.workspace}"
}

locals {
  all_results = [
    for idx, i in local.item_specs : {
      group_name = local.final_list[idx].group_name
      name       = module.vms[idx].vm_name
      private_ip = module.vms[idx].private_ip
      public_ip  = module.vms[idx].public_ip
      vault_path = module.ssh_vm_secret[idx].vault_path
    }
  ]

  instances_by_group = {
    for grp in var.instance_groups : grp.name => [
      for x in all_results : x if x.group_name == grp.name
    ]
  }
}
EOF

# outputs.tf
cat <<'EOF' > amoebius/terraform/modules/cluster/outputs.tf
output "instances_by_group" {
  description = "Map of group_name => list of VMs {name, private_ip, public_ip, vault_path}"
  value       = local.instances_by_group
}
EOF


echo "Overwrite script complete. The 'compute' modules now handle single VMs only, and the new '/amoebius/terraform/modules/cluster' does the fan-out logic."
