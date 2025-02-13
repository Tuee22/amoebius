terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

resource "null_resource" "wait_for_ssh" {
  provisioner "remote-exec" {
    inline = [
      "echo 'SSH check succeeded for ${var.vm_name}'"
    ]
    connection {
      type        = "ssh"
      host        = var.public_ip
      user        = var.ssh_user
      private_key = var.private_key_pem
      port        = var.port
    }
  }
}

resource "random_id" "vault_uuid" {
  byte_length = 4
  depends_on  = [null_resource.wait_for_ssh]
}

module "vault_secret" {
  source = "/amoebius/terraform/modules/ssh_vault_secret"

  depends_on = [random_id.vault_uuid]

  vault_role_name = var.vault_role_name
  user            = var.ssh_user
  hostname        = var.public_ip
  port            = var.port
  private_key     = var.private_key_pem
  no_verify_ssl   = var.no_verify_ssl

  path = "${var.vault_prefix}/${random_id.vault_uuid.hex}"
}

output "vault_path" {
  value = module.vault_secret.vault_path
}
