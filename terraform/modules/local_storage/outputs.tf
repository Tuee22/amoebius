# Overwrites the local_storage outputs so the module exports storage_class_name

output "storage_class_name" {
  description = "The name of the StorageClass created by local_storage module"
  value       = kubernetes_storage_class.this.metadata[0].name
}
