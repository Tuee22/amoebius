###############################################
# /amoebius/terraform/modules/compute/outputs.tf
###############################################

# We'll coalesce from whichever single_vm submodule has count=1

output "vm_name" {
  description = "VM name from whichever provider submodule was created."
  value = coalesce(
    try(module.aws_single_vm[0].vm_name, null),
    try(module.azure_single_vm[0].vm_name, null),
    try(module.gcp_single_vm[0].vm_name, null),
    "No single VM module was created."
  )
}

output "private_ip" {
  description = "VM private IP from whichever submodule was used."
  value = coalesce(
    try(module.aws_single_vm[0].private_ip, null),
    try(module.azure_single_vm[0].private_ip, null),
    try(module.gcp_single_vm[0].private_ip, null),
    null
  )
}

output "public_ip" {
  description = "VM public IP from whichever submodule was used."
  value = coalesce(
    try(module.aws_single_vm[0].public_ip, null),
    try(module.azure_single_vm[0].public_ip, null),
    try(module.gcp_single_vm[0].public_ip, null),
    null
  )
}
