variable "vm_name" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_self_link" {
  type = string
}

variable "public_key_openssh" {
  type = string
}

variable "image" {
  type    = string
  default = ""
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "workspace" {
  type    = string
  default = "default"
}
