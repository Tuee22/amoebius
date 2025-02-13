terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  default_ami_x86 = "ami-08c40ec9ead489470"
  default_ami_arm = "ami-0f52bda759e8e4aa4"
}

resource "aws_key_pair" "this" {
  key_name   = "${terraform.workspace}-${var.vm_name}"
  public_key = var.public_key_openssh
}

resource "aws_instance" "this" {
  ami           = var.architecture == "arm" ? local.default_ami_arm : local.default_ami_x86
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = aws_key_pair.this.key_name

  tags = {
    Name = "${terraform.workspace}-${var.vm_name}"
  }

  root_block_device {
    volume_size = var.disk_size_gb
    volume_type = "gp2"
  }
}
