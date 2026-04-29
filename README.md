# Terraform Apstra — ERB 6.1

Automated provisioning of a Juniper datacenter fabric via [Juniper Apstra](https://www.juniper.net/us/en/products/network-automation/apstra.html) and Terraform.

## Deployed Topology

```
                     ┌─────────┐      ┌─────────┐
                     │ Spine 1 │      │ Spine 2 │   (QFX5200)
                     └────┬────┘      └────┬────┘
          ┌───────────────┴──┬─────────────┴───────────────┐
   ┌──────┴──────┐    ┌──────┴──────┐    ┌──────┴──────┐    ┌──────┴──────┐
   │  Border L1  │    │  Border L2  │    │ Compute L1  │    │ Compute L2  │
   │  QFX10002   │    │  QFX10002   │    │   QFX5120   │    │   QFX5120   │
   └──────┬──────┘    └──────┬──────┘    └──────┬──────┘    └──────┬──────┘
          └─── ESI-LAG ──────┘                  └─── ESI-LAG ──────┘
                    │                                      │
                ┌───┴───┐                    ┌─────────────┴─────────────┐
                │  FW   │             ┌──────┴──────┐             ┌──────┴──────┐
                └───────┘             │   Server14  │             │   Server10  │
                                      └─────────────┘             └─────────────┘
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

### 3. Choose a lab configuration

Two lab configurations are available — pick one:

| Config file | VRFs | VLANs | IP gateways |
|-------------|------|-------|-------------|
| `config-erb.tfvars` | Blue_VRF, Red_VRF | 10, 20, 100, 200 | Yes |
| `config-bo.tfvars` | BO | 100, 200 | No |

### 4. Plan and Deploy

```bash
# ERB lab
terraform apply -var-file="terraform.secrets.tfvars" -var-file="config-erb.tfvars"

# BO lab
terraform apply -var-file="terraform.secrets.tfvars" -var-file="config-bo.tfvars"
```

> `terraform.tfvars` is loaded automatically by Terraform. `config-*.tfvars` files must be passed explicitly with `-var-file` so you can choose which lab to deploy.

### 5. Destroy

```bash
terraform destroy -var-file="terraform.secrets.tfvars" -var-file="config-erb.tfvars"
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
| `vrf.tf` | VRFs (Routing Zones) and default route Connectivity Templates |
| `virtual_networks.tf` | Virtual Networks (VXLANs) and tagged Connectivity Templates |
| `generic-systems.tf` | Generic systems (servers, firewall) with LACP LAG |
| `terraform.tfvars` | Common variables (Apstra endpoint, blueprint name…) |
| `config-erb.tfvars` | ERB lab: Blue_VRF / Red_VRF, VLANs 10/20/100/200 with IPs |
| `config-bo.tfvars` | BO lab: single VRF BO, VLANs 100/200 without IPs |

## Service Configuration

Services are defined in config files (`config-erb.tfvars` or `config-bo.tfvars`) — no changes to `.tf` files are needed to add VRFs, VNs, or generic systems.

### VRFs

Each VRF (Routing Zone) can optionally have a **default route configured on the border leafs pointing to the firewall**.

```hcl
vrfs = [
  {
    name                   = "Blue_VRF"
    default_route_next_hop = "10.0.10.254"          # optional — omit for L2-only VRFs
    default_route_leaf     = ["Border1", "Border2"]  # optional
  },
]
```

When `default_route_next_hop` is set, Apstra generates a System Connectivity Template that injects a static default route (`0.0.0.0/0`) into the VRF on the specified border leafs.

### Virtual Networks (VXLANs)

IP fields are optional — omit them for pure L2 VLANs:

```hcl
vns = [
  {
    name                 = "Vlan-100"
    vlan_id              = 100
    vrf_name             = "Blue_VRF"
    ipv4_virtual_gateway = "10.0.100.1"   # optional
    ipv4_subnet          = "10.0.100.0/24" # optional
    bindings             = ["Leaf1"]
  },
  {
    name     = "Vlan-200"   # L2 only — no IP
    vlan_id  = 200
    vrf_name = "BO"
    bindings = ["Leaf1", "Border1"]
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

## Lab Configurations

### ERB lab (`config-erb.tfvars`)

| VRF | VLAN | Subnet | Gateway | Default Route Next-Hop | Bound to |
|-----|------|--------|---------|------------------------|----------|
| Blue_VRF | 100 | 10.0.100.0/24 | 10.0.100.1 | 10.0.10.254 (FW) | Leaf1 |
| Red_VRF  | 200 | 10.0.200.0/24 | 10.0.200.1 | 10.0.20.254 (FW) | Leaf1 |
| Blue_VRF | 10  | 10.0.10.0/24  | 10.0.10.1  | 10.0.10.254 (FW) | Border1 |
| Red_VRF  | 20  | 10.0.20.0/24  | 10.0.20.1  | 10.0.20.254 (FW) | Border1 |

### BO lab (`config-bo.tfvars`)

| VRF | VLAN | Subnet | Gateway | Default Route | Bound to |
|-----|------|--------|---------|---------------|----------|
| BO | 100 | — | — | — | Leaf1, Border1 |
| BO | 200 | — | — | — | Leaf1, Border1 |

## Security

- `terraform.secrets.tfvars` is excluded from the git repository (see `.gitignore`)
- Terraform state files (`.tfstate`) are also excluded — use a remote backend (S3, Terraform Cloud) in production
