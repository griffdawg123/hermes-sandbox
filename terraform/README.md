# Homelab Terraform — vSphere VM Provisioning

Terraform configurations for provisioning VMs on VMware vSphere (vCenter or standalone ESXi).
Designed for homelab/IaC learning.

## Structure

```
terraform/
├── main.tf              # Provider config, data sources, module calls
├── variables.tf         # All variables with descriptions and defaults
├── outputs.tf           # What terraform apply prints on completion
├── terraform.tfvars.example  # Template for your secrets (copy to .tfvars)
├── .gitignore           # Ignores state, .terraform/, credentials
├── modules/
│   ├── vm/              # Single VM from template (clone, customize)
│   └── network/         # Network/portgroup lookup and creation
└── examples/            # Real-world usage patterns (coming next)
```

## Quick Start

### 1. Install Terraform

```bash
# Arch Linux
sudo pacman -S terraform

# Or download from https://developer.hashicorp.com/terraform/downloads
```

### 2. Configure Your vSphere Connection

Copy the example and fill in your values:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your vCenter/ESXi details
```

**NEVER commit `terraform.tfvars`** — it's in `.gitignore`.

### 3. Initialize and Validate

```bash
terraform init       # Download the vSphere provider plugin
terraform validate   # Check syntax (works without a vSphere connection)
```

### 4. Plan and Apply

```bash
terraform plan       # Dry run — shows what will be created
terraform apply      # Actually create the VM
terraform destroy    # Tear it all down
```

### 5. Add or Customize VMs

Edit the `module "lab_vm"` block in `main.tf` to change resources,
or add additional module blocks for more VMs:

```hcl
module "web_server" {
  source   = "./modules/vm"
  vm_name  = "web-01"
  num_cpus = 4
  memory   = 8192
  # ... (same variables)
}
```

## Preparing a Clone Source (Standalone ESXi)

Standalone ESXi (no vCenter) does **not** support VM templates — that feature requires vCenter Server. Instead, Terraform clones from a powered-off VM directly.

### Create the base VM

1. Create an Ubuntu VM inside ESXi via the UI
2. Install Ubuntu (enable OpenSSH server during install)
3. After install, run:
   ```bash
   sudo apt update
   sudo apt install -y open-vm-tools cloud-init
   sudo apt clean
   ```
4. **Shut it down** (do not delete or snapshot it):
   ```bash
   sudo shutdown -h now
   ```
5. Note the exact VM name (e.g., `ubuntu-22.04-base`)
6. In your `terraform.tfvars.local`, set:
   ```hcl
   vm_template_name = "ubuntu-22.04-base"
   ```

Terraform's `vsphere_virtual_machine` clone block works identically from a powered-off VM as from a vCenter template. The only difference is you must remember not to power the base VM back on manually — only let Terraform manage it by cloning from it.

## Next Phases

| Phase | What | Skill |
|-------|------|-------|
| 1 (current) | Single VM from template | Terraform basics |
| 2 | Multi-VM lab (web + DB + jump box) | Modules, loops, variables |
| 3 | Packer template for golden images | Image building, cloud-init |
| 4 | VMware ARIA JS API orchestration | Node.js, vSphere API |
| 5 | PowerShell guest configuration | PowerShell DSC, WinRM |
| 6 | Dashboard / status tracking | Frontend, state reading |

## vSphere Provider Reference

Official docs: https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs

## Key Concepts

| Concept | Why it matters |
|---------|---------------|
| **State** | Terraform tracks what it manages in `terraform.tfstate`. Don't edit manually. |
| **Data sources** | Read existing vCenter objects without creating them. How we find your real datastore, cluster, templates. |
| **Modules** | Reusable blocks. The `vm` module can be called multiple times for different VMs. |
| **Variables + tfvars** | Separate config from code. Variables have defaults, tfvars overrides them. |
| **Plan** | Always run `terraform plan` before `apply`. Shows exactly what changes will happen. |
