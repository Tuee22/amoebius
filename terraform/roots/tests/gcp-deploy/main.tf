###############################################################################
# main.tf - Example GCP ARM Deploy in us-central1 (Iowa) with Vault SSH Storage
###############################################################################

###############################################################################
# 1) Variables
###############################################################################
variable "project_id" {
  type        = string
  description = "GCP project ID where resources will be created."
}

variable "region" {
  type        = string
  description = "The GCP region to deploy in."
  default     = "us-central1"
}

variable "availability_zones" {
  type        = list(string)
  description = "Zones in us-central1 that support T2A."
  default     = ["us-central1-a", "us-central1-b", "us-central1-f"]
}

variable "service_account_key_json" {
  type        = string
  description = "Entire GCP service account JSON key, as a single string."
  sensitive   = true
  default     = <<EOF
EOF
}

variable "ssh_user" {
  type        = string
  description = "SSH username to configure on the VM instances."
  default     = "ubuntu"
}

variable "vault_role_name" {
  type        = string
  description = "Vault role name used to store SSH keys."
  default     = "amoebius-admin-role"
}

variable "no_verify_ssl" {
  type        = bool
  description = "Disable SSL verification for Vault."
  default     = false
}

###############################################################################
# 2) Terraform Settings & Provider
###############################################################################
terraform {
  backend "kubernetes" {
    secret_suffix     = "test-gcp-deploy"
    load_config_file  = false
    namespace         = "amoebius"
    in_cluster_config = true
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project     = var.project_id
  credentials = var.service_account_key_json
  region      = var.region
}

###############################################################################
# 3) Data Source: ARM64 Ubuntu Image
###############################################################################
data "google_compute_image" "ubuntu_2204_arm64" {
  family  = "ubuntu-2204-lts-arm64"
  project = "ubuntu-os-cloud"
}

###############################################################################
# 4) TLS Key Pairs (Per VM)
###############################################################################
resource "tls_private_key" "ssh_keys" {
  count     = length(var.availability_zones)
  algorithm = "RSA"
  rsa_bits  = 2048
}

###############################################################################
# 5) Create a Custom VPC & 3 Subnets
###############################################################################
resource "google_compute_network" "vpc" {
  name                    = "${terraform.workspace}-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

resource "google_compute_subnetwork" "public_subnets" {
  count         = length(var.availability_zones)
  name          = "${terraform.workspace}-subnet-${count.index}"
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = "10.0.${count.index}.0/24"
  region        = var.region
  project       = var.project_id
}

###############################################################################
# 6) Firewall Rule for SSH
###############################################################################
resource "google_compute_firewall" "allow_ssh" {
  name    = "${terraform.workspace}-allow-ssh"
  network = google_compute_network.vpc.self_link
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-ssh"]
}

###############################################################################
# 7) Create T2A Instances (one in each zone)
###############################################################################
resource "google_compute_instance" "vms" {
  count        = length(var.availability_zones)
  name         = "${terraform.workspace}-vm-${count.index}"
  machine_type = "t2a-standard-1"  # 1 vCPU, 4 GB RAM (ARM64)
  zone         = var.availability_zones[count.index]
  project      = var.project_id

  network_interface {
    subnetwork   = google_compute_subnetwork.public_subnets[count.index].self_link
    access_config {}
  }

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu_2204_arm64.self_link
    }
  }

  tags = ["allow-ssh"]

  metadata = {
    ssh-keys = "${var.ssh_user}:${tls_private_key.ssh_keys[count.index].public_key_openssh}"
  }
}

###############################################################################
# 8) Store SSH Keys in Vault (After VM Creation)
###############################################################################
module "ssh_vault_secret" {
  source = "/amoebius/terraform/modules/ssh_vault_secret"

  count            = length(var.availability_zones)
  vault_role_name  = var.vault_role_name
  user             = var.ssh_user
  hostname         = google_compute_instance.vms[count.index].network_interface[0].access_config[0].nat_ip
  port             = 22
  private_key      = tls_private_key.ssh_keys[count.index].private_key_pem
  no_verify_ssl    = var.no_verify_ssl

  path = "amoebius/tests/gcp-test-deploy/ssh/${terraform.workspace}-vm-key-${count.index}"

  depends_on = [
    google_compute_instance.vms,
    google_compute_firewall.allow_ssh
  ]
}

###############################################################################
# 9) Outputs
###############################################################################
output "vpc_name" {
  description = "The created VPC (network) name."
  value       = google_compute_network.vpc.name
}

output "subnet_names" {
  description = "Names of created subnets (one per zone)."
  value       = [for s in google_compute_subnetwork.public_subnets : s.name]
}

output "instance_names" {
  description = "Names of the GCP Compute instances."
  value       = [for vm in google_compute_instance.vms : vm.name]
}

output "public_ips" {
  description = "Public IP addresses of instances."
  value       = [for vm in google_compute_instance.vms : vm.network_interface[0].access_config[0].nat_ip]
}

output "private_ips" {
  description = "Private IP addresses of instances."
  value       = [for vm in google_compute_instance.vms : vm.network_interface[0].network_ip]
}

output "vault_ssh_key_paths" {
  description = "Vault paths where SSH keys are stored."
  value       = [for i in range(length(var.availability_zones)) : "amoebius/tests/gcp-test-deploy/ssh/${terraform.workspace}-vm-key-${i}"]
}