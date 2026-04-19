# Terraform Apstra — ERB 6.1

Provisionnement automatisé d'un fabric datacenter Juniper via [Juniper Apstra](https://www.juniper.net/us/en/products/network-automation/apstra.html) et Terraform.

## Topologie déployée

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

| Rôle          | Modèle     | Quantité |
|---------------|------------|----------|
| Spine         | QFX5200    | 2        |
| Border Leaf   | QFX10002-36Q | 2      |
| Compute Leaf  | QFX5120-48Y  | 2      |

**Overlay** : EVPN / VXLAN — contrôle via Apstra

## Prérequis

- Terraform ≥ 1.0
- Accès réseau à l'instance Apstra
- Apstra ≥ 5.0 (provider `Juniper/apstra` v0.98.0)

## Démarrage rapide

### 1. Initialisation

```bash
terraform init
```

### 2. Credentials Apstra

Créer un fichier `terraform.secrets.tfvars` (ignoré par git) :

```hcl
apstra_url = "https://<user>:<password>@<apstra-ip>"
```

### 3. Plan et déploiement

```bash
terraform plan    -var-file="terraform.secrets.tfvars"
terraform apply   -var-file="terraform.secrets.tfvars"
```

### 4. Destruction

```bash
terraform destroy -var-file="terraform.secrets.tfvars"
```

## Structure des fichiers

| Fichier | Rôle |
|---------|------|
| `apstra.tf` | Configuration du provider Apstra |
| `resources.tf` | Pools de ressources (ASN, IPv4 loopback/link, VNI) |
| `logical-device-interface-maps.tf` | Logical devices et interface maps (leaf / border / spine) |
| `racks.tf` | Types de racks (compute et border) |
| `template.tf` | Template rack-based du blueprint |
| `blueprint.tf` | Blueprint, allocation des devices et déploiement |
| `erb_vrf.tf` | VRFs (Routing Zones) et Connectivity Templates default route |
| `erb_vn.tf` | Virtual Networks (VXLANs) et Connectivity Templates tagged |
| `generic-systems.tf` | Generic systems (serveurs, firewall) avec LAG LACP |
| `terraform.tfvars` | Valeurs : VRFs, VNs, generic systems |

## Configuration des services

Tous les services sont définis dans `terraform.tfvars` — aucune modification des fichiers `.tf` n'est nécessaire pour ajouter des VRFs, VNs ou generic systems.

### VRFs

```hcl
vrfs = [
  {
    name                   = "Blue_VRF"
    default_route_next_hop = "10.0.10.254"         # Next-hop FW
    default_route_leaf     = ["terraform_border_001_leaf1", "terraform_border_001_leaf2"]
  },
]
```

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

### Generic Systems (serveurs / équipements)

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
      # Deuxième lien pour ESI-LAG (multi-homing)
      { ... }
    ]
    vns = ["Vlan-100", "Vlan-200"]
  },
]
```

## Pools de ressources créés

| Pool | Type | Plage |
|------|------|-------|
| Terraform-Loopback | IPv4 | 10.0.0.0/24 |
| Terraform-Link | IPv4 | 10.1.0.0/24 |
| Terraform-ASN | ASN | 65100–65199 |
| Terraform-vni | VNI | 10000–19999 |

## Services déployés (valeurs par défaut)

| VRF | VLAN | Subnet | Gateway | Bound to |
|-----|------|--------|---------|----------|
| Blue_VRF | 100 | 10.0.100.0/24 | 10.0.100.1 | compute leaf1 |
| Red_VRF | 200 | 10.0.200.0/24 | 10.0.200.1 | compute leaf1 |
| Blue_VRF | 10 | 10.0.10.0/24 | 10.0.10.1 | border leaf1 |
| Red_VRF | 20 | 10.0.20.0/24 | 10.0.20.1 | border leaf1 |

## Sécurité

- `terraform.secrets.tfvars` est exclu du dépôt git (voir `.gitignore`)
- Les fichiers d'état Terraform (`.tfstate`) sont également exclus — utiliser un backend distant (S3, Terraform Cloud) en production
