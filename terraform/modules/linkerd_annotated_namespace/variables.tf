variable "create_namespace" {
  type    = bool
  default = true
  description = "Whether to create the namespace."
}

variable "namespace_name" {
  type        = string
  description = "Name of the namespace to create or to apply policies to."
}

variable "linkerd_inject" {
  type    = bool
  default = true
  description = "Whether to annotate the namespace for automatic Linkerd proxy injection."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Additional labels to attach to the namespace."
}

variable "apply_linkerd_policy" {
  type    = bool
  default = true
  description = "Whether to create Server + ServerAuthorization to enforce mTLS-only traffic."
}

variable "server_name" {
  type        = string
  default     = "all-ports"
  description = "Name for the Linkerd Server resource."
}

variable "server_port" {
  type        = number
  default     = 0
  description = "Port for the Linkerd Server resource. 0 = match all ports."
}

variable "proxy_protocol" {
  type        = string
  default     = "opaque"
  description = "Proxy protocol (e.g., 'opaque', 'HTTP/1.x', 'HTTP/2')."
}
