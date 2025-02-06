############################################
# 1. Variables & Provider Configuration
############################################

variable "aws_access_key_id" {
  type      = string
  sensitive = true
  description = "Your AWS Access Key ID (long-lived credential)."
}

variable "aws_secret_access_key" {
  type      = string
  sensitive = true
  description = "Your AWS Secret Access Key (long-lived credential)."
}

variable "region" {
  type    = string
  default = "us-east-1"
  description = "AWS region to deploy into."
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
  description = "List of AZs in the chosen region. One subnet + instance per AZ."
}

variable "vault_addr" {
  type        = string
  default     = "http://vault.vault.svc.cluster.local:8200"
  description = "Base address of Vault (if needed for the ssh_vault_secret module)."
}

# This is the 'ssh_vault_secret' module you already have.
# Adjust the source path to wherever you store that module code.
variable "no_verify_ssl" {
  type    = bool
  default = false
  description = "Disable Vault SSL verification if needed."
}

# The default Ubuntu ARM64 AMI lookup for Focal 20.04 (owner Canonical).
# You can customize the filters for a different Ubuntu release or region.
data "aws_ami" "ubuntu_arm" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-arm64-server-*"]
  }
  filter {
    name   = "architecture"
    values = ["arm64"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

provider "aws" {
  region                  = var.region
  access_key             = var.aws_access_key_id
  secret_key             = var.aws_secret_access_key
  # Or set credentials in your environment instead of storing them in TF variables
}

# If needed, configure the rke provider (assuming a local run).
# Make sure you have 'provider "rke" {}' in your required_providers block.
provider "rke" {}

############################################
# 2. Create a VPC with subnets in each AZ
############################################

resource "aws_vpc" "main" {
  cidr_block = "10.10.0.0/16"

  tags = {
    Name = "example-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "example-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "example-public-rt"
  }
}

# One subnet per AZ in var.availability_zones
resource "aws_subnet" "public_subnet" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet("10.10.0.0/16", 4, count.index)
  availability_zone = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "example-subnet-${var.availability_zones[count.index]}"
  }
}

resource "aws_route_table_association" "public_assoc" {
  count          = length(var.availability_zones)
  route_table_id = aws_route_table.public_rt.id
  subnet_id      = aws_subnet.public_subnet[count.index].id
}

############################################
# 3. Create one EC2 instance (Ubuntu ARM) per subnet, each with its own key
############################################

# Generate a separate SSH keypair per instance
resource "tls_private_key" "vm_key" {
  count = length(var.availability_zones)
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "vm_key" {
  count = length(var.availability_zones)
  key_name   = "my_vm_key_${count.index}"
  public_key = tls_private_key.vm_key[count.index].public_key_openssh
}

resource "aws_instance" "vm" {
  count         = length(var.availability_zones)
  ami           = data.aws_ami.ubuntu_arm.id
  instance_type = "t4g.small"  # an ARM instance type
  subnet_id     = aws_subnet.public_subnet[count.index].id
  vpc_security_group_ids = [aws_vpc.main.default_security_group_id]
  key_name      = aws_key_pair.vm_key[count.index].key_name
  associate_public_ip_address = true  # So we can SSH from the internet if needed

  tags = {
    Name = "example-ubuntu-arm-${count.index}"
  }
}

############################################
# 4. Wait for each VM to be "SSH up",
#    then store the private key in Vault
############################################

# Wait for each instance to be responsive (a simplistic approach).
# We use remote-exec to do a quick "echo" or "uptime" test.
# This ensures the instance is truly up & listening on SSH.
resource "null_resource" "wait_for_ssh" {
  count = length(var.availability_zones)

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = aws_instance.vm[count.index].public_ip
    private_key = tls_private_key.vm_key[count.index].private_key_pem
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'SSH is up!'"
    ]
  }
}

# Now that each VM is definitely up,
# we run the "ssh_vault_secret" module to store the private key in Vault.
module "ssh_secrets" {
  source = "./modules/ssh_vault_secret" # Adjust path as needed

  for_each         = toset([for i in range(length(var.availability_zones)) : tostring(i)])
  vault_role_name  = "my_k8s_role"   # or whatever your Vault K8s role is
  path             = "secrets/ssh/server-${each.key}"
  user             = "ubuntu"
  hostname         = aws_instance.vm[tonumber(each.key)].public_ip
  port             = 22
  private_key      = tls_private_key.vm_key[tonumber(each.key)].private_key_pem
  no_verify_ssl    = var.no_verify_ssl

  depends_on = [
    null_resource.wait_for_ssh[tonumber(each.key)]
  ]
}

############################################
# 5. Use the RKE provider to configure a k8s cluster
#    with each VM as a control plane node
############################################

# We define one "rke_cluster" with multi-node, fully HA setup:
resource "rke_cluster" "k8s" {
  # We'll create a node definition for each VM, specifying:
  #   - public IP address
  #   - SSH user
  #   - SSH key (the same key Terraform created earlier)
  #   - roles: controlplane, etcd, worker
  nodes = [
    for i in range(length(var.availability_zones)) : {
      address          = aws_instance.vm[i].public_ip
      user             = "ubuntu"
      ssh_key          = tls_private_key.vm_key[i].private_key_pem
      role             = ["controlplane", "etcd", "worker"]
    }
  ]

  # For a real cluster, you'd also specify:
  # network {
  #   plugin = "canal"
  # }
  # services {
  #   etcd {
  #     snapshot        = true
  #     creation        = 6
  #     retention       = 24
  #   }
  # }
}

############################################
# Outputs (Optional)
############################################

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "public_subnets" {
  description = "IDs of the created public subnets"
  value       = [for s in aws_subnet.public_subnet : s.id]
}

output "instance_public_ips" {
  description = "Public IP addresses of the created instances"
  value       = [for vm in aws_instance.vm : vm.public_ip]
}

output "rke_kube_config" {
  description = "Kubeconfig for the RKE cluster"
  value       = rke_cluster.k8s.kube_config_yaml
  sensitive   = true
}