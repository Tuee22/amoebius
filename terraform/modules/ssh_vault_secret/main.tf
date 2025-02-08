######################################
# main.tf for ssh_vault_secret module
######################################

locals {
  # Place non-secret variables in triggers so we can reference them safely
  # during creation and destruction (in the same resource).
  # If you have additional variables, include them here, but do NOT store
  # the entire private_key in triggers. Only store the ephemeral private_key
  # in the local-exec command.
  triggers = {
    vault_role_name = var.vault_role_name
    path            = var.path
    user            = var.user
    hostname        = var.hostname
    port            = tostring(var.port)
    # Convert bool to string for easy conditional usage
    no_verify_ssl   = var.no_verify_ssl ? "true" : "false"
  }
}

resource "null_resource" "vault_ssh_secret" {
  # Use triggers so the resource updates if these values change
  triggers = local.triggers

  # --------------------------------------------------------------------------
  # 1) CREATE/UPDATE: "store" the SSH private key in Vault
  # --------------------------------------------------------------------------
  provisioner "local-exec" {
    # runs on create/update
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

  # --------------------------------------------------------------------------
  # 2) DESTROY: "delete" the SSH private key from Vault
  # --------------------------------------------------------------------------
  # Use `when    = destroy` (unquoted) to avoid the Terraform
  # “Quoted keywords are deprecated” warning.
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