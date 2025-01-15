variable "host" {
  type        = string
  default     = ""
  description = "Kubernetes API server endpoint."
}

variable "cluster_ca_certificate" {
  type        = string
  default     = ""
  description = "Base64-encoded CA certificate for the Kubernetes cluster."
}

variable "client_certificate" {
  type        = string
  default     = ""
  description = "Base64-encoded client certificate for Kubernetes authentication."
}

variable "client_key" {
  type        = string
  default     = ""
  description = "Base64-encoded client key for Kubernetes authentication."
}

variable "create_namespace" {
  type        = bool
  default     = true
  description = "Whether to create the namespace."
}

variable "namespace_name" {
  type        = string
  description = "Name of the namespace to create or apply policies to."
}

variable "linkerd_inject" {
  type        = bool
  default     = false
  description = "Whether to annotate the namespace for automatic Linkerd proxy injection."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Additional labels to attach to the namespace."
}

variable "apply_linkerd_policy" {
  type        = bool
  default     = false
  description = "Whether to create Server and ServerAuthorization resources to enforce mTLS-only traffic."
}

variable "server_name" {
  type        = string
  default     = "all-ports"
  description = "Name for the Linkerd Server resource."
}

variable "server_port_range" {
  type        = string
  default     = "1-65535"
  description = "All ports for the Linkerd Server resource."
}

variable "proxy_protocol" {
  type        = string
  default     = "opaque"
  description = "Proxy protocol, for example 'opaque', 'HTTP/1.x', 'HTTP/2'."
}
