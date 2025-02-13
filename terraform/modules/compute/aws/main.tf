terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  # region from env or root
}

# Hard-code a default 24.04 AMI (this is hypothetical!)
locals {
  default_ubuntu_ami = "ami-024404EXAMPLE"  # For demonstration
}

resource "aws_key_pair" "this" {
  key_name   = "${var.workspace}-${var.vm_name}"
  public_key = var.public_key_openssh
}

resource "aws_instance" "this" {
  ami           = length(var.image) > 0 ? var.image : local.default_ubuntu_ami
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = aws_key_pair.this.key_name

  tags = {
    Name = "${var.workspace}-${var.vm_name}"
  }
}

output "vm_name" {
  value = aws_instance.this.tags["Name"]
}

output "private_ip" {
  value = aws_instance.this.private_ip
}

output "public_ip" {
  value = aws_instance.this.public_ip
}
