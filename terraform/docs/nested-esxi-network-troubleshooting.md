# Nested ESXi Network Troubleshooting
## Ubuntu Server VM on ESXi on VMware Workstation (WiFi Host)

**Environment:**
- Host OS: Arch Linux (WiFi — wlan0)
- Hypervisor: VMware Workstation (NAT via vmnet8)
- Nested Hypervisor: VMware ESXi 8.0
- Guest VM: Ubuntu Server
- Guest NIC: VMXNET3

---

## Problem 1 — VMXNET3 Autoconfiguration Failing

### Problem
On first boot, Ubuntu Server failed to configure the VMXNET3 ethernet controller automatically. No IPv4 address was assigned.

### Diagnosis
- `ip a` showed the interface (e.g. `ens34`) present but with no IPv4 address
- Running `sudo netplan apply` produced:
  ```
  WARNING:root:Cannot call Open vSwitch: ovsdb-server.service is not running.
  ```

### Troubleshooting Steps
1. Confirmed the VMXNET3 module was loaded: `lsmod | grep vmxnet3`
2. Confirmed interface name via `ip a` — Ubuntu uses predictable names (`ens34`), not `eth0`
3. Verified netplan config matched the actual interface name in `/etc/netplan/*.yaml`
4. Investigated the OVS warning

### Recovery
- The OVS warning was **benign** — netplan always probes for Open vSwitch even when unused. Safely ignored.
- Corrected the interface name in the netplan YAML to match `ens34`
- Applied with `sudo netplan apply`

### Outcome
Interface recognised. Netplan applied without errors. However, no IPv4 was assigned — DHCP discovery was failing.

---

## Problem 2 — DHCP Broadcasts Not Reaching the DHCP Server

### Problem
Running `sudo dhclient -v ens34` sent DHCP Discover broadcasts but received no DHCP Offer. 100% packet loss to the gateway.

### Diagnosis
- `dhclient -v` confirmed broadcasts were leaving the VM
- No DHCP Offer returned — packets were not reaching the DHCP server
- Root cause: **ESXi vSwitch and Port Group security settings** were blocking Layer 2 traffic from nested VMs

### Troubleshooting Steps
1. Confirmed the interface was up and broadcasting
2. Identified ESXi vSwitch security settings as blocking traffic for VMs with different MACs
3. Identified that VMware Workstation network mode (NAT/Bridged) also affected traffic flow

### Recovery
In ESXi Host Client:
```
Networking → Virtual Switches → vSwitch0 → Edit → Security
Networking → Port Groups → [VM Port Group] → Edit → Security
```
Set **all three** to **Accept** on both vSwitch and Port Group:

| Setting            | Value  |
|--------------------|--------|
| Promiscuous Mode   | Accept |
| MAC Address Changes| Accept |
| Forged Transmits   | Accept |

> ⚠️ Port Group settings **override** vSwitch settings — both must be configured.

Changed VMware Workstation network mode for the ESXi VM from **NAT → Bridged**.

### Outcome
DHCP Offer received. Ubuntu VM assigned `192.168.1.112/24` from the home router. IPv4 connectivity established at Layer 3.

---

## Problem 3 — Gateway Unreachable / ARP Dying (Bridged Mode)

### Problem
VM had an IP (`192.168.1.112`) but ping to the gateway (`192.168.1.1`) resulted in 100% packet loss. Curl to external hosts returned `No route to host`, then `Connection timed out`.

### Diagnosis
- `ip neigh show` showed the gateway ARP entry as **STALE** — learned once but not refreshing
- `sudo tcpdump -i ens34 arp` confirmed ARP requests left the VM and **replies came back** — Layer 2 was working intermittently
- When ARP entry expired to FAILED, all outbound traffic died — `EHOSTUNREACH`
- Root cause: **WiFi does not support bridged promiscuous mode for nested VMs**

**The core issue with WiFi + Bridged + Nested ESXi:**
```
Bridged (wired):  Ubuntu VM → ESXi vSwitch → Physical switch → Router   ✅
                  All MACs visible to physical switch

Bridged (WiFi):   Ubuntu VM → ESXi vSwitch → WiFi AP → Router           ❌
                  WiFi AP only knows host's MAC (wlan0)
                  Return traffic for MAC_ubuntu arrives at host but
                  Workstation's bridge cannot identify which nested VM
                  it belongs to → silently dropped
```

### Troubleshooting Steps
1. Confirmed ARP via `tcpdump` — saw requests and replies
2. Pinned a static ARP entry: `sudo ip neigh replace 192.168.1.1 lladdr <mac> dev ens34 nud permanent`
3. Confirmed packets leaving via `tcpdump -i ens34 icmp` — only SYN out, no SYN-ACK back
4. Disabled VMXNET3 checksum offloading: `sudo ethtool -K ens34 tx off rx off tso off gso off gro off lro off` — no effect
5. Ran `tcpdump` on host physical NIC (`wlan0`) — confirmed SYN packets reaching physical network
6. Confirmed SYN-ACK arriving at host from router but **never delivered to the ESXi VM**
7. Identified `/etc/vmware/networking` — only vmnet1 (host-only) and vmnet8 (NAT), no vmnet0 config
8. Root cause confirmed: WiFi cannot support bridged mode for nested VMs

### Recovery
Switched VMware Workstation network mode for ESXi VM from **Bridged → NAT (vmnet8)**.

### Outcome
Bridged mode abandoned as architecturally incompatible with WiFi for nested virtualisation.

---

## Problem 4 — NAT Mode Not Delivering Traffic to Nested VM

### Problem
After switching to NAT, ESXi management interface received `192.168.101.x` from Workstation's vmnet8 DHCP, but the Ubuntu VM received no IP and could not ping `192.168.101.1` (the host's vmnet8 interface).

### Diagnosis
Static IP (`192.168.101.50`) assigned manually to the Ubuntu VM. Ping to `192.168.101.1` returned:
```
Destination Host Unreachable
```
This indicated **ARP was failing** — the host's vmnet8 interface was not responding to ARP requests from `MAC_ubuntu`.

**Why:** In VMware Workstation's NAT virtual switch (vmnet8), each connected VM port only receives frames addressed to **its own registered MAC**. ESXi's vmnic0 MAC (`MAC_esxi`) is registered. The Ubuntu VM's MAC (`MAC_ubuntu`) is not — it is a nested VM invisible to Workstation's vmnet layer. Return traffic for `MAC_ubuntu` was silently dropped.

```
Ubuntu VM (MAC_ubuntu) → ESXi vSwitch → vmnic0 (MAC_esxi) → vmnet8
                                                                    ↓
                                               Host responds to MAC_esxi only
                                               MAC_ubuntu frames dropped ❌
```

ESXi needs permission to put `vmnic0` into **promiscuous mode** so that vmnet8 delivers ALL frames to the ESXi VM, including those addressed to `MAC_ubuntu`.

### Troubleshooting Steps
1. Confirmed vmnet8 had correct IP (`192.168.101.1`) on host: `ip addr show vmnet8`
2. Confirmed ESXi management working on `192.168.101.x` — proving vmnic0 → vmnet8 path is live
3. Confirmed single vmnic (`vmnic0`) in ESXi — no adapter mismatch
4. Ran `sudo tcpdump -i vmnet8 arp` on host — confirmed ARP requests from Ubuntu VM not arriving at vmnet8
5. Root cause identified: vmnet8 not delivering frames for `MAC_ubuntu` to ESXi VM

### Recovery

**Step 1 — Allow ESXi VM to use promiscuous mode on vmnet8:**

Edit the ESXi VM's `.vmx` file (shut ESXi down first):
```ini
ethernet0.noPromisc = "FALSE"
```

**Step 2 — Grant vmnet8 device permission for promiscuous mode:**

On the Linux host:
```bash
sudo chmod a+rw /dev/vmnet8
```

**Step 3 — Make the permission persistent (survives reboots):**

Create `/etc/systemd/system/vmnet8-promisc.service`:
```ini
[Unit]
Description=Fix vmnet8 permissions for nested VMs
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/chmod a+rw /dev/vmnet8
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```
```bash
sudo systemctl enable --now vmnet8-promisc.service
```

**Step 4 — Verify ESXi Port Group security still set to Accept** (Promiscuous Mode, MAC Address Changes, Forged Transmits).

### Outcome
With `ethernet0.noPromisc = "FALSE"` + vmnet8 permissions set, ESXi put vmnic0 into promiscuous mode. vmnet8 began delivering all frames to the ESXi VM regardless of destination MAC. Ubuntu VM successfully received DHCP lease and ping to `8.8.8.8` succeeded.

---

## Problem 5 — Ubuntu VM Loses Network Connectivity After Reboot

### Problem
After a clean reboot of the Ubuntu VM, `ens34` had no IP address and there was no network connectivity. Running `sudo dhclient ens34` manually restored the connection, confirming the interface and DHCP path were fine — but the configuration wasn't persisting across reboots.

### Diagnosis
- `ip addr show ens34` — interface present, no IPv4 address
- `sudo dhclient ens34` — immediately obtained a lease → DHCP itself was working
- No files in `/etc/netplan/` — Netplan was not configured
- `systemctl status NetworkManager` — unit not found
- `systemctl status systemd-networkd` — **active (running)**
- `/etc/network/interfaces` — did not exist
- Root cause: Ubuntu was using **systemd-networkd** as the network manager, but no `.network` file existed for `ens34` in `/etc/systemd/network/`. systemd-networkd only manages interfaces it has an explicit config file for — `ens34` was silently ignored on boot.

### Recovery
Create a `.network` file for the interface:

```bash
sudo nano /etc/systemd/network/10-ens34.network
```

```ini
[Match]
Name=ens34

[Network]
DHCP=yes
```

```bash
sudo systemctl restart systemd-networkd
```

### Outcome
`ens34` obtained a DHCP lease immediately and came up automatically on all subsequent reboots.

---

## Final Working Configuration

| Layer | Setting | Value |
|---|---|---|
| VMware Workstation | ESXi VM network mode | NAT (vmnet8) |
| VMware Workstation | ESXi VM `.vmx` flag | `ethernet0.noPromisc = "FALSE"` |
| Linux Host | `/dev/vmnet8` permissions | `a+rw` (via systemd service) |
| ESXi vSwitch0 | Promiscuous Mode | Accept |
| ESXi vSwitch0 | MAC Address Changes | Accept |
| ESXi vSwitch0 | Forged Transmits | Accept |
| ESXi Port Group | Promiscuous Mode | Accept |
| ESXi Port Group | MAC Address Changes | Accept |
| ESXi Port Group | Forged Transmits | Accept |
| Ubuntu VM | Network | DHCP via vmnet8 (192.168.101.x) |

---

## Key Lessons

### 1. WiFi Cannot Support Bridged Mode for Nested VMs
WiFi access points only communicate with the registered MAC of the connected device. When ESXi is on a WiFi-connected host and VMs run inside ESXi, return traffic addressed to the nested VMs' MACs arrives at the host but cannot be forwarded — the WiFi AP has no record of those MACs. **Always use NAT or a wired connection for nested ESXi labs on a laptop.**

### 2. Two Layers of vSwitch Security Settings
ESXi has security settings at **both** the vSwitch level and the Port Group level. Port Group settings override vSwitch settings. Always verify **both** layers are set to Accept for nested virtualisation.

### 3. Promiscuous Mode is Needed at Every Hypervisor Layer
Each hypervisor in the stack only delivers traffic for MACs it knows about. For nested VMs to receive traffic, every hypervisor layer must be configured to pass traffic for unknown MACs:
- ESXi vSwitch/Port Group → Promiscuous Mode: Accept
- VMware Workstation vmnet → `ethernet0.noPromisc = "FALSE"` + `chmod a+rw /dev/vmnetX`

### 4. ARP is the Diagnostic Canary
- ARP working but TCP failing → checksum offloading or MTU issue
- ARP intermittently working (STALE entries) → promiscuous mode not fully configured
- ARP never resolving → Layer 2 policy blocking traffic entirely

### 6. systemd-networkd Ignores Unconfigured Interfaces
If Ubuntu is using `systemd-networkd` (no NetworkManager, no Netplan), it will **only** bring up interfaces that have a corresponding file in `/etc/systemd/network/`. An interface can be fully functional but will silently receive no DHCP lease on boot if that file is missing. Check with `systemctl status systemd-networkd` and create `/etc/systemd/network/10-<iface>.network` with `DHCP=yes` under `[Network]`.

### 5. Diagnosis Order
```
Is the interface up?          → ip link show
Does DHCP work?               → dhclient -v (watch for DHCPOFFER)
Can we reach the gateway?     → ping gateway
Does ARP resolve?             → ip neigh show / tcpdump arp
Is it one-directional?        → tcpdump icmp or tcp (SYN vs SYN-ACK)
Where does it break?          → tcpdump on host NIC, then vmnet, then VM
```
