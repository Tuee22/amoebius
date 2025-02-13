terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  # region from environment or root
}

resource "aws_key_pair" "this" {
  key_name   = "${var.workspace}-${var.vm_name}"
  public_key = var.public_key_openssh
}

resource "aws_instance" "this" {
  ami           = var.image
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = aws_key_pair.this.key_name

  tags = {
    Name = "${var.workspace}-${var.vm_name}"
  }
}

# Overwrite unimplemented outputs
output "vm_name" {
  value = aws_instance.this.tags["Name"]
}

output "private_ip" {
  value = aws_instance.this.private_ip
}

output "public_ip" {
  value = aws_instance.this.public_ip
}
