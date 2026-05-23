variable "datacenter_id" {
  description = "vSphere datacenter ID"
  type        = string
}

variable "vsphere_network_name" {
  description = "Name of the portgroup (as shown in vSphere)"
  type        = string
}

variable "vlan_id" {
  description = "VLAN ID for new network (0 = default/untagged)"
  type        = number
  default     = 0
}

# This resource creates a new distributed portgroup.
# Most homelabs use an existing standard portgroup instead.
# Uncomment when you need custom networks.
#
# resource "vsphere_distributed_port_group" "this" {
#   name                            = var.vsphere_network_name
#   distributed_virtual_switch_uuid = var.dvs_id
#   number_of_ports                 = var.num_ports
#   vlan_id                         = var.vlan_id
# }

# Lookup existing network
data "vsphere_network" "this" {
  name          = var.vsphere_network_name
  datacenter_id = var.datacenter_id
}

output "network_id" {
  description = "ID of the network (portgroup)"
  value       = data.vsphere_network.this.id
}

output "network_name" {
  value = data.vsphere_network.this.name
}
