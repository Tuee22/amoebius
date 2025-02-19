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
