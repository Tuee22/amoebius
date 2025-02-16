output "vm_name" {
  description = "Name from whichever submodule was created."
  value = coalesce(
    try(module.aws_single_vm[0].vm_name, null),
    try(module.azure_single_vm[0].vm_name, null),
    try(module.gcp_single_vm[0].vm_name, null),
    "No VM created"
  )
}

output "private_ip" {
  description = "Private IP from whichever submodule was created."
  value = coalesce(
    try(module.aws_single_vm[0].private_ip, null),
    try(module.azure_single_vm[0].private_ip, null),
    try(module.gcp_single_vm[0].private_ip, null),
    null
  )
}

output "public_ip" {
  description = "Public IP from whichever submodule was created."
  value = coalesce(
    try(module.aws_single_vm[0].public_ip, null),
    try(module.azure_single_vm[0].public_ip, null),
    try(module.gcp_single_vm[0].public_ip, null),
    null
  )
}
