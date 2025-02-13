terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  # project, region from environment
}

locals {
  # Hypothetical default 24.04 LTS
  default_ubuntu_image = "projects/ubuntu-os-cloud/global/images/ubuntu-2404-lts"
}

resource "google_compute_instance" "this" {
  name         = "${var.workspace}-${var.vm_name}"
  zone         = var.zone
  machine_type = var.instance_type

  network_interface {
    subnetwork   = var.subnet_self_link
    access_config {}
  }

  boot_disk {
    initialize_params {
      image = length(var.image) > 0 ? var.image : local.default_ubuntu_image
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.public_key_openssh}"
  }

  tags = ["allow-ssh"]
}

output "vm_name" {
  value = google_compute_instance.this.name
}

output "private_ip" {
  value = google_compute_instance.this.network_interface[0].network_ip
}

output "public_ip" {
  value = google_compute_instance.this.network_interface[0].access_config[0].nat_ip
}
