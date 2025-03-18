##############################
# 1. Retrieve secrets from Vault
##############################
data "vault_generic_secret" "harbor_admin" {
  path = var.harbor_admin_vault_path
}

data "vault_generic_secret" "harbor_minio" {
  path = var.minio_vault_path
}

# (Optional) If using DockerHub credentials for a future proxy cache config:
data "vault_generic_secret" "dockerhub" {
  path = var.dockerhub_vault_path
}

##############################
# 2. Create optional K8s Secrets
##############################

# Harbor admin password
resource "kubernetes_secret" "harbor_admin_pwd" {
  count = var.create_k8s_secret_for_admin && !var.use_vault_agent_injection ? 1 : 0

  metadata {
    name      = "harbor-admin-secret"
    namespace = var.namespace
  }

  data = {
    # Harbor chart expects the key to be 'HARBOR_ADMIN_PASSWORD' by default
    HARBOR_ADMIN_PASSWORD = base64encode(
      data.vault_generic_secret.harbor_admin.data[var.harbor_admin_vault_key]
    )
  }

  type = "Opaque"
}

# MinIO / S3 credentials
resource "kubernetes_secret" "harbor_s3_creds" {
  count = var.create_k8s_secret_for_minio && !var.use_vault_agent_injection && var.use_s3_storage ? 1 : 0

  metadata {
    name      = "harbor-minio-secret"
    namespace = var.namespace
  }

  data = {
    REGISTRY_STORAGE_S3_ACCESSKEY = base64encode(
      data.vault_generic_secret.harbor_minio.data[var.minio_vault_key_access]
    )
    REGISTRY_STORAGE_S3_SECRETKEY = base64encode(
      data.vault_generic_secret.harbor_minio.data[var.minio_vault_key_secret]
    )
  }

  type = "Opaque"
}

##############################
# 3. Render Helm values
##############################

locals {
  # Decide the "existingSecret" name for admin password if we are using K8s secrets
  admin_secret_name = var.create_k8s_secret_for_admin && !var.use_vault_agent_injection
    ? kubernetes_secret.harbor_admin_pwd[0].metadata[0].name
    : ""

  # Decide the "existingSecret" name for MinIO if we are using K8s secrets
  s3_secret_name = var.create_k8s_secret_for_minio && !var.use_vault_agent_injection && var.use_s3_storage
    ? kubernetes_secret.harbor_s3_creds[0].metadata[0].name
    : ""
}

data "template_file" "harbor_values" {
  template = file("${path.module}/templates/values.yaml.tpl")
  vars = {
    external_url         = var.external_url
    admin_secret_name    = local.admin_secret_name
    use_s3_storage       = var.use_s3_storage
    s3_bucket            = var.s3_bucket
    s3_region            = var.s3_region
    s3_endpoint          = var.s3_endpoint
    s3_secure            = var.s3_secure
    s3_secret_name       = local.s3_secret_name
    vault_injection      = var.use_vault_agent_injection
    vault_minio_path     = var.minio_vault_path
    vault_dockerhub_path = var.dockerhub_vault_path
  }
}

##############################
# 4. Deploy Harbor with Helm
##############################
resource "helm_release" "harbor" {
  name       = var.harbor_release_name
  namespace  = var.namespace
  repository = var.harbor_helm_repo
  chart      = "harbor"
  version    = var.harbor_helm_chart_version

  create_namespace = true

  values = [
    data.template_file.harbor_values.rendered
  ]

  # Ensure secrets (if we are creating them) are created before the Helm install
  depends_on = [
    kubernetes_secret.harbor_admin_pwd,
    kubernetes_secret.harbor_s3_creds
  ]
}
