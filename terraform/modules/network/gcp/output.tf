output "vpc_id" {
  value = google_compute_network.vpc.name
}

output "subnet_ids" {
  value = [for s in google_compute_subnetwork.public_subnets : s.self_link]
}

output "subnet_cidrs" {
  value = [for s in google_compute_subnetwork.public_subnets : s.ip_cidr_range]
}

output "security_group_id" {
  value = google_compute_firewall.allow_ssh.self_link
}
