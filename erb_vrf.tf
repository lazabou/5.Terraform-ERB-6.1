########################
#       VRFs           #
########################

variable "vrfs" {
  type = list(object({
    name                      = string
    default_route_next_hop    = string
    default_route_leaf        = list(string)
  }))
}

resource "apstra_datacenter_resource_pool_allocation" "vrf-vni" {
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id
  role         = "evpn_l3_vnis"
  pool_ids     = [apstra_vni_pool.terraform-vni.id]
}

resource "apstra_datacenter_routing_zone" "vrfs" {
  for_each     = { for v in var.vrfs : v.name => v }
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id
  name         = each.value.name
}

resource "apstra_datacenter_resource_pool_allocation" "vrf_loopbacks" {
  for_each = apstra_datacenter_routing_zone.vrfs

  blueprint_id    = apstra_datacenter_blueprint.terraform-pod1.id
  role            = "leaf_loopback_ips"
  pool_ids        = [apstra_ipv4_pool.terraform-lb.id]
  routing_zone_id = each.value.id
}

resource "apstra_datacenter_connectivity_template_system" "ct_default_route" {
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id
  name         = "Default_route"
  description  = "Routes par défaut pour toutes les VRFs"

  custom_static_routes = {
    for vrf in var.vrfs :
    vrf.name => {
      routing_zone_id = apstra_datacenter_routing_zone.vrfs[vrf.name].id
      network         = "0.0.0.0/0"
      next_hop        = vrf.default_route_next_hop
    }
  }
}

########################
#  Leaf systems ciblés par la default route  #
########################

data "apstra_datacenter_systems" "default_route_leafs" {
  # un data par leaf_label utilisé dans au moins une VRF
  for_each     = toset(flatten([for vrf in var.vrfs : vrf.default_route_leaf]))
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id

  filters = [{
    label = each.key
  }]
}


########################
#  Assignation du CT   #
########################

resource "apstra_datacenter_connectivity_template_assignments" "assign_default_route" {
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id

  # Tous les leafs utilisés par au moins une VRF
  application_point_ids = [
    for _, sys in data.apstra_datacenter_systems.default_route_leafs :
    one(sys.ids)
  ]

  connectivity_template_id = apstra_datacenter_connectivity_template_system.ct_default_route.id

  depends_on = [
    apstra_datacenter_connectivity_template_system.ct_default_route,
  ]
}
