# ═══════════════════════════════════════════════════════════════════
# vSphere connection variables
# ═══════════════════════════════════════════════════════════════════

variable "vsphere_server" {
  description = "vCenter Server or ESXi host FQDN/IP"
  type        = string
  sensitive   = true
}

variable "vsphere_user" {
  description = "vSphere username (e.g. administrator@vsphere.local)"
  type        = string
  sensitive   = true
}

variable "vsphere_password" {
  description = "vSphere password"
  type        = string
  sensitive   = true
}

variable "vsphere_allow_unverified_ssl" {
  description = "Allow self-signed SSL certificates (typical for homelabs)"
  type        = bool
  default     = true
}

# ═══════════════════════════════════════════════════════════════════
# Infrastructure target variables
# ═══════════════════════════════════════════════════════════════════

variable "vsphere_datacenter" {
  description = "vSphere datacenter name"
  type        = string
  default     = "Datacenter"
}

variable "vsphere_compute_cluster" {
  description = "vCenter cluster name. Leave empty (\"\") for standalone ESXi."
  type        = string
  default     = ""
}

variable "vsphere_datastore" {
  description = "Target datastore name"
  type        = string
  default     = "datastore1"
}

variable "vsphere_network" {
  description = "Target portgroup or distributed switch portgroup name"
  type        = string
  default     = "VM Network"
}

variable "vm_template_name" {
  description = "Name of the VM template to clone from"
  type        = string
  default     = "ubuntu-22.04-template"
}

# ═══════════════════════════════════════════════════════════════════
# VM resource variables
# ═══════════════════════════════════════════════════════════════════

variable "vm_name" {
  description = "Name for the new virtual machine"
  type        = string
  default     = "lab-vm-01"
}

variable "vm_num_cpus" {
  description = "Number of vCPUs"
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "Memory in MB"
  type        = number
  default     = 4096
}

variable "vm_disk_size" {
  description = "Root disk size in GB"
  type        = number
  default     = 40
}

# ═══════════════════════════════════════════════════════════════════
# Networking (optional — leave empty for DHCP)
# ═══════════════════════════════════════════════════════════════════

variable "vm_ipv4_address" {
  description = "Static IPv4 address (empty for DHCP)"
  type        = string
  default     = ""
}

variable "vm_ipv4_netmask" {
  description = "CIDR netmask (e.g. 24)"
  type        = number
  default     = 24
}

variable "vm_ipv4_gateway" {
  description = "IPv4 gateway address"
  type        = string
  default     = ""
}

variable "vm_dns_servers" {
  description = "DNS server addresses"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}
