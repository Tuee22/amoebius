variable "serviceaccounts" {
  type = list(object({
    name               = string
    namespace          = string
    image_pull_secrets = list(string)
  }))
  description = <<EOT
List of service accounts to patch or create, each having:
- name
- namespace
- image_pull_secrets (list of secret names)
EOT
}

variable "patch_type" {
  type        = string
  description = "Kubernetes patch type (e.g. strategic, merge, json). Usually 'strategic'."
  default     = "strategic"
}

variable "field_manager" {
  type        = string
  description = "Kubernetes server-side apply field manager identifier."
  default     = "terraform"
}

variable "ignore_changes" {
  type        = list(string)
  description = "Fields to ignore changes on, e.g. ['automountServiceAccountToken']."
  default     = []
}

# variable "force_conflicts" {
#   type        = bool
#   description = "Whether to overwrite conflicts when patching"
#   default     = false
# }