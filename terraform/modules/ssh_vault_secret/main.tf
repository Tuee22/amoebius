locals {
  # Only the non-secret parameters go into triggers,
  # so the private_key won't be stored in state.
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
  # These triggers let Terraform know when to re-run the store step.
  triggers = local.triggers

  provisioner "local-exec" {
    # Called on create/update (terraform apply).
    command = <<EOT
python -m amoebius.cli.secrets.ssh store \
  --vault-role-name="${var.vault_role_name}" \
  --path="${var.path}" \
  --user="${var.user}" \
  --hostname="${var.hostname}" \
  --port="${var.port}" \
  --private-key="${var.private_key}" \
  ${var.no_verify_ssl ? "--no-verify-ssl" : ""}
EOT
  }

  provisioner "local-exec" {
    # Called on destroy (terraform destroy).
    when = "destroy"
    command = <<EOT
python -m amoebius.cli.secrets.ssh delete \
  --vault-role-name="${var.vault_role_name}" \
  --path="${var.path}" \
  ${var.no_verify_ssl ? "--no-verify-ssl" : ""}
EOT
  }
}