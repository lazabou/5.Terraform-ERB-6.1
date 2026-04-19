
# Instantiate a blueprint from the previously-created template
resource "apstra_datacenter_blueprint" "terraform-pod1" {
  name        = "Terraform-pod1"
  template_id = apstra_template_rack_based.terraform-template.id
  depends_on = [
    apstra_logical_device.ld,
    apstra_interface_map.im,
  ]
}


data "apstra_asn_pool" "details" {
  name       = "Terraform-ASN"
  
  depends_on = [
    apstra_asn_pool.terraform-asn,
  ]
}

data "apstra_ipv4_pool" "lb" {
  name       = "Terraform-Loopback"
  
    depends_on = [
    apstra_ipv4_pool.terraform-lb,
  ]
}

data "apstra_ipv4_pool" "link" {
  name       = "Terraform-Link"
  
  depends_on = [
    apstra_ipv4_pool.terraform-link,
  ]
}



locals {
  asn_pools = {
    spine_asns = [data.apstra_asn_pool.details.id]
    leaf_asns  = [data.apstra_asn_pool.details.id]
  }
  ipv4_pools = {
    spine_loopback_ips  = [data.apstra_ipv4_pool.lb.id]
    leaf_loopback_ips   = [data.apstra_ipv4_pool.lb.id]
    spine_leaf_link_ips = [data.apstra_ipv4_pool.link.id]
  }
  switches = {
    spine1 = {
      device_key       = "WH0216290096"
      interface_map_id = apstra_interface_map.im["spine"].id
    }
    spine2 = {
      device_key       = "WH0217430051"
      interface_map_id = apstra_interface_map.im["spine"].id
    }
    terraform_border_001_leaf1 = {
      device_key       = "DA722"
      interface_map_id = apstra_interface_map.im["border"].id
    }
    terraform_border_001_leaf2 = {
      device_key       = "DL440"
      interface_map_id = apstra_interface_map.im["border"].id
    }
    terraform_compute_001_leaf1 = {
      device_key       = "XH3722180714"
      interface_map_id = apstra_interface_map.im["leaf"].id
    }
    terraform_compute_001_leaf2 = {
      device_key       = "XH3722180698"
      interface_map_id = apstra_interface_map.im["leaf"].id
    }
  }
}


resource "apstra_datacenter_device_allocation" "assign_devices" {
  for_each         = local.switches
  blueprint_id     = apstra_datacenter_blueprint.terraform-pod1.id
  node_name        = each.key

  # On associe l’interface map à ce nœud
  initial_interface_map_id = each.value.interface_map_id

  # Obligatoire pour pouvoir déployer
  system_attributes = {
    deploy_mode = "deploy"
  }

  device_key = each.value.device_key

  # ⭐ Dépendances importantes : les LD & interface maps doivent exister AVANT assignation
  depends_on = [
    apstra_logical_device.ld,
    apstra_interface_map.im,
  ]
}

# Assign ASN pools to fabric roles 
resource "apstra_datacenter_resource_pool_allocation" "asn" {
  for_each     = local.asn_pools
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id
  role         = each.key
  pool_ids     = each.value
}

# Assign IPv4 pools to fabric roles 
resource "apstra_datacenter_resource_pool_allocation" "ipv4" {
  for_each     = local.ipv4_pools
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id
  role         = each.key
  pool_ids     = each.value
}


resource "apstra_blueprint_deployment" "deploy" {
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id

  depends_on = [
    # VRFs
    apstra_datacenter_routing_zone.vrfs,
    apstra_datacenter_resource_pool_allocation.vrf_loopbacks,

    # VNs
    apstra_datacenter_virtual_network.vns,
    apstra_datacenter_resource_pool_allocation.vn-vni,

    # Generic systems et leurs assignements
    apstra_datacenter_generic_system.systems,
    apstra_datacenter_connectivity_templates_assignment.gs_assign,

    # CT par VN
    apstra_datacenter_connectivity_template_interface.vn_ct,

    # Routes par défaut
    apstra_datacenter_connectivity_template_system.ct_default_route,
  #  apstra_datacenter_connectivity_templates_assignment.assign_default_route,
    apstra_datacenter_connectivity_template_assignments.assign_default_route,

    # 🆕 Ajout important : assignation des devices dans le blueprint
    apstra_datacenter_device_allocation.assign_devices
  ]

  comment = "Déployé par Terraform {{.TerraformVersion}}, provider Apstra {{.ProviderVersion}}, utilisateur $USER."
}