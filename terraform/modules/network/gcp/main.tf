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

resource "google_compute_network" "vpc" {
  name                    = "${terraform.workspace}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public_subnets" {
  count         = length(var.availability_zones)
  name          = "${terraform.workspace}-subnet-${count.index}"
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = cidrsubnet(var.vpc_cidr, 8, count.index)
  region        = replace(var.availability_zones[count.index], "/(.*)-(.*)-(.*)/", "$1-$2")
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
