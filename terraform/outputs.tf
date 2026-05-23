output "vm_details" {
  description = "Deployed VM connection details"
  value = {
    name       = module.lab_vm.vm_name
    uuid       = module.lab_vm.vm_uuid
    ip_address = module.lab_vm.vm_ip
    state      = module.lab_vm.vm_power_state
  }
}

output "terraform_state_summary" {
  description = "Quick info about what Terraform manages"
  value = {
    datacenter = var.vsphere_datacenter
    cluster    = var.vsphere_compute_cluster
    network    = var.vsphere_network
    vm_name    = var.vm_name
  }
}
