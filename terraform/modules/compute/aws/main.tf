terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  # region is set at root or from environment
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
