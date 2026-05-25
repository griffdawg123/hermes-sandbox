terraform {
  required_version = ">= 1.5.0"

  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = "~> 2.9"
    }
  }

  # Local state for learning. Replace with remote backend when ready.
  backend "local" {
    path = "./state/terraform.tfstate"
  }
}

# ── VMware vSphere Provider ──────────────────────────────────────────
# Credentials should be set via environment variables or a .tfvars file:
#   TF_VAR_vsphere_server      = "vcenter.example.com"
#   TF_VAR_vsphere_user        = "administrator@vsphere.local"
#   TF_VAR_vsphere_password    = "your-password"
# OR via terraform.tfvars.local (not committed):
#   vsphere_server     = "..."
#   vsphere_user       = "..."
#   vsphere_password   = "..."

# Allow unverified/self-signed certificates (common in homelabs)
provider "vsphere" {
  vsphere_server       = var.vsphere_server
  user                 = var.vsphere_user
  password             = var.vsphere_password
  allow_unverified_ssl = var.vsphere_allow_unverified_ssl
}

# ── Data Sources (lookup existing infrastructure objects) ────────────
# These find your real vCenter/ESXi resources by name so Terraform knows
# where to deploy.

data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter
}

# ── Standalone ESXi vs vCenter Cluster ───────────────────────────────
# For standalone ESXi (no vCenter), we use the host's default resource pool.
# For vCenter with a cluster, we use the cluster's resource pool.
# Set vsphere_compute_cluster to "" when using standalone ESXi.

data "vsphere_host" "standalone" {
  count         = var.vsphere_compute_cluster == "" ? 1 : 0
  name          = var.vsphere_server
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_compute_cluster" "cluster" {
  count         = var.vsphere_compute_cluster != "" ? 1 : 0
  name          = var.vsphere_compute_cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Resolve the resource pool depending on standalone vs cluster mode
locals {
  resource_pool_id = var.vsphere_compute_cluster == "" ? data.vsphere_host.standalone[0].resource_pool_id : data.vsphere_compute_cluster.cluster[0].resource_pool_id
}

data "vsphere_datastore" "datastore" {
  name          = var.vsphere_datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.vsphere_network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.vm_template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

# ── Module: Single VM ────────────────────────────────────────────────
module "lab_vm" {
  source = "./modules/vm"

  # Resource targeting
  datacenter_id  = data.vsphere_datacenter.dc.id
  resource_pool_id = local.resource_pool_id
  datastore_id   = data.vsphere_datastore.datastore.id
  network_id     = data.vsphere_network.network.id
  template_uuid  = data.vsphere_virtual_machine.template.id

  # VM specifics (passed from examples or root)
  vm_name     = var.vm_name
  num_cpus    = var.vm_num_cpus
  memory      = var.vm_memory
  disk_size   = var.vm_disk_size

  # Networking (optional)
  ipv4_address = var.vm_ipv4_address
  ipv4_netmask = var.vm_ipv4_netmask
  ipv4_gateway = var.vm_ipv4_gateway
  dns_servers  = var.vm_dns_servers
}

