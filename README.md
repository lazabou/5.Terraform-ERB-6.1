# Terraform Apstra — ERB 6.1

Automated provisioning of a Juniper datacenter fabric via [Juniper Apstra](https://www.juniper.net/us/en/products/network-automation/apstra.html) and Terraform.

## Deployed Topology

```
                    ┌─────────┐   ┌─────────┐
                    │ Spine 1 │   │ Spine 2 │   (QFX5200)
                    └────┬────┘   └────┬────┘
              ┌──────────┴──┬──────────┴──────────┐
        ┌─────┴──────┐      │               ┌──────┴─────┐
        │ Border L1  │  Border L2           │ Compute L1 │  Compute L2
        │ QFX10002   │  QFX10002            │ QFX5120    │  QFX5120
        └─────┬──────┘                      └──────┬─────┘
              │  LAG (LACP)                        │  LAG (LACP)
           ┌──┴──┐                          ┌──────┴──────┐
           │ FW  │                          │  Server14   │  Server10
           └─────┘                          └─────────────┘
```

| Role          | Model        | Count |
|---------------|--------------|-------|
| Spine         | QFX5200      | 2     |
| Border Leaf   | QFX10002-36Q | 2     |
| Compute Leaf  | QFX5120-48Y  | 2     |

**Overlay**: EVPN / VXLAN — managed by Apstra

## Prerequisites

- Terraform ≥ 1.0
- Network access to the Apstra instance
- Apstra ≥ 5.0 (provider `Juniper/apstra` v0.98.0)

## Quick Start

### 1. Initialize

```bash
terraform init
```

### 2. Apstra Credentials

Create a `terraform.secrets.tfvars` file (excluded from git):

```hcl
apstra_url = "https://<user>:<password>@<apstra-ip>"
```

### 3. Plan and Deploy

```bash
terraform plan    -var-file="terraform.secrets.tfvars"
terraform apply   -var-file="terraform.secrets.tfvars"
```

### 4. Destroy

```bash
terraform destroy -var-file="terraform.secrets.tfvars"
```

## File Structure

| File | Purpose |
|------|---------|
| `apstra.tf` | Apstra provider configuration |
| `resources.tf` | Resource pools (ASN, IPv4 loopback/link, VNI) |
| `logical-device-interface-maps.tf` | Logical devices and interface maps (leaf / border / spine) |
| `racks.tf` | Rack types (compute and border) |
| `template.tf` | Rack-based blueprint template |
| `blueprint.tf` | Blueprint, device allocation, and deployment |
| `erb_vrf.tf` | VRFs (Routing Zones) and default route Connectivity Templates |
| `erb_vn.tf` | Virtual Networks (VXLANs) and tagged Connectivity Templates |
| `generic-systems.tf` | Generic systems (servers, firewall) with LACP LAG |
| `terraform.tfvars` | Service definitions: VRFs, VNs, generic systems |

## Service Configuration

All services are defined in `terraform.tfvars` — no changes to `.tf` files are needed to add VRFs, VNs, or generic systems.

### VRFs

Each VRF (Routing Zone) has a **default route configured on the border leafs pointing to the firewall**. This ensures that all inter-VRF or north-south traffic is forwarded to the firewall for inspection before leaving the fabric.

```hcl
vrfs = [
  {
    name                   = "Blue_VRF"
    default_route_next_hop = "10.0.10.254"    # Firewall IP in this VRF
    default_route_leaf     = ["terraform_border_001_leaf1", "terraform_border_001_leaf2"]
  },
]
```

Apstra automatically generates a System Connectivity Template per VRF that injects this static default route (`0.0.0.0/0`) into the VRF routing table on the specified border leafs.

### Virtual Networks (VXLANs)

```hcl
vns = [
  {
    name                 = "Vlan-100"
    vlan_id              = 100
    vrf_name             = "Blue_VRF"
    ipv4_virtual_gateway = "10.0.100.1"
    ipv4_subnet          = "10.0.100.0/24"
    bindings             = ["terraform_compute_001_leaf1"]
  },
]
```

### Generic Systems (servers / appliances)

```hcl
generic_systems = [
  {
    name      = "Server14"
    hostname  = "Server14"
    link_tags = ["server14"]
    links = [
      {
        leaf_label                    = "terraform_compute_001_leaf1"
        target_switch_if_name         = "xe-0/0/1"
        target_switch_if_transform_id = 2
        group_label                   = "bond0"
        lag_mode                      = "lacp_active"
      },
      # Second link for ESI-LAG (multi-homing)
      { ... }
    ]
    vns = ["Vlan-100", "Vlan-200"]
  },
]
```

## Resource Pools

| Pool | Type | Range |
|------|------|-------|
| Terraform-Loopback | IPv4 | 10.0.0.0/24 |
| Terraform-Link | IPv4 | 10.1.0.0/24 |
| Terraform-ASN | ASN | 65100–65199 |
| Terraform-vni | VNI | 10000–19999 |

## Deployed Services (default values)

| VRF | VLAN | Subnet | Gateway | Default Route Next-Hop | Bound to |
|-----|------|--------|---------|------------------------|----------|
| Blue_VRF | 100 | 10.0.100.0/24 | 10.0.100.1 | 10.0.10.254 (FW) | compute leaf1 |
| Red_VRF  | 200 | 10.0.200.0/24 | 10.0.200.1 | 10.0.20.254 (FW) | compute leaf1 |
| Blue_VRF | 10  | 10.0.10.0/24  | 10.0.10.1  | 10.0.10.254 (FW) | border leaf1  |
| Red_VRF  | 20  | 10.0.20.0/24  | 10.0.20.1  | 10.0.20.254 (FW) | border leaf1  |

## Security

- `terraform.secrets.tfvars` is excluded from the git repository (see `.gitignore`)
- Terraform state files (`.tfstate`) are also excluded — use a remote backend (S3, Terraform Cloud) in production
