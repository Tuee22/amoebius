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
