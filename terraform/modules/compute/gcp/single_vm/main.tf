terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  region = var.region
}

locals {
  default_image_x86 = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
  default_image_arm = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts-arm64"
}

resource "google_compute_instance" "vm" {
  name         = "${terraform.workspace}-${var.vm_name}"
  zone         = "${var.region}-a"  # or you can pass zone if you prefer
  machine_type = var.instance_type

  network_interface {
    subnetwork   = var.subnet_id
    access_config {}
  }

  boot_disk {
    initialize_params {
      image = var.architecture == "arm" ? local.default_image_arm : local.default_image_x86
      size  = var.disk_size_gb
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${var.public_key_openssh}"
  }

  tags = ["allow-ssh"]
}
