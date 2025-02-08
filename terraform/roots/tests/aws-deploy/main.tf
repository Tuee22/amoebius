###############################################################################
# main.tf - Full Terraform Module
###############################################################################

###############################################################################
# 1) Terraform Settings & Kubernetes Backend
###############################################################################
terraform {
  backend "kubernetes" {
    secret_suffix     = "test-aws-deploy"
    load_config_file  = false
    namespace         = "amoebius"
    in_cluster_config = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

###############################################################################
# 2) Variables
###############################################################################
variable "region" {
  type        = string
  description = "The AWS region to deploy in."
  default     = "us-east-1"
}

variable "aws_access_key_id" {
  type        = string
  description = "AWS Access Key ID."
  sensitive   = true
}

variable "aws_secret_access_key" {
  type        = string
  description = "AWS Secret Access Key."
  sensitive   = true
}

variable "availability_zones" {
  type        = list(string)
  description = "List of Availability Zones in which to create subnets and EC2 instances."
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# ------------------------------------------------------------------
# Variables for Vault usage
# ------------------------------------------------------------------
variable "vault_role_name" {
  type        = string
  description = "Vault Kubernetes auth role name used by the ssh_vault_secret module."
  default     = "amoebius-admin-role"
}

variable "ssh_user" {
  type        = string
  description = "SSH username to configure on the remote host."
  default     = "ubuntu"
}

variable "no_verify_ssl" {
  type        = bool
  description = "Disable SSL certificate verification for Vault calls."
  default     = true
}

###############################################################################
# 3) AWS Provider
###############################################################################
provider "aws" {
  region     = var.region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

###############################################################################
# 4) Data Sources
###############################################################################
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

###############################################################################
# 5) Generate an SSH Key Pair Per AZ
###############################################################################
resource "tls_private_key" "ssh" {
  count     = length(var.availability_zones)
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh" {
  count      = length(var.availability_zones)
  key_name   = "${terraform.workspace}-ec2-key-${count.index}"
  public_key = tls_private_key.ssh[count.index].public_key_openssh
}

###############################################################################
# 6) VPC & Networking
###############################################################################
resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${terraform.workspace}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${terraform.workspace}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${terraform.workspace}-public-rt"
  }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.this.id
  cidr_block             = "10.0.${count.index}.0/24"
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${terraform.workspace}-public-subnet-${count.index}"
  }
}

resource "aws_route_table_association" "public_subnet" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

###############################################################################
# 7) Custom Security Group (Avoid AWS Default SG)
###############################################################################
resource "aws_security_group" "this" {
  name        = "${terraform.workspace}-custom-sg"
  description = "Security group for SSH ingress"
  vpc_id      = aws_vpc.this.id

  # Allow SSH Inbound from anywhere (adjust as needed)
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${terraform.workspace}-custom-sg"
  }
}

###############################################################################
# 8) Create EC2 Instances (One Per AZ) With Unique SSH Keys
###############################################################################
resource "aws_instance" "ubuntu" {
  count         = length(var.availability_zones)
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public[count.index].id
  key_name      = aws_key_pair.ssh[count.index].key_name

  # Use our custom security group
  vpc_security_group_ids = [aws_security_group.this.id]

  tags = {
    Name = "${terraform.workspace}-test-aws-deployment-${count.index}"
  }
}

###############################################################################
# 9) Wait for Instances to be SSH-Accessible
###############################################################################
# This resource ensures the instance is fully started, networked, and listening
# on port 22 before we do anything that requires live SSH connectivity.
# resource "null_resource" "wait_for_ssh" {
#   count = length(var.availability_zones)


#   connection {
#     type        = "ssh"
#     host        = aws_instance.ubuntu[count.index].public_ip
#     user        = var.ssh_user
#     private_key = tls_private_key.ssh[count.index].private_key_pem
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "echo 'Instance is up and SSH connection successful.'"
#     ]
#   }
# }

###############################################################################
# 10) Store Each Private Key in Vault
###############################################################################
module "ssh_vault_secret" {
  source = "/amoebius/terraform/modules/ssh_vault_secret"

  count            = length(var.availability_zones)
  vault_role_name  = var.vault_role_name
  user             = var.ssh_user
  hostname         = aws_instance.ubuntu[count.index].public_ip
  port             = 22
  private_key      = tls_private_key.ssh[count.index].private_key_pem
  no_verify_ssl    = var.no_verify_ssl

  # Construct a unique path for each key
  path = "amoebius/tests/aws-test-deploy/ssh/${terraform.workspace}-ec2-key-${count.index}"

  # Ensure we only run after the instance is confirmed accessible by SSH
  #depends_on = [null_resource.wait_for_ssh]
  depends_on = [
    aws_instance.ubuntu, 
    aws_security_group.this
  ]

}

###############################################################################
# 11) Outputs
###############################################################################
output "vpc_id" {
  description = "The ID of the created VPC."
  value       = aws_vpc.this.id
}

output "subnet_ids" {
  description = "List of subnet IDs, one per AZ."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "instance_ids" {
  description = "List of all Ubuntu instance IDs created, one per AZ."
  value       = [for instance in aws_instance.ubuntu : instance.id]
}

output "public_ips" {
  description = "List of public IP addresses for the Ubuntu instances."
  value       = [for instance in aws_instance.ubuntu : instance.public_ip]
}

output "private_ips" {
  description = "List of private IP addresses for the Ubuntu instances."
  value       = [for instance in aws_instance.ubuntu : instance.private_ip]
}

output "security_group_id" {
  description = "The ID of the custom security group used by the instances."
  value       = aws_security_group.this.id
}

output "vault_ssh_keys" {
  description = "Vault paths where each SSH private key is stored."
  value       = [for vault_secret in module.ssh_vault_secret : vault_secret.vault_path]
}