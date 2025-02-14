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
