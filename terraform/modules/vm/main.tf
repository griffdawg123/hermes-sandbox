variable "datacenter_id" {
  description = "vSphere datacenter ID"
  type        = string
}

variable "resource_pool_id" {
  description = "vSphere resource pool ID (from cluster or standalone host)"
  type        = string
}

variable "datastore_id" {
  description = "vSphere datastore ID"
  type        = string
}

variable "network_id" {
  description = "vSphere network ID"
  type        = string
}

variable "template_uuid" {
  description = "UUID of the template to clone"
  type        = string
}

variable "vm_name" {
  description = "VM display name"
  type        = string
}

variable "num_cpus" {
  description = "Number of vCPUs"
  type        = number
}

variable "memory" {
  description = "Memory in MB"
  type        = number
}

variable "disk_size" {
  description = "Root disk size in GB"
  type        = number
}

variable "ipv4_address" {
  description = "Static IPv4 (empty = DHCP)"
  type        = string
  default     = ""
}

variable "ipv4_netmask" {
  description = "CIDR netmask"
  type        = number
  default     = 24
}

variable "ipv4_gateway" {
  description = "IPv4 gateway"
  type        = string
  default     = ""
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

# ── VM Resource ──────────────────────────────────────────────────────
resource "vsphere_virtual_machine" "this" {
  name             = var.vm_name
  resource_pool_id = var.resource_pool_id
  datastore_id     = var.datastore_id
  num_cpus         = var.num_cpus
  memory           = var.memory
  firmware         = "efi"

  wait_for_guest_ip_timeout = 5

  network_interface {
    network_id   = var.network_id
    adapter_type = "vmxnet3"
  }

  disk {
    label            = "disk0"
    size             = var.disk_size
    thin_provisioned = true

    # Inherit from the template
    eagerly_scrub    = false
  }

  clone {
    template_uuid = var.template_uuid

    # Optional Linux customization (customize for Windows differently)
    dynamic "customize" {
      for_each = var.ipv4_address != "" ? [1] : []
      content {
        linux_options {
          host_name = split(".", var.vm_name)[0]
          domain    = "local"
        }

        network_interface {
          ipv4_address = var.ipv4_address
          ipv4_netmask = var.ipv4_netmask
        }

        ipv4_gateway    = var.ipv4_gateway
        dns_server_list = var.dns_servers
      }
    }
  }

  # Use data source for cluster info
  depends_on = []
}

# Cluster and template lookups are done at the root level and
# passed in as IDs. No additional data sources needed here.

# ── Outputs ───────────────────────────────────────────────────────────
output "vm_name" {
  value = vsphere_virtual_machine.this.name
}

output "vm_uuid" {
  value = vsphere_virtual_machine.this.id
}

output "vm_ip" {
  value = try(
    vsphere_virtual_machine.this.default_ip_address,
    "pending (guest tools not reporting yet)"
  )
}

output "vm_power_state" {
  value = vsphere_virtual_machine.this.power_state
}
