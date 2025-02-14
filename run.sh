#!/usr/bin/env bash

################################################################################
# populate.sh
# Creates all folders and .tf files per your final refactoring requirements.
################################################################################

set -e

# 1) Create directories
mkdir -p amoebius/terraform/modules/network/{aws,azure,gcp}
mkdir -p amoebius/terraform/modules/compute/{aws,azure,gcp}
# "universal" logic sits directly in /compute as main.tf,variables.tf,outputs.tf
mkdir -p amoebius/terraform/modules/ssh/{vault_secret,vm_secret}

mkdir -p amoebius/terraform/roots/{aws-root,azure-root,gcp-root}
# We'll place an example shell script for usage at the same level
# => amoebius/terraform/roots/deploy_examples.sh

################################################################################
# 2) NETWORK MODULES
################################################################################

######################################
# 2A) AWS NETWORK
######################################
mkdir -p amoebius/terraform/modules/network/aws

# variables.tf
cat <<'EOF' > amoebius/terraform/modules/network/aws/variables.tf
variable "region" {
  type        = string
  description = "AWS region."
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  default     = []
  description = "List of AWS AZs in this region."
}
EOF

# main.tf
cat <<'EOF' > amoebius/terraform/modules/network/aws/main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${terraform.workspace}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${terraform.workspace}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${terraform.workspace}-public-rt"
  }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${terraform.workspace}-subnet-${count.index}"
  }
}

resource "aws_route_table_association" "public_subnet" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "this" {
  name        = "${terraform.workspace}-ssh-sg"
  description = "Security group for SSH"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${terraform.workspace}-ssh-sg"
  }
}
EOF

# outputs.tf
cat <<'EOF' > amoebius/terraform/modules/network/aws/outputs.tf
output "vpc_id" {
  value = aws_vpc.this.id
}

output "subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "security_group_id" {
  value = aws_security_group.this.id
}
EOF

######################################
# 2B) AZURE NETWORK
######################################
mkdir -p amoebius/terraform/modules/network/azure
cat <<'EOF' > amoebius/terraform/modules/network/azure/variables.tf
variable "region" {
  type        = string
  description = "Azure region, e.g. eastus"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  default     = []
}
EOF

cat <<'EOF' > amoebius/terraform/modules/network/azure/main.tf
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

resource "azurerm_resource_group" "main" {
  name     = "${terraform.workspace}-rg"
  location = var.region
}

resource "azurerm_resource_group" "network_watcher" {
  name     = "${terraform.workspace}-NetworkWatcherRG"
  location = var.region
}

resource "azurerm_network_watcher" "main" {
  name                = "NetworkWatcher_${var.region}"
  location            = var.region
  resource_group_name = azurerm_resource_group.network_watcher.name
}

resource "azurerm_virtual_network" "main" {
  name                = "${terraform.workspace}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vpc_cidr]
}

resource "azurerm_subnet" "subnets" {
  count                = length(var.availability_zones)
  name                 = "${terraform.workspace}-subnet-${count.index}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vpc_cidr, 8, count.index)]
}

resource "azurerm_network_security_group" "ssh" {
  name                = "${terraform.workspace}-ssh-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow_ssh"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
EOF

cat <<'EOF' > amoebius/terraform/modules/network/azure/outputs.tf
output "vpc_id" {
  value = azurerm_virtual_network.main.id
}

output "subnet_ids" {
  value = [for s in azurerm_subnet.subnets : s.id]
}

output "security_group_id" {
  value = azurerm_network_security_group.ssh.id
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}
EOF

######################################
# 2C) GCP NETWORK
######################################
mkdir -p amoebius/terraform/modules/network/gcp
cat <<'EOF' > amoebius/terraform/modules/network/gcp/variables.tf
variable "region" {
  type        = string
  description = "GCP region, e.g. us-central1"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  default     = []
}
EOF

cat <<'EOF' > amoebius/terraform/modules/network/gcp/main.tf
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.region  # Not typical, but let's assume user sets the GCP project in 'region' or via env
  # Usually you'd do region = "us-central1", but let's keep it minimal
}

resource "google_compute_network" "vpc" {
  name                    = "${terraform.workspace}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public_subnets" {
  count         = length(var.availability_zones)
  name          = "${terraform.workspace}-subnet-${count.index}"
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = cidrsubnet(var.vpc_cidr, 8, count.index)
  region        = replace(var.availability_zones[count.index], "/(.*)-(.*)-(.*)/", "$1-$2") # Simplistic
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${terraform.workspace}-allow-ssh"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-ssh"]
}
EOF

cat <<'EOF' > amoebius/terraform/modules/network/gcp/outputs.tf
output "vpc_id" {
  value = google_compute_network.vpc.name
}

output "subnet_ids" {
  value = [for s in google_compute_subnetwork.public_subnets : s.self_link]
}

output "security_group_id" {
  value = google_compute_firewall.allow_ssh.self_link
}
EOF

################################################################################
# 3) PROVIDER-SPECIFIC COMPUTE MODULES
################################################################################

# We'll place standard variables, main, outputs. No placeholder "UNIMPLEMENTED".

#### AWS ####
mkdir -p amoebius/terraform/modules/compute/aws
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
  description = "AMI override"
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


#### AZURE ####
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
  description = "Custom or default image ID"
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

# For real usage, we need the resource group name, so let's accept that:
variable "resource_group_name" {
  type        = string
  description = "Azure resource group name to place this VM"
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
  location            = "eastus"
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [var.zone]
}

resource "azurerm_network_interface" "this" {
  name                = "${var.workspace}-${var.vm_name}-nic"
  location            = "eastus"
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
  location            = "eastus"
  size                = var.instance_type
  zone                = var.zone

  admin_username                  = var.ssh_user
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.this.id]

  admin_ssh_key {
    username   = var.ssh_user
    public_key = var.public_key_openssh
  }

  # We assume var.image is an ID of a managed or gallery image
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
  value = azurerm_linux_virtual_machine.this.name
}

output "private_ip" {
  value = azurerm_network_interface.this.ip_configuration[0].private_ip_address
}

output "public_ip" {
  value = azurerm_public_ip.this.ip_address
}
EOF


#### GCP ####
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
  description = "Custom or default GCP image"
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
  # project or region from env or root
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
  value = google_compute_instance.this.name
}

output "private_ip" {
  value = google_compute_instance.this.network_interface[0].network_ip
}

output "public_ip" {
  value = google_compute_instance.this.network_interface[0].access_config[0].nat_ip
}
EOF

################################################################################
# 4) UNIVERSAL /compute (fan-out)
################################################################################
# We'll create variables.tf, main.tf, outputs.tf in /amoebius/terraform/modules/compute

# variables.tf
cat <<'EOF' > amoebius/terraform/modules/compute/variables.tf
variable "provider" {
  type        = string
  description = "aws, azure, or gcp"
}

variable "availability_zones" {
  type        = list(string)
  default     = []
  description = "Which zones to use."
}

variable "subnet_ids" {
  type        = list(string)
  description = "One subnet per zone index."
}

variable "security_group_id" {
  type        = string
  description = "SG or firewall ID that allows SSH."
}

variable "instance_groups" {
  type = list(object({
    name           = string
    category       = string   # e.g. 'arm_small','x86_small','nvidia_medium'
    count_per_zone = number
    image          = optional(string, "")
  }))
  default = []
}

variable "instance_type_map" {
  type    = map(string)
  default = {}
  description = "Maps from category => instance_type"
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
EOF

# main.tf
cat <<'EOF' > amoebius/terraform/modules/compute/main.tf
terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

locals {
  # Table lookup for submodule folder path
  provider_subfolders = {
    "aws"   = "./aws"
    "azure" = "./azure"
    "gcp"   = "./gcp"
  }
}

# 1) expand instance groups
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

# 2) For each item, pick instance_type from var.instance_type_map
#    If var.instance_type_map does not contain the category, it fails or returns blank
locals {
  item_specs = [
    for idx, i in local.final_list : {
      group_name    = i.group_name
      zone          = i.zone
      instance_type = lookup(var.instance_type_map, i.category, "MISSING_TYPE")
      image         = i.custom_image
      # The rest is used directly
    }
  ]
}

module "provider_vm" {
  count = length(local.item_specs)

  source = local.provider_subfolders[var.provider]

  vm_name            = "${terraform.workspace}-${local.item_specs[count.index].group_name}-${count.index}"
  public_key_openssh = tls_private_key.all[count.index].public_key_openssh
  ssh_user           = var.ssh_user

  image         = local.item_specs[count.index].image
  instance_type = local.item_specs[count.index].instance_type
  zone          = local.item_specs[count.index].zone
  workspace     = terraform.workspace

  subnet_id = element(var.subnet_ids, index(var.availability_zones, local.item_specs[count.index].zone))
  security_group_id = var.security_group_id

  # If azure, we likely also need resource_group_name. That is typically from the root, or from the network module output
  # We'll handle that in the root if needed (by making 'subnet_id' be a data reference?). 
}

module "vm_secret" {
  count = length(local.item_specs)
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
  # Combine results
  all_results = [
    for idx, s in local.item_specs : {
      group_name = local.final_list[idx].group_name
      name       = module.provider_vm[idx].vm_name
      private_ip = module.provider_vm[idx].private_ip
      public_ip  = module.provider_vm[idx].public_ip
      vault_path = module.vm_secret[idx].vault_path
    }
  ]

  instances_by_group = {
    for i in local.final_list : i.group_name => [
      for x in all_results : x if x.group_name == i.group_name
    ]
  }
}
EOF

# outputs.tf
cat <<'EOF' > amoebius/terraform/modules/compute/outputs.tf
output "instances_by_group" {
  description = "Map of group_name => list of { name, private_ip, public_ip, vault_path }"
  value       = local.instances_by_group
}
EOF


################################################################################
# 5) SSH modules: vault_secret & vm_secret
################################################################################
mkdir -p amoebius/terraform/modules/ssh/vault_secret
mkdir -p amoebius/terraform/modules/ssh/vm_secret

#### vault_secret ####
cat <<'EOF' > amoebius/terraform/modules/ssh/vault_secret/variables.tf
variable "vault_role_name" {
  type        = string
  description = "Vault Kubernetes auth role name."
}

variable "path" {
  type        = string
  description = "Vault path for storing SSH keys"
}

variable "user" {
  type        = string
}

variable "hostname" {
  type        = string
}

variable "port" {
  type    = number
  default = 22
}

variable "private_key" {
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "no_verify_ssl" {
  type    = bool
  default = true
}
EOF

cat <<'EOF' > amoebius/terraform/modules/ssh/vault_secret/main.tf
locals {
  triggers = {
    vault_role_name = var.vault_role_name
    path            = var.path
    user            = var.user
    hostname        = var.hostname
    port            = tostring(var.port)
    no_verify_ssl   = var.no_verify_ssl ? "true" : "false"
  }
}

resource "null_resource" "vault_ssh_secret" {
  triggers = local.triggers

  provisioner "local-exec" {
    command = <<EOT
python -m amoebius.cli.secrets.ssh store \
  --vault-role-name="${self.triggers.vault_role_name}" \
  --path="${self.triggers.path}" \
  --user="${self.triggers.user}" \
  --hostname="${self.triggers.hostname}" \
  --port="${self.triggers.port}" \
  --private-key="${var.private_key}" \
  ${self.triggers.no_verify_ssl == "true" ? "--no-verify-ssl" : ""}
EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
python -m amoebius.cli.secrets.ssh delete \
  --vault-role-name="${self.triggers.vault_role_name}" \
  --path="${self.triggers.path}" \
  ${self.triggers.no_verify_ssl == "true" ? "--no-verify-ssl" : ""}
EOT
  }
}
EOF

cat <<'EOF' > amoebius/terraform/modules/ssh/vault_secret/outputs.tf
output "vault_path" {
  description = "Vault path where SSH was stored."
  value       = var.path
}
EOF

#### vm_secret ####
cat <<'EOF' > amoebius/terraform/modules/ssh/vm_secret/variables.tf
variable "vm_name" {
  type = string
}

variable "public_ip" {
  type = string
}

variable "private_key_pem" {
  type        = string
  sensitive   = true
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "port" {
  type    = number
  default = 22
}

variable "vault_role_name" {
  type    = string
  default = "amoebius-admin-role"
}

variable "no_verify_ssl" {
  type    = bool
  default = true
}

variable "vault_prefix" {
  type = string
}
EOF

cat <<'EOF' > amoebius/terraform/modules/ssh/vm_secret/main.tf
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

resource "null_resource" "wait_for_ssh" {
  provisioner "remote-exec" {
    inline = [
      "echo 'Testing SSH for ${var.vm_name}'"
    ]
    connection {
      type        = "ssh"
      host        = var.public_ip
      user        = var.ssh_user
      private_key = var.private_key_pem
      port        = var.port
    }
  }
}

resource "random_id" "path_suffix" {
  byte_length = 4
  depends_on  = [null_resource.wait_for_ssh]
}

module "vault" {
  source = "../vault_secret"

  depends_on = [random_id.path_suffix]

  vault_role_name = var.vault_role_name
  user            = var.ssh_user
  hostname        = var.public_ip
  port            = var.port
  private_key     = var.private_key_pem
  no_verify_ssl   = var.no_verify_ssl

  path = "${var.vault_prefix}/${random_id.path_suffix.hex}"
}
EOF

cat <<'EOF' > amoebius/terraform/modules/ssh/vm_secret/outputs.tf
output "vault_path" {
  value = module.vault.vault_path
}
EOF

################################################################################
# 6) MASTER ROOTS
################################################################################

############################
# 6A) AWS MASTER ROOT
############################
mkdir -p amoebius/terraform/roots/aws-root

# variables.tf
cat <<'EOF' > amoebius/terraform/roots/aws-root/variables.tf
variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a","us-east-1b","us-east-1c"]
}

# Default instance_type_map. The user can override if they want
variable "instance_type_map" {
  type = map(string)
  default = {
    "arm_small"  = "t4g.micro"
    "x86_small"  = "t3.micro"
    "x86_medium" = "t3.small"
    "nvidia_small" = "g4dn.xlarge"
  }
}

variable "arm_default_image" {
  type    = string
  default = "ami-0faefad027f3b5de6" # e.g. hypothetical Ubuntu 24.04 ARM for us-east-1
  # in reality you'll pick the official 24.04 once it's out
}

variable "x86_default_image" {
  type    = string
  default = "ami-0c8a4fc5fa843b2c2" # e.g. hypothetical Ubuntu 24.04 x86
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
EOF

# main.tf
cat <<'EOF' > amoebius/terraform/roots/aws-root/main.tf
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
  source = "/amoebius/terraform/modules/network/aws"

  region            = var.region
  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
}

# We inject default images if user hasn't specified. We'll do that by rewriting instance_groups ourselves
# so that if 'image' is blank, we assign arm_default_image or x86_default_image depending on category prefix.

locals {
  final_instance_groups = [
    for g in var.instance_groups : {
      name           = g.name
      category       = g.category
      count_per_zone = g.count_per_zone
      image          = (
        length(try(g.image,"")) > 0
        ? g.image
        : (
          startswith(g.category, "arm_") ? var.arm_default_image : var.x86_default_image
        )
      )
    }
  ]
}

module "compute" {
  source = "/amoebius/terraform/modules/compute"

  provider          = "aws"
  availability_zones = var.availability_zones
  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.security_group_id

  instance_groups   = local.final_instance_groups
  instance_type_map = var.instance_type_map

  ssh_user         = var.ssh_user
  vault_role_name  = var.vault_role_name
  no_verify_ssl    = var.no_verify_ssl
}

EOF

# outputs.tf
cat <<'EOF' > amoebius/terraform/roots/aws-root/outputs.tf
output "instances_by_group" {
  value = module.compute.instances_by_group
}
EOF

############################
# 6B) AZURE MASTER ROOT
############################
mkdir -p amoebius/terraform/roots/azure-root

cat <<'EOF' > amoebius/terraform/roots/azure-root/variables.tf
variable "region" {
  type    = string
  default = "eastus"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["1","2","3"]
}

variable "instance_type_map" {
  type = map(string)
  default = {
    "arm_small"   = "Standard_D2ps_v5",
    "x86_small"   = "Standard_D2s_v5",
    "nvidia_small"= "Standard_NC4as_T4_v3"
  }
}

variable "arm_default_image" {
  type    = string
  default = "/subscriptions/123abc/resourceGroups/myRG/providers/Microsoft.Compute/galleries/24_04_arm/images/latest"
}

variable "x86_default_image" {
  type    = string
  default = "/subscriptions/123abc/resourceGroups/myRG/providers/Microsoft.Compute/galleries/24_04_x86/images/latest"
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
EOF

cat <<'EOF' > amoebius/terraform/roots/azure-root/main.tf
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
  source = "/amoebius/terraform/modules/network/azure"

  region            = var.region
  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
}

# We'll produce final instance_groups with defaults for ARM vs x86
locals {
  final_instance_groups = [
    for g in var.instance_groups : {
      name           = g.name
      category       = g.category
      count_per_zone = g.count_per_zone
      image          = (
        length(try(g.image,"")) > 0
        ? g.image
        : (
          startswith(g.category, "arm_") ? var.arm_default_image : var.x86_default_image
        )
      )
    }
  ]
}

module "compute" {
  source = "/amoebius/terraform/modules/compute"

  provider          = "azure"
  availability_zones= var.availability_zones
  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.security_group_id

  instance_groups   = local.final_instance_groups
  instance_type_map = var.instance_type_map

  ssh_user         = var.ssh_user
  vault_role_name  = var.vault_role_name
  no_verify_ssl    = var.no_verify_ssl
}
EOF

cat <<'EOF' > amoebius/terraform/roots/azure-root/outputs.tf
output "instances_by_group" {
  value = module.compute.instances_by_group
}
EOF


############################
# 6C) GCP MASTER ROOT
############################
mkdir -p amoebius/terraform/roots/gcp-root

cat <<'EOF' > amoebius/terraform/roots/gcp-root/variables.tf
variable "region" {
  type    = string
  default = "us-central1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-central1-a","us-central1-b","us-central1-f"]
}

variable "instance_type_map" {
  type = map(string)
  default = {
    "arm_small"    = "t2a-standard-1",
    "x86_small"    = "e2-small",
    "nvidia_small" = "a2-highgpu-1g"
  }
}

variable "arm_default_image" {
  type    = string
  default = "projects/ubuntu-os-cloud/global/images/ubuntu-2404-lts-arm64"
}

variable "x86_default_image" {
  type    = string
  default = "projects/ubuntu-os-cloud/global/images/ubuntu-2404-lts"
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
EOF

cat <<'EOF' > amoebius/terraform/roots/gcp-root/main.tf
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
  project = var.region  # or set from env
}

module "network" {
  source = "/amoebius/terraform/modules/network/gcp"

  region            = var.region
  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
}

locals {
  final_instance_groups = [
    for g in var.instance_groups : {
      name           = g.name
      category       = g.category
      count_per_zone = g.count_per_zone
      image = (
        length(try(g.image,"")) > 0
        ? g.image
        : (
          startswith(g.category, "arm_") ? var.arm_default_image : var.x86_default_image
        )
      )
    }
  ]
}

module "compute" {
  source = "/amoebius/terraform/modules/compute"

  provider          = "gcp"
  availability_zones= var.availability_zones
  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.security_group_id

  instance_groups   = local.final_instance_groups
  instance_type_map = var.instance_type_map

  ssh_user         = var.ssh_user
  vault_role_name  = var.vault_role_name
  no_verify_ssl    = var.no_verify_ssl
}
EOF

cat <<'EOF' > amoebius/terraform/roots/gcp-root/outputs.tf
output "instances_by_group" {
  value = module.compute.instances_by_group
}
EOF

################################################################################
# 7) EXAMPLE DEPLOY SCRIPT
################################################################################
cat <<'EOF' > amoebius/terraform/roots/deploy_examples.sh
#!/usr/bin/env bash
#
# Simple demonstration of using the master roots with multiple workspaces.
#

set -e

# Example: AWS "simple" cluster
echo "=== AWS SIMPLE ==="
cd aws-root
terraform init
terraform workspace new simple || terraform workspace select simple
terraform apply -auto-approve -var 'instance_groups=[{
  name           = "x86_demo",
  category       = "x86_small",
  count_per_zone = 1
}]'
cd ..

# Example: AWS "ha" cluster with both ARM and x86
echo "=== AWS HA ==="
cd aws-root
terraform workspace new ha || terraform workspace select ha
terraform apply -auto-approve -var 'instance_groups=[
  { name="arm_nodes",category="arm_small",count_per_zone=1 },
  { name="x86_nodes",category="x86_small",count_per_zone=2 }
]'
cd ..

# Example: Azure with a single ARM group
echo "=== AZURE SIMPLE ==="
cd ../azure-root
terraform init
terraform workspace new simple || terraform workspace select simple
terraform apply -auto-approve -var 'instance_groups=[{
  name="arm_machine",
  category="arm_small",
  count_per_zone=1
}]'
cd ..

# Example: GCP with an x86 group
echo "=== GCP SIMPLE ==="
cd ../gcp-root
terraform init
terraform workspace new simple || terraform workspace select simple
terraform apply -auto-approve -var 'instance_groups=[{
  name="x86_nodes",
  category="x86_small",
  count_per_zone=1
}]'
cd ..

echo "=== Examples deployed! ==="
EOF

chmod +x amoebius/terraform/roots/deploy_examples.sh

echo "All files have been created successfully!"
