# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commandes essentielles

```bash
# Initialisation (première fois ou après changement de provider)
terraform init

# Vérification du plan avant déploiement
terraform plan -var-file="terraform.secrets.tfvars"

# Déploiement
terraform apply -var-file="terraform.secrets.tfvars"

# Destruction complète
terraform destroy -var-file="terraform.secrets.tfvars"
```

Le fichier `terraform.secrets.tfvars` (ignoré par git) contient `apstra_url` avec les credentials. Il doit être créé localement :

```hcl
apstra_url = "https://<user>:<password>@<apstra-ip>"
```

## Architecture

Ce projet provisionne un fabric datacenter complet via Juniper Apstra (provider `Juniper/apstra` v0.98.0). Le déploiement suit un ordre strict imposé par les dépendances Terraform.

### Ordre de création des ressources

```
resources.tf          → pools ASN / IPv4 / VNI
logical-device-interface-maps.tf → logical devices + interface maps
racks.tf              → rack types (compute + border)
template.tf           → rack-based template
blueprint.tf          → blueprint + device allocation + pool allocation
erb_vrf.tf            → VRFs (routing zones) + CT default route
erb_vn.tf             → Virtual Networks + CT tagged par VN
generic-systems.tf    → Generic systems (serveurs, FW) + CT assignments
blueprint.tf          → apstra_blueprint_deployment (dernier, avec depends_on complet)
```

### Pattern data-driven

Toutes les entités variables (VRFs, VNs, generic systems) sont définies comme listes d'objets dans `terraform.tfvars` et itérées avec `for_each`. Pour ajouter un VRF, une VN ou un serveur, il suffit d'ajouter un bloc dans `terraform.tfvars` — aucune modification des fichiers `.tf` n'est nécessaire.

### Nommage des switches

Les nœuds du blueprint sont référencés par leur label Apstra :
- `spine1`, `spine2`
- `terraform_border_001_leaf1`, `terraform_border_001_leaf2`
- `terraform_compute_001_leaf1`, `terraform_compute_001_leaf2`

Ces labels sont utilisés comme clés dans `local.switches` (blueprint.tf) et comme valeurs dans les champs `bindings`, `default_route_leaf`, et `leaf_label` de `terraform.tfvars`.

### Connectivity Templates

Deux types de CT sont générés automatiquement :
- **CT par VN** (`erb_vn.tf`) : un CT interface tagged par Virtual Network, assigné aux generic systems via `generic-systems.tf`
- **CT default route** (`erb_vrf.tf`) : un CT system par VRF avec static route vers le next-hop du firewall, assigné aux border leafs

### Mutex et TLS

`blueprint_mutex_enabled = false` — à activer si plusieurs utilisateurs modifient le même blueprint simultanément. `tls_validation_disabled = true` — ne pas modifier sans certificat valide sur Apstra.
