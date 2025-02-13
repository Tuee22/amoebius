######################################
# main.tf for ssh_vault_secret module
######################################

locals {
  triggers = {
    vault_role_name = var.vault_role_name
    path            = var.path
    user            = var.user
    hostname        = var.hostname
    port            = tostring(var.port)
    no_verify_ssl   = var.no_verify_ssl ? "true" : "false"
  }
}

resource "null_resource" "vault_ssh_secret" {
  triggers = local.triggers

  provisioner "local-exec" {
    command = <<EOT
python -m amoebius.cli.secrets.ssh store \
  --vault-role-name="${self.triggers.vault_role_name}" \
  --path="${self.triggers.path}" \
  --user="${self.triggers.user}" \
  --hostname="${self.triggers.hostname}" \
  --port="${self.triggers.port}" \
  --private-key="${var.private_key}" \
  ${self.triggers.no_verify_ssl == "true" ? "--no-verify-ssl" : ""}
EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
python -m amoebius.cli.secrets.ssh delete \
  --vault-role-name="${self.triggers.vault_role_name}" \
  --path="${self.triggers.path}" \
  ${self.triggers.no_verify_ssl == "true" ? "--no-verify-ssl" : ""}
EOT
  }
}

output "vault_path" {
  description = "The Vault path where the SSH config was stored."
  value       = var.path
}
