output "vpc_id" {
  value = aws_vpc.this.id
}

output "subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "subnet_cidrs" {
  value = [for s in aws_subnet.public : s.cidr_block]
}

output "security_group_id" {
  value = aws_security_group.this.id
}
