output "host" {
  value = minikube_cluster.terraform-cluster.host
}

output "client_certificate" {
  value     = minikube_cluster.terraform-cluster.client_certificate
  sensitive = true
}

output "client_key" {
  value     = minikube_cluster.terraform-cluster.client_key
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = minikube_cluster.terraform-cluster.cluster_ca_certificate
  sensitive = true
}
