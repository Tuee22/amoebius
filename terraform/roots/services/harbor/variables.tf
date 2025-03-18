variable "namespace" {
  type        = string
  description = "Namespace in which to deploy Harbor"
  default     = "harbor"
}

variable "kubeconfig_path" {
  type        = string
  description = "Path to the kubeconfig file (only needed if not running in-cluster)"
  default     = "~/.kube/config"
}

variable "vault_address" {
  type        = string
  description = "URL of the Vault server"
  default     = "https://vault.example.com"
}

variable "vault_token" {
  type        = string
  description = "Ephemeral Vault token for reading secrets (override or provide via env)"
  default     = ""
  sensitive   = true
}

variable "harbor_helm_repo" {
  type        = string
  description = "Helm repository URL for the official Harbor chart"
  default     = "https://helm.goharbor.io"
}

variable "harbor_helm_chart_version" {
  type        = string
  description = "Version of the Harbor Helm chart to deploy"
  default     = "1.11.3"
}

variable "harbor_release_name" {
  type        = string
  description = "Name for the Harbor helm release"
  default     = "harbor"
}

variable "external_url" {
  type        = string
  description = "Public URL at which Harbor will be accessible (e.g. https://harbor.mycompany.com)"
  default     = "https://harbor.local"
}

variable "harbor_admin_vault_path" {
  type        = string
  description = "Vault KV path for the Harbor admin password (KV v2 recommended). 
                 e.g. 'secret/data/infra/harbor/admin'"
  default     = "secret/data/infra/harbor/admin"
}

variable "harbor_admin_vault_key" {
  type        = string
  description = "Key name in the Vault KV secret for the Harbor admin password"
  default     = "password"
}

variable "use_vault_agent_injection" {
  type        = bool
  description = "Whether to rely on Vault Agent sidecar injection for credentials instead of creating K8s secrets"
  default     = false
}

variable "create_k8s_secret_for_admin" {
  type        = bool
  description = "If true, create a Kubernetes Secret for the Harbor admin password. 
                 If use_vault_agent_injection=true, you might not need this."
  default     = true
}

variable "minio_vault_path" {
  type        = string
  description = "Vault KV path for MinIO S3 credentials. e.g. 'secret/data/infra/harbor/minio'"
  default     = "secret/data/infra/harbor/minio"
}

variable "minio_vault_key_access" {
  type        = string
  description = "Key in the Vault KV secret that holds the MinIO access key"
  default     = "access_key"
}

variable "minio_vault_key_secret" {
  type        = string
  description = "Key in the Vault KV secret that holds the MinIO secret key"
  default     = "secret_key"
}

variable "create_k8s_secret_for_minio" {
  type        = bool
  description = "If true, create a Kubernetes secret for the MinIO credentials. 
                 If use_vault_agent_injection=true, you might not need this."
  default     = true
}

variable "use_s3_storage" {
  type        = bool
  description = "If true, Harbor will use S3 (MinIO) as backend for images/charts. Otherwise uses filesystem."
  default     = true
}

variable "s3_bucket" {
  type        = string
  description = "MinIO bucket name used by Harbor"
  default     = "harbour"
}

variable "s3_region" {
  type        = string
  description = "MinIO S3 region name. For MinIO, can be an arbitrary string like 'us-east-1'"
  default     = "us-east-1"
}

variable "s3_endpoint" {
  type        = string
  description = "MinIO S3 endpoint (including http/https). e.g. 'http://minio.minio-namespace:9000'"
  default     = "http://minio.minio-namespace:9000"
}

variable "s3_secure" {
  type        = bool
  description = "Set to true if S3 endpoint is HTTPS, false if HTTP"
  default     = false
}

variable "use_proxy_cache" {
  type        = bool
  description = "Toggles whether to do any references to DockerHub or other upstream. 
                 (The chart doesn't automatically configure proxy cache, but this might help in post-deploy steps.)"
  default     = false
}

variable "dockerhub_vault_path" {
  type        = string
  description = "Vault path for DockerHub credentials if you want them injected or stored. 
                 e.g. 'secret/data/infra/harbor/dockerhub'"
  default     = "secret/data/infra/harbor/dockerhub"
}
