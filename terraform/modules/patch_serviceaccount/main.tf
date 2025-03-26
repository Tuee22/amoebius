/*
  A reusable module to patch an existing ServiceAccount (or create if missing)
  with multiple imagePullSecrets.

  By default, it uses "strategic" patch_type.
*/
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.11"
    }
  }
}

resource "kubernetes_manifest" "patch_sa" {
  for_each = {
    for sa in var.serviceaccounts : "${sa.namespace}/${sa.name}" => sa
  }

  // Build the manifest from each item in var.serviceaccounts
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "ServiceAccount"
    "metadata" = {
      "name"      = each.value.name
      "namespace" = each.value.namespace
      // optionally additional metadata if needed
    }
    "imagePullSecrets" = [
      for secret in each.value.image_pull_secrets : {
        "name" = secret
      }
    ]
  }

  patch_type    = var.patch_type
  field_manager = var.field_manager
  # force_conflicts = var.force_conflicts

  lifecycle {
    ignore_changes = var.ignore_changes
  }
}